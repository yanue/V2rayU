//
//  DiagnosticsViewModel.swift
//  V2rayU
//
//  Created by yanue on 2025/11/8.
//

import SwiftUI
import AppKit

@MainActor
final class DiagnosticsViewModel: ObservableObject {
    // MARK: - Published state

    @Published var items: [DiagnosticItem] = []
    @Published var checking = false
    @Published var showOpenSettingsAlert = false
    @Published var showFAQ = false
    @Published var progressText = ""
    @Published var logContent = ""
    @Published var collapsedSections: Set<DiagnosticCategory> = []

    var hasFailures: Bool { ensureItemsInitialized(); return items.contains { !$0.ok } }

    var passedCount: Int { ensureItemsInitialized(); return items.filter { $0.status == .passed }.count }
    var checkedCount: Int { ensureItemsInitialized(); return items.filter { $0.status == .passed || $0.status == .failed }.count }
    var totalCount:  Int { ensureItemsInitialized(); return items.count }

    // MARK: - Dependencies

    private let appState = AppState.shared
    private let logPath  = coreLogFilePath
    private var localSocksPort: Int { Int(getSocksProxyPort()) }
    private var localHTTPPort:  Int { Int(getHttpProxyPort()) }
    private let nodeHostProvider: () -> String?
    private let nodePortProvider: () -> UInt16?

    private var checkTask: Task<Void, Never>?

    // MARK: - Init

    private var _hasInitialized = false
    private var _hasRun = false

    init(nodeHostProvider: @escaping () -> String?, nodePortProvider: @escaping () -> UInt16?) {
        self.nodeHostProvider = nodeHostProvider
        self.nodePortProvider = nodePortProvider
    }

    func ensureItemsInitialized() {
        guard !_hasInitialized else { return }
        _hasInitialized = true
        items = DiagnosticStep.ordered.map { makePending($0) }
    }

    /// Only run checks on first appearance; subsequent returns preserve last results
    func runChecksIfNeeded() {
        ensureItemsInitialized()
        guard !_hasRun else { return }
        _hasRun = true
        runSequentialChecks()
    }

    func resetForNewCheck() {
        items = DiagnosticStep.ordered.map { makePending($0) }
    }

    // MARK: - Item helpers

    func itemsFor(_ category: DiagnosticCategory) -> [DiagnosticItem] {
        ensureItemsInitialized()
        return items.filter { $0.category == category }
    }

    private func makePending(_ step: DiagnosticStep) -> DiagnosticItem {
        DiagnosticItem(id: step.rawValue, step: step, title: title(for: step),
                       subtitle: String(localized: .DiagPending), status: .pending,
                       ok: false, problem: nil, actionTitle: nil, action: nil)
    }

    private func makeChecking(_ step: DiagnosticStep) -> DiagnosticItem {
        DiagnosticItem(id: step.rawValue, step: step, title: title(for: step),
                       subtitle: String(localized: .DiagChecking), status: .checking,
                       ok: false, problem: nil, actionTitle: nil, action: nil)
    }

    /// Convert a CheckResult into a display item with resolved action closure
    private func toItem(_ r: CheckResult) -> DiagnosticItem {
        let (aTitle, aAction) = resolveAction(r.actionId)
        return DiagnosticItem(
            id: r.step.rawValue, step: r.step, title: title(for: r.step),
            subtitle: r.subtitle, status: r.ok ? .passed : .failed,
            ok: r.ok, problem: r.problem,
            actionTitle: aTitle, action: aAction
        )
    }

    private func title(for step: DiagnosticStep) -> String {
        switch step {
        case .v2rayUToolInstall:  return String(localized: .DiagV2rayUToolInstall)
        case .uToolPermission:   return String(localized: .DiagUToolPermission)
        case .coreInstall:       return String(localized: .DiagCoreInstall)
        case .coreArch:          return String(localized: .DiagCoreArch)
        case .configFile:        return String(localized: .DiagConfigFile)
        case .configValidity:    return String(localized: .DiagConfigValidity)
        case .geoipFile:         return String(localized: .DiagGeoipFile)
        case .geositeFile:       return String(localized: .DiagGeositeFile)
        case .coreRunning:       return String(localized: .DiagCoreRunning)
        case .launchdProcess:    return String(localized: .DiagLaunchdProcess)
        case .systemProxy:       return String(localized: .DiagSystemProxy)
        case .localPortConflict: return String(localized: .DiagLocalPortConflict)
        case .basicNetwork:      return String(localized: .DiagBasicNetwork)
        case .nodeConnectivity:  return String(localized: .DiagNetworkConnectivity)
        case .proxyConnectivity: return String(localized: .DiagProxyConnectivity)
        case .pingLatency:       return String(localized: .DiagPingLatency)
        case .logAnalysis:       return String(localized: .DiagLogAnalysis)
        }
    }

    // MARK: - Action resolution

    private func resolveAction(_ id: DiagnosticAction?) -> (String?, (() -> Void)?) {
        guard let id else { return (nil, nil) }
        switch id {
        case .fixInstall:          return (String(localized: .DiagFixNow),             { self.doFixInstall() })
        case .fixTool:             return (String(localized: .DiagFixNow),             { self.doFixTool() })
        case .fixGeoip:            return (String(localized: .DiagFixNow),             { self.doFixGeoip() })
        case .openConfig:          return (String(localized: .DiagViewConfig),         { self.openConfigFile() })
        case .openNetworkSettings: return (String(localized: .DiagOpenNetworkSettings),{ self.openSystemNetworkSettings() })
        case .startCore:           return (String(localized: .DiagStartCore),          { self.doToggleCore() })
        case .restartCore:         return (String(localized: .DiagRestartCore),        { self.doRestartCore() })
        case .rePing:              return (String(localized: .DiagReTest),             { self.doPingNow() })
        case .reloadLaunchd:       return (String(localized: .DiagLaunchdReload),      { self.doRestartCore() })
        }
    }

    // MARK: - Run diagnostics

    func cancelChecks() {
        checkTask?.cancel()
        checkTask = nil
        checking = false
    }

    func runSequentialChecks() {
        guard !checking else { return }
        checkTask?.cancel()
        checkTask = Task { @MainActor [weak self] in
            guard let self else { return }
            self.checking = true
            self.progressText = ""
            self.items = DiagnosticStep.ordered.map { self.makePending($0) }

            let steps = DiagnosticStep.ordered

            for (i, step) in steps.enumerated() {
                guard !Task.isCancelled else { break }

                // Mark current step as checking
                if let idx = self.items.firstIndex(where: { $0.step == step }) {
                    self.items[idx] = self.makeChecking(step)
                }
                self.progressText = "\(i + 1)/\(steps.count) \(self.title(for: step))"

                // Yield to let UI update
                await Task.yield()

                // Run the check (heavy work dispatched off main actor inside each method)
                let result = await self.runCheck(step)

                guard !Task.isCancelled else { break }

                if let idx = self.items.firstIndex(where: { $0.step == step }) {
                    self.items[idx] = self.toItem(result)
                }
            }

            self.progressText = ""
            self.checking = false
        }
    }

    /// Dispatch to appropriate checker
    private func runCheck(_ step: DiagnosticStep) async -> CheckResult {
        switch step {
        case .v2rayUToolInstall:  return await checkV2rayUToolInstall()
        case .uToolPermission:   return await checkUToolPermission()
        case .coreInstall:       return await checkCoreInstall()
        case .coreArch:          return await checkCoreArch()
        case .configFile:        return await checkConfigFile()
        case .configValidity:    return await checkConfigValidity()
        case .geoipFile:         return checkGeoFile(name: "geoip.dat", step: .geoipFile, missingKey: .DiagGeoipMissing)
        case .geositeFile:       return checkGeoFile(name: "geosite.dat", step: .geositeFile, missingKey: .DiagGeositeMissing)
        case .coreRunning:       return await checkCoreRunning()
        case .launchdProcess:    return await checkLaunchdProcess()
        case .systemProxy:       return await checkSystemProxy()
        case .localPortConflict: return await checkLocalPortConflict()
        case .basicNetwork:      return await checkBasicNetwork()
        case .nodeConnectivity:  return await checkNodeConnectivity()
        case .proxyConnectivity: return await checkProxyConnectivity()
        case .pingLatency:       return await checkPingLatency()
        case .logAnalysis:       return await checkLogAnalysis()
        }
    }

    // MARK: ── File Checks ──

    private func checkV2rayUToolInstall() async -> CheckResult {
        let path = v2rayUTool
        let exists = FileManager.default.fileExists(atPath: path)
        let exec   = exists && FileManager.default.isExecutableFile(atPath: path)

        if exec {
            return .pass(.v2rayUToolInstall)
        }
        let msg = exists ? String(localized: .DiagToolNoPermission) : String(localized: .DiagToolMissing)
        return .fail(.v2rayUToolInstall, subtitle: msg, problem: msg, action: .fixTool)
    }

    private func checkUToolPermission() async -> CheckResult {
        let path = v2rayUTool
        guard FileManager.default.fileExists(atPath: path) else {
            return .fail(.uToolPermission,
                         subtitle: String(localized: .DiagToolMissing),
                         problem: String(localized: .DiagToolMissing), action: .fixTool)
        }
        let ok = checkFileIsRootAdmin(file: path)
        if ok { return .pass(.uToolPermission) }
        return .fail(.uToolPermission,
                     subtitle: String(localized: .DiagToolNoPermission),
                     problem: String(localized: .DiagToolNoPermission), action: .fixTool)
    }

    private func checkCoreInstall() async -> CheckResult {
        let path = xrayCoreFile
        let exists = FileManager.default.fileExists(atPath: path)
        let exec   = exists && FileManager.default.isExecutableFile(atPath: path)

        if exec {
            let ver = getCoreVersion()
            return .pass(.coreInstall, String(format: String(localized: .DiagPassed), ver))
        }
        let msg = exists ? String(localized: .DiagCoreNotExecutable) : String(localized: .DiagCoreNotInstalled)
        return .fail(.coreInstall, subtitle: msg, problem: msg, action: .fixInstall)
    }

    private func checkCoreArch() async -> CheckResult {
        let path = xrayCoreFile
        guard FileManager.default.fileExists(atPath: path),
              FileManager.default.isExecutableFile(atPath: path) else {
            return .fail(.coreArch, subtitle: String(localized: .DiagCoreNotInstalled),
                         problem: String(localized: .DiagCoreNotInstalled), action: .fixInstall)
        }
        let currentArch = isARM64() ? "arm64" : "amd64"
        let actualArch = await getFileArch(file: path)
        let ok = actualArch == currentArch
        if ok {
            return .pass(.coreArch, String(format: String(localized: .DiagCoreArchCorrect), actualArch ?? "unknown"))
        }
        let msg = String(format: String(localized: .DiagCoreArchMismatch), actualArch ?? "unknown", currentArch)
        return .fail(.coreArch, subtitle: msg, problem: msg, action: .fixInstall)
    }

    private func checkConfigFile() async -> CheckResult {
        let path = JsonConfigFilePath
        guard FileManager.default.fileExists(atPath: path) else {
            return .fail(.configFile, subtitle: String(localized: .DiagConfigFileMissing),
                         problem: String(localized: .DiagConfigFileMissing), action: .fixInstall)
        }
        let size = (try? FileManager.default.attributesOfItem(atPath: path)[.size] as? Int) ?? 0
        if size > 0 {
            return .pass(.configFile, String(format: String(localized: .DiagConfigFileExists), size))
        }
        return .fail(.configFile, subtitle: String(localized: .DiagConfigFileEmpty),
                     problem: String(localized: .DiagConfigFileEmpty), action: .fixInstall)
    }

    private func checkConfigValidity() async -> CheckResult {
        let (valid, problems) = await ConfigValidator.validateConfig(filePath: JsonConfigFilePath)
        if valid { return .pass(.configValidity, String(localized: .DiagConfigValidOK)) }
        let joined = problems.joined(separator: "; ")
        return .fail(.configValidity, subtitle: String(localized: .DiagFailed),
                     problem: String(format: String(localized: .DiagConfigValidProblems), joined),
                     action: .openConfig)
    }

    private func checkGeoFile(name: String, step: DiagnosticStep, missingKey: LanguageLabel) -> CheckResult {
        let exists = FileManager.default.fileExists(atPath: xrayCorePath + "/\(name)")
        if exists { return .pass(step) }
        return .fail(step, subtitle: String(localized: missingKey),
                     problem: String(localized: missingKey), action: .fixGeoip)
    }

    // MARK: ── Status Checks ──

    private func checkCoreRunning() async -> CheckResult {
        let running = await runInBackground { ProcessChecker.isProcessRunning("v2ray") || ProcessChecker.isProcessRunning("xray") }
        if running {
            return CheckResult(step: .coreRunning, ok: true, subtitle: String(localized: .DiagPassed),
                               problem: nil, actionId: .restartCore)
        }
        let msg = appState.v2rayTurnOn ? String(localized: .DiagCoreStartFailed) : String(localized: .DiagCoreStopped)
        return CheckResult(step: .coreRunning, ok: false, subtitle: msg, problem: msg,
                           actionId: appState.v2rayTurnOn ? .restartCore : .startCore)
    }

    /// NEW: Check launchd agent status for sing-box / xray
    private func checkLaunchdProcess() async -> CheckResult {
        let result = await runInBackground { () -> (loaded: Bool, pid: String?) in
            // Use launchctl list to check if agent is loaded and get PID
            let agentNames = ["yanue.v2rayu.sing-box", "yanue.v2rayu.xray-core"]
            for name in agentNames {
                let task = Process()
                task.launchPath = "/bin/launchctl"
                task.arguments = ["list", name]
                let pipe = Pipe()
                task.standardOutput = pipe
                task.standardError = Pipe()
                do {
                    try task.run()
                    task.waitUntilExit()
                    if task.terminationStatus == 0 {
                        let data = pipe.fileHandleForReading.readDataToEndOfFile()
                        let output = String(data: data, encoding: .utf8) ?? ""
                        // Parse PID from launchctl list output
                        // Format: { "LimitLoadToSessionType" = "Aqua"; "Label" = "..."; "PID" = 12345; ... }
                        var pid: String? = nil
                        for line in output.components(separatedBy: "\n") {
                            let trimmed = line.trimmingCharacters(in: .whitespaces)
                            if trimmed.hasPrefix("\"PID\"") {
                                let parts = trimmed.components(separatedBy: "=")
                                if parts.count >= 2 {
                                    pid = parts[1].trimmingCharacters(in: CharacterSet.whitespaces.union(CharacterSet(charactersIn: "\";")))
                                }
                            }
                        }
                        return (true, pid)
                    }
                } catch { }
            }
            return (false, nil)
        }

        if !result.loaded {
            return .fail(.launchdProcess,
                         subtitle: String(localized: .DiagLaunchdNotLoaded),
                         problem: String(localized: .DiagLaunchdNotLoaded),
                         action: .reloadLaunchd)
        }
        if let pid = result.pid, !pid.isEmpty, pid != "0" {
            return .pass(.launchdProcess,
                         String(format: String(localized: .DiagLaunchdRunning), pid))
        }
        return .fail(.launchdProcess,
                     subtitle: String(localized: .DiagLaunchdNotRunning),
                     problem: String(localized: .DiagLaunchdNotRunning),
                     action: .reloadLaunchd)
    }

    private func checkSystemProxy() async -> CheckResult {
        let runMode = appState.runMode

        if runMode == .tun {
            return .pass(.systemProxy, String(localized: .DiagProxyNotNeededTunnel))
        }
        if runMode == .manual {
            return .pass(.systemProxy, String(localized: .DiagProxyNotNeededManual))
        }
        if !appState.v2rayTurnOn {
            return .pass(.systemProxy, String(localized: .DiagProxyNotNeededOff))
        }

        let expectedSocks = localSocksPort
        let expectedHTTP  = localHTTPPort

        let (socksEnabled, socksPort, httpEnabled, httpPort) = await runInBackground {
            let s = DiagnosticsViewModel.getSystemProxyStatusSync(type: "socks")
            let h = DiagnosticsViewModel.getSystemProxyStatusSync(type: "http")
            return (s.enabled, s.port, h.enabled, h.port)
        }

        let socksOK = socksEnabled && socksPort == expectedSocks
        let httpOK  = httpEnabled  && httpPort  == expectedHTTP
        let ok = socksOK || httpOK

        if ok {
            let port = socksOK ? expectedSocks : expectedHTTP
            return .pass(.systemProxy, String(format: String(localized: .DiagSystemProxyOK), port))
        }
        if !socksEnabled && !httpEnabled {
            return .fail(.systemProxy, subtitle: String(localized: .DiagProxyNotEnabled),
                         problem: String(localized: .DiagProxyNotEnabled), action: .openNetworkSettings)
        }
        let curPort = socksEnabled ? socksPort : httpPort
        let expPort = socksEnabled ? expectedSocks : expectedHTTP
        let msg = String(format: String(localized: .DiagProxyPortMismatch), curPort, expPort)
        return .fail(.systemProxy, subtitle: msg, problem: msg, action: .openNetworkSettings)
    }

    private func checkLocalPortConflict() async -> CheckResult {
        let socksPort = localSocksPort
        let httpPort  = localHTTPPort

        let (socksListening, httpListening, coreRunning, ownerSocks, ownerHTTP) = await runInBackground {
            let sl = ProcessChecker.isPortListening(socksPort)
            let hl = ProcessChecker.isPortListening(httpPort)
            let cr = ProcessChecker.isProcessRunning("v2ray") || ProcessChecker.isProcessRunning("xray")
            let os = ProcessChecker.portOwner(socksPort) ?? "未知"
            let oh = ProcessChecker.portOwner(httpPort) ?? "未知"
            return (sl, hl, cr, os, oh)
        }

        let conflictSocks = socksListening && !coreRunning
        let conflictHTTP  = httpListening  && !coreRunning
        let ok = !(conflictSocks || conflictHTTP)

        if ok { return .pass(.localPortConflict) }

        let msg: String
        if conflictSocks {
            msg = String(format: String(localized: .DiagPortOccupied), socksPort, ownerSocks)
        } else {
            msg = String(format: String(localized: .DiagPortOccupied), httpPort, ownerHTTP)
        }
        return .fail(.localPortConflict, subtitle: String(localized: .DiagPortOccupied),
                     problem: msg, action: .restartCore)
    }

    // MARK: ── Network Checks ──

    private func checkBasicNetwork() async -> CheckResult {
        let ok = await NetworkChecker.canResolve(host: "www.apple.com", timeout: 5)
        if ok { return .pass(.basicNetwork, String(localized: .DiagBasicNetworkOK)) }
        return .fail(.basicNetwork, subtitle: String(localized: .DiagBasicNetworkFailed),
                     problem: String(localized: .DiagBasicNetworkFailed), action: .openNetworkSettings)
    }

    private func checkNodeConnectivity() async -> CheckResult {
        guard let host = nodeHostProvider() else {
            return .fail(.nodeConnectivity, subtitle: String(localized: .DiagNodeNotSelected),
                         problem: String(localized: .DiagNodeNotSelected))
        }
        let dnsOK = await NetworkChecker.canResolve(host: host)
        guard dnsOK else {
            let msg = String(format: String(localized: .DiagDNSResolveFailed), host)
            return .fail(.nodeConnectivity, subtitle: msg, problem: msg)
        }
        guard let port = nodePortProvider() else {
            return .fail(.nodeConnectivity, subtitle: String(localized: .DiagNodeNotSelected),
                         problem: String(localized: .DiagNodeNotSelected))
        }
        let portOK = await TCPConnectivity.canConnect(host: host, port: port)
        if portOK { return .pass(.nodeConnectivity) }
        let msg = String(format: String(localized: .DiagPortConnectFailed), host, port)
        return .fail(.nodeConnectivity, subtitle: msg, problem: msg)
    }

    private func checkProxyConnectivity() async -> CheckResult {
        let coreRunning = await runInBackground {
            ProcessChecker.isProcessRunning("v2ray") || ProcessChecker.isProcessRunning("xray")
        }
        guard coreRunning else {
            return .fail(.proxyConnectivity, subtitle: String(localized: .DiagCoreNotRunning),
                         problem: String(localized: .DiagCoreNotRunning), action: .startCore)
        }
        let ok = await testProxyConnectivity(socksPort: UInt16(localSocksPort))
        if ok { return .pass(.proxyConnectivity, String(localized: .DiagProxyConnectOK)) }
        return .fail(.proxyConnectivity, subtitle: String(localized: .DiagProxyConnectFailed),
                     problem: String(localized: .DiagProxyConnectFailed), action: .restartCore)
    }

    private func checkPingLatency() async -> CheckResult {
        guard appState.v2rayTurnOn else {
            return .fail(.pingLatency, subtitle: String(localized: .DiagCoreStopped),
                         problem: String(localized: .DiagCoreStopped))
        }
        let uuid = appState.runningProfile
        guard !uuid.isEmpty, let item = ProfileStore.shared.fetchOne(uuid: uuid) else {
            return .fail(.pingLatency, subtitle: String(localized: .DiagNodeNotSelected),
                         problem: String(localized: .DiagNodeNotSelected))
        }

        await PingAll.shared.pingOne(item: item)
        let latency = appState.latency

        if latency > 0 {
            let sub = latency < 300 ? "\(Int(latency))ms"
                : String(format: String(localized: .DiagLatencyHigh), Int(latency))
            return CheckResult(step: .pingLatency, ok: true, subtitle: sub, problem: nil, actionId: .rePing)
        }
        return CheckResult(step: .pingLatency, ok: false,
                           subtitle: String(localized: .DiagLatencyFailed),
                           problem: String(localized: .DiagLatencyFailed), actionId: .rePing)
    }

    // MARK: ── Log Check ──

    private func checkLogAnalysis() async -> CheckResult {
        let problems = await LogAnalyzer.analyze(logPath: logPath, lastLines: 500)
        let log = await LogAnalyzer.getSurroundingLog(logPath: logPath, lastLines: 500, contextLines: 3)

        let ok = problems.isEmpty || (problems.count == 1 && problems[0] == "未发现明显错误")
        self.logContent = log

        if ok { return .pass(.logAnalysis) }
        return .fail(.logAnalysis, subtitle: String(localized: .DiagFailed),
                     problem: problems.joined(separator: "\n"))
    }

    // MARK: ── Background helper ──

    /// Run a synchronous closure off the main actor to avoid blocking UI
    private func runInBackground<T: Sendable>(_ work: @escaping @Sendable () -> T) async -> T {
        await Task.detached(priority: .userInitiated) { work() }.value
    }

    // MARK: ── Process utilities (run off main) ──

    /// Read system proxy status synchronously (called from background)
    nonisolated private static func getSystemProxyStatusSync(type: String) -> (enabled: Bool, port: Int) {
        let task = Process()
        task.launchPath = "/usr/sbin/networksetup"
        let svc = DiagnosticsViewModel.getActiveNetworkServiceSync() ?? "Wi-Fi"

        switch type {
        case "socks": task.arguments = ["-getsocksfirewallproxy", svc]
        case "http":  task.arguments = ["-getwebproxy", svc]
        default:      return (false, 0)
        }

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            let enabled = output.lowercased().contains("enabled: yes")
            let portLine = output.split(separator: "\n").first { $0.lowercased().contains("port:") }
            let port = portLine.flatMap { Int($0.split(separator: " ").last ?? "0") } ?? 0
            return (enabled, port)
        } catch {
            return (false, 0)
        }
    }

    nonisolated private static func getActiveNetworkServiceSync() -> String? {
        let task = Process()
        task.launchPath = "/usr/sbin/networksetup"
        task.arguments = ["-listallnetworkservices"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            let services = output.split(separator: "\n").dropFirst()
            for service in services {
                let s = String(service).trimmingCharacters(in: .whitespaces)
                if s.lowercased().contains("wi-fi") { return s }
            }
            for service in services {
                let s = String(service).trimmingCharacters(in: .whitespaces)
                if s.lowercased().contains("ethernet") || s.lowercased().contains("thunderbolt") { return s }
            }
            for service in services {
                let s = String(service).trimmingCharacters(in: .whitespaces)
                if !s.hasPrefix("*") { return s }
            }
        } catch {}
        return nil
    }

    private func testProxyConnectivity(socksPort: UInt16) async -> Bool {
        let portOK = await runInBackground { ProcessChecker.isPortListening(Int(socksPort)) }
        guard portOK else { return false }

        return await runInBackground {
            let task = Process()
            task.launchPath = "/usr/bin/curl"
            task.arguments = [
                "--socks5", "127.0.0.1:\(socksPort)",
                "--connect-timeout", "5", "--max-time", "8",
                "-s", "-o", "/dev/null", "-w", "%{http_code}",
                "https://www.google.com/generate_204"
            ]
            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError = Pipe()
            do {
                try task.run()
                task.waitUntilExit()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let code = Int(output) ?? 0
                return code == 204 || code == 200
            } catch {
                return false
            }
        }
    }

    private func isARM64() -> Bool {
        #if arch(arm64)
        return true
        #else
        return false
        #endif
    }

    private func getFileArch(file: String) async -> String? {
        await Task.detached(priority: .userInitiated) {
            guard let data = try? Data(contentsOf: URL(fileURLWithPath: file)),
                  data.count >= 20 else { return nil }
            // Mach-O
            if data[0] == 0xCF && data[1] == 0xFA && data[2] == 0xED && data[3] == 0xFE {
                let cpuType = data.withUnsafeBytes { $0.load(fromByteOffset: 4, as: Int32.self) }
                switch cpuType {
                case 0x01000007: return "x86_64"
                case 0x0100000C: return "arm64"
                default:         return "unknown"
                }
            }
            // ELF
            if data[0] == 0x7F && data[1] == 0x45 && data[2] == 0x4C && data[3] == 0x46 {
                let eMachine = data.withUnsafeBytes { $0.load(fromByteOffset: 18, as: UInt16.self) }
                switch eMachine {
                case 62:  return "amd64"
                case 183: return "arm64"
                default:  return "unknown"
                }
            }
            return nil
        }.value
    }

    // MARK: ── User Actions ──

    private func doFixInstall() {
        checkTask?.cancel()
        checkTask = Task { @MainActor in
            await AppInstaller.shared.checkInstall()
            self.runSequentialChecks()
        }
    }

    private func doFixTool() {
        checkTask?.cancel()
        checkTask = Task { @MainActor in
            await AppInstaller.shared.checkInstall()
            self.runSequentialChecks()
        }
    }

    private func doFixGeoip() {
        checkTask?.cancel()
        checkTask = Task { @MainActor in
            await AppInstaller.shared.checkInstall()
            self.runSequentialChecks()
        }
    }

    private func doRestartCore() {
        checkTask?.cancel()
        checkTask = Task { @MainActor in
            await V2rayLaunch.shared.stop()
            try? await Task.sleep(nanoseconds: 300_000_000)
            await AppState.shared.turnOnCore()
            self.runSequentialChecks()
        }
    }

    private func doToggleCore() {
        checkTask?.cancel()
        checkTask = Task { @MainActor in
            if appState.v2rayTurnOn {
                await AppState.shared.turnOffCore()
            } else {
                await AppState.shared.turnOnCore()
            }
            try? await Task.sleep(nanoseconds: 500_000_000)
            self.runSequentialChecks()
        }
    }

    private func doPingNow() {
        checkTask?.cancel()
        checkTask = Task { @MainActor in
            await PingAll.shared.run()
            try? await Task.sleep(nanoseconds: 300_000_000)
            self.runSequentialChecks()
        }
    }

    private func openConfigFile() {
        NSWorkspace.shared.open(URL(fileURLWithPath: JsonConfigFilePath))
    }

    private func openSystemNetworkSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.network") {
            NSWorkspace.shared.open(url)
        } else {
            showOpenSettingsAlert = true
        }
    }

    // MARK: ── Report & Submit ──

    func generateReport() async -> String {
        let arch: String
        #if arch(arm64)
        arch = "arm64"
        #else
        arch = "x86_64"
        #endif

        var report = "## Environment\n"
        report += "- V2rayU: \(appVersion) | macOS: \(osVersion) | Arch: \(arch)\n"
        report += "- Core: \(coreVersion) | Mode: \(appState.runMode.rawValue) | Status: \(appState.v2rayTurnOn ? "ON" : "OFF")\n"
        report += "- SOCKS: \(localSocksPort) | HTTP: \(localHTTPPort)\n\n"

        report += "## Diagnostic Results\n"
        for category in DiagnosticCategory.allCases {
            let catItems = itemsFor(category)
            guard !catItems.isEmpty else { continue }
            report += "### \(category.rawValue)\n"
            for item in catItems {
                let icon = item.ok ? "✅" : "❌"
                report += "\(icon) \(item.title): \(item.subtitle)\n"
            }
            report += "\n"
        }

        if let server = appState.runningServer {
            report += "## Config (Sanitized)\n"
            report += "- Protocol: \(server.protocol.rawValue) | Network: \(server.network.rawValue) | Security: \(server.security.rawValue)\n"
            report += "- Port: \(server.port) | Addr: \(maskAddress(server.address))\n"
            if !server.sni.isEmpty { report += "- SNI: \(maskAddress(server.sni))\n" }
            report += "- Flow: \(server.flow.isEmpty ? "none" : server.flow) | ALPN: \(server.alpn.rawValue) | FP: \(server.fingerprint.rawValue)\n\n"
        }

        if !logContent.isEmpty && logContent != "无 INFO 及以上级别日志" {
            report += "## Error Logs\n```\n"
            let rawErr = await extractRawErrorLines(from: logPath, maxLines: 30)
            report += rawErr.isEmpty ? String(logContent.prefix(3000)) : rawErr
            report += "\n```\n"
        }
        return report
    }

    private func extractRawErrorLines(from logPath: String, maxLines: Int) async -> String {
        await runInBackground {
            guard let content = try? String(contentsOfFile: logPath, encoding: .utf8) else { return "" }
            let lines = content.components(separatedBy: .newlines).suffix(500)
            var errors: [String] = []
            for line in lines {
                let lower = line.lowercased()
                if lower.contains("[error]") || lower.contains("[warning]") ||
                   lower.contains("failed") || lower.contains("timeout") ||
                   lower.contains("rejected") || lower.contains("denied") {
                    errors.append(line)
                    if errors.count >= maxLines { break }
                }
            }
            return errors.joined(separator: "\n")
        }
    }

    private func maskAddress(_ addr: String) -> String {
        if addr.isEmpty { return "N/A" }
        if addr.range(of: #"^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$"#, options: .regularExpression) != nil {
            let parts = addr.split(separator: ".")
            if parts.count == 4 { return "***.***.***.\(parts[3])" }
        }
        let comps = addr.split(separator: ".")
        if comps.count >= 2 { return "***.\(comps.suffix(2).joined(separator: "."))" }
        return "***"
    }

    func submitToGitHub() {
        Task {
            let report = await generateReport()
            let title = "[Bug] V2rayU Diagnostic - \(Date().formatted(date: .abbreviated, time: .shortened))"
            let encodedTitle = title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            let encodedBody = report.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            let baseURL = "https://github.com/yanue/V2rayU/issues/new?title=\(encodedTitle)&body="
            let fullURL = baseURL + encodedBody

            if fullURL.count <= 8000, let url = URL(string: fullURL) {
                NSWorkspace.shared.open(url)
            } else {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(report, forType: .string)
                if let url = URL(string: "https://github.com/yanue/V2rayU/issues/new?title=\(encodedTitle)") {
                    NSWorkspace.shared.open(url)
                }
                makeToast(message: String(localized: .DiagReportCopied), displayDuration: 5)
            }
        }
    }
}
