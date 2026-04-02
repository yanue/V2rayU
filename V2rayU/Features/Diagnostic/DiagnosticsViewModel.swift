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
    @Published var items: [DiagnosticItem] = []
    @Published var checking: Bool = false
    @Published var showOpenSettingsAlert: Bool = false
    @Published var showFAQ: Bool = false
    @Published var progressText: String = ""
    @Published var showSubmitSheet: Bool = false
    @Published var logContent: String = ""
    
    var hasFailures: Bool {
        items.contains { !$0.ok }
    }
    
    // MARK: - 依赖（从实际配置读取端口）
    private let appState = AppState.shared
    private let v2rayUToolPath = v2rayUTool
    private let logPath = coreLogFilePath
    private var localSocksPort: Int { Int(getSocksProxyPort()) }
    private var localHTTPPort: Int { Int(getHttpProxyPort()) }
    private let nodeHostProvider: () -> String?
    private let nodePortProvider: () -> UInt16?

    init(nodeHostProvider: @escaping () -> String?, nodePortProvider: @escaping () -> UInt16?) {
        self.nodeHostProvider = nodeHostProvider
        self.nodePortProvider = nodePortProvider
        
        self.items = DiagnosticStep.allCheckSteps.map { makePendingItem(for: $0) }
    }
    
    func itemsForCategory(_ category: DiagnosticCategory) -> [DiagnosticItem] {
        items.filter { $0.category == category }
    }
    
    // MARK: - 逐项诊断

    func runSequentialChecks() {
        Task {
            withAnimation {
                self.checking = true
                self.progressText = "准备开始诊断…"
                self.items = DiagnosticStep.allCheckSteps.map { makePendingItem(for: $0) }
            }
            
            // 文件检查
            await step(.v2rayUToolInstall)  { await self.checkV2rayUToolInstall() }
            await step(.uToolPermission)    { await self.checkUToolPermission() }
            await step(.coreInstall)        { await self.checkCoreInstall() }
            await step(.coreArch)           { await self.checkCoreArch() }
            await step(.configFile)         { await self.checkConfigFile() }
            await step(.configValidity)     { await self.checkConfigValidity() }
            await step(.geoipFile)          { await self.checkGeoipFile() }
            await step(.geositeFile)        { await self.checkGeositeFile() }
            // 运行状态
            await step(.coreRunning)        { await self.checkCoreRunning() }
            await step(.systemProxy)        { await self.checkSystemProxy() }
            await step(.localPortConflict)  { await self.checkLocalPortConflict() }
            // 网络检查
            await step(.basicNetwork)       { await self.checkBasicNetwork() }
            await step(.nodeConnectivity)   { await self.checkNodeConnectivity() }
            await step(.proxyConnectivity)  { await self.checkProxyConnectivity() }
            await step(.pingLatency)        { await self.checkPingLatency() }
            // 日志
            await step(.logAnalysis)        { await self.checkLogAnalysis() }

            withAnimation {
                self.progressText = "诊断完成"
                self.checking = false
            }
        }
    }
    
    /// 步骤执行包装
    private func step(_ step: DiagnosticStep, action: () async -> DiagnosticItem) async {
        if let idx = items.firstIndex(where: { $0.step == step }) {
            withAnimation {
                self.progressText = "正在检查：\(title(for: step))"
                self.items[idx] = DiagnosticItem(
                    step: step,
                    title: items[idx].title,
                    subtitle: "正在检查…",
                    status: .checking,
                    ok: false,
                    problem: nil,
                    actionTitle: nil,
                    action: nil
                )
            }
        }
        
        let result = await action()
        
        if let idx = items.firstIndex(where: { $0.step == step }) {
            withAnimation {
                self.items[idx] = result
            }
        }
        
        try? await Task.sleep(nanoseconds: 200_000_000)
    }
    
    // MARK: - Helpers
    
    private func makePendingItem(for step: DiagnosticStep) -> DiagnosticItem {
        DiagnosticItem(
            step: step,
            title: title(for: step),
            subtitle: "等待检查…",
            status: .pending,
            ok: false,
            problem: nil,
            actionTitle: nil,
            action: nil
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
        case .systemProxy:       return String(localized: .DiagSystemProxy)
        case .localPortConflict: return String(localized: .DiagLocalPortConflict)
        case .basicNetwork:      return String(localized: .DiagBasicNetwork)
        case .nodeConnectivity:  return String(localized: .DiagNetworkConnectivity)
        case .proxyConnectivity: return String(localized: .DiagProxyConnectivity)
        case .pingLatency:       return String(localized: .DiagPingLatency)
        case .logAnalysis:       return String(localized: .DiagLogAnalysis)
        }
    }

    // MARK: - 文件检查

    private func checkV2rayUToolInstall() async -> DiagnosticItem {
        let exists = FileManager.default.fileExists(atPath: v2rayUToolPath)
        let executable = exists && FileManager.default.isExecutableFile(atPath: v2rayUToolPath)

        let subtitle: String
        let problem: String?

        if executable {
            subtitle = String(localized: .DiagPassed)
            problem = nil
        } else if exists {
            subtitle = String(localized: .DiagToolNoPermission)
            problem = String(localized: .DiagToolNoPermission)
        } else {
            subtitle = String(localized: .DiagToolMissing)
            problem = String(localized: .DiagToolMissing)
        }

        return DiagnosticItem(
            step: .v2rayUToolInstall,
            title: String(localized: .DiagV2rayUToolInstall),
            subtitle: subtitle,
            ok: executable,
            problem: problem,
            actionTitle: executable ? nil : String(localized: .DiagFixNow),
            action: executable ? nil : { self.fixV2rayUTool() }
        )
    }

    private func checkUToolPermission() async -> DiagnosticItem {
        let toolExists = FileManager.default.fileExists(atPath: v2rayUToolPath)
        let hasPermission = toolExists && checkFileIsRootAdmin(file: v2rayUToolPath)

        let subtitle: String
        let problem: String?

        if hasPermission {
            subtitle = String(localized: .DiagPassed)
            problem = nil
        } else if !toolExists {
            subtitle = String(localized: .DiagToolMissing)
            problem = String(localized: .DiagToolMissing)
        } else {
            subtitle = String(localized: .DiagToolNoPermission)
            problem = String(localized: .DiagToolNoPermission)
        }

        return DiagnosticItem(
            step: .uToolPermission,
            title: String(localized: .DiagUToolPermission),
            subtitle: subtitle,
            ok: hasPermission,
            problem: problem,
            actionTitle: hasPermission ? nil : String(localized: .DiagFixNow),
            action: hasPermission ? nil : { self.fixV2rayUTool() }
        )
    }

    private func checkCoreInstall() async -> DiagnosticItem {
        let installed = FileManager.default.fileExists(atPath: xrayCoreFile)
        let executable = installed && FileManager.default.isExecutableFile(atPath: xrayCoreFile)
        let version = executable ? getCoreVersion() : ""
        
        let subtitle: String
        let problem: String?
        
        if executable {
            subtitle = String(format: String(localized: .DiagPassed), version)
            problem = nil
        } else if installed {
            subtitle = String(localized: .DiagCoreNotExecutable)
            problem = String(localized: .DiagCoreNotExecutable)
        } else {
            subtitle = String(localized: .DiagCoreNotInstalled)
            problem = String(localized: .DiagCoreNotInstalled)
        }
        
        return DiagnosticItem(
            step: .coreInstall,
            title: String(localized: .DiagCoreInstall),
            subtitle: subtitle,
            ok: executable,
            problem: problem,
            actionTitle: executable ? nil : String(localized: .DiagFixNow),
            action: executable ? nil : { self.fixInstallAll() }
        )
    }
    
    private func checkCoreArch() async -> DiagnosticItem {
        let installed = FileManager.default.fileExists(atPath: xrayCoreFile)
        let executable = installed && FileManager.default.isExecutableFile(atPath: xrayCoreFile)
        
        let currentArch = isARM64() ? "arm64" : "amd64"
        let actualArch = executable ? getFileArch(file: xrayCoreFile) : nil
        let ok = actualArch == currentArch
        
        let subtitle: String
        let problem: String?
        
        if !installed {
            subtitle = String(localized: .DiagCoreNotInstalled)
            problem = String(localized: .DiagCoreNotInstalled)
        } else if !executable {
            subtitle = String(localized: .DiagCoreNotExecutable)
            problem = String(localized: .DiagCoreNotExecutable)
        } else if ok {
            subtitle = String(format: String(localized: .DiagCoreArchCorrect), actualArch ?? "unknown")
            problem = nil
        } else {
            subtitle = String(format: String(localized: .DiagCoreArchMismatch), actualArch ?? "unknown", currentArch)
            problem = String(format: String(localized: .DiagCoreArchMismatch), actualArch ?? "unknown", currentArch)
        }
        
        return DiagnosticItem(
            step: .coreArch,
            title: String(localized: .DiagCoreArch),
            subtitle: subtitle,
            ok: ok,
            problem: problem,
            actionTitle: ok ? nil : String(localized: .DiagFixNow),
            action: ok ? nil : { self.fixInstallAll() }
        )
    }
    
    private func checkConfigFile() async -> DiagnosticItem {
        let exists = FileManager.default.fileExists(atPath: JsonConfigFilePath)

        let subtitle: String
        let problem: String?

        if exists {
            let fileSize = (try? FileManager.default.attributesOfItem(atPath: JsonConfigFilePath)[.size] as? Int) ?? 0
            if fileSize > 0 {
                subtitle = String(format: String(localized: .DiagConfigFileExists), fileSize)
                problem = nil
            } else {
                subtitle = String(localized: .DiagConfigFileEmpty)
                problem = String(localized: .DiagConfigFileEmpty)
            }
        } else {
            subtitle = String(localized: .DiagConfigFileMissing)
            problem = String(localized: .DiagConfigFileMissing)
        }

        return DiagnosticItem(
            step: .configFile,
            title: String(localized: .DiagConfigFile),
            subtitle: subtitle,
            ok: exists && ((try? FileManager.default.attributesOfItem(atPath: JsonConfigFilePath)[.size] as? Int) ?? 0) > 0,
            problem: problem,
            actionTitle: exists ? nil : String(localized: .DiagFixNow),
            action: exists ? nil : { self.fixInstallAll() }
        )
    }

    /// 新增：配置文件 JSON 合法性 + 字段完整性检查
    private func checkConfigValidity() async -> DiagnosticItem {
        let (isValid, problems) = ConfigValidator.validateConfig(filePath: JsonConfigFilePath)

        let subtitle: String
        let problem: String?

        if isValid {
            subtitle = String(localized: .DiagConfigValidOK)
            problem = nil
        } else {
            let joined = problems.joined(separator: "; ")
            subtitle = String(localized: .DiagFailed)
            problem = String(format: String(localized: .DiagConfigValidProblems), joined)
        }

        return DiagnosticItem(
            step: .configValidity,
            title: String(localized: .DiagConfigValidity),
            subtitle: subtitle,
            ok: isValid,
            problem: problem,
            actionTitle: isValid ? nil : String(localized: .DiagViewConfig),
            action: isValid ? nil : { self.openConfigFile() }
        )
    }

    private func checkGeoipFile() async -> DiagnosticItem {
        let exists = FileManager.default.fileExists(atPath: xrayCorePath + "/geoip.dat")

        let subtitle: String
        let problem: String?

        if exists {
            subtitle = String(localized: .DiagPassed)
            problem = nil
        } else {
            subtitle = String(localized: .DiagGeoipMissing)
            problem = String(localized: .DiagGeoipMissing)
        }

        return DiagnosticItem(
            step: .geoipFile,
            title: String(localized: .DiagGeoipFile),
            subtitle: subtitle,
            ok: exists,
            problem: problem,
            actionTitle: exists ? nil : String(localized: .DiagFixNow),
            action: exists ? nil : { self.fixGeoip() }
        )
    }

    private func checkGeositeFile() async -> DiagnosticItem {
        let exists = FileManager.default.fileExists(atPath: xrayCorePath + "/geosite.dat")

        let subtitle: String
        let problem: String?

        if exists {
            subtitle = String(localized: .DiagPassed)
            problem = nil
        } else {
            subtitle = String(localized: .DiagGeositeMissing)
            problem = String(localized: .DiagGeositeMissing)
        }

        return DiagnosticItem(
            step: .geositeFile,
            title: String(localized: .DiagGeositeFile),
            subtitle: subtitle,
            ok: exists,
            problem: problem,
            actionTitle: exists ? nil : String(localized: .DiagFixNow),
            action: exists ? nil : { self.fixGeoip() }
        )
    }

    // MARK: - 运行状态检查

    private func checkCoreRunning() async -> DiagnosticItem {
        let running = ProcessChecker.isProcessRunning("v2ray") || ProcessChecker.isProcessRunning("xray")
        
        let subtitle: String
        let problem: String?
        
        if running {
            subtitle = String(localized: .DiagPassed)
            problem = nil
        } else if !appState.v2rayTurnOn {
            subtitle = String(localized: .DiagCoreStopped)
            problem = String(localized: .DiagCoreStopped)
        } else {
            subtitle = String(localized: .DiagCoreStartFailed)
            problem = String(localized: .DiagCoreStartFailed)
        }
        
        return DiagnosticItem(
            step: .coreRunning,
            title: String(localized: .DiagCoreRunning),
            subtitle: subtitle,
            ok: running,
            problem: problem,
            actionTitle: running ? String(localized: .DiagRestartCore) : String(localized: .DiagStartCore),
            action: running ? { self.restartCore() } : { self.toggleCoreOnOff() }
        )
    }
    
    /// 新增：系统代理状态检查
    private func checkSystemProxy() async -> DiagnosticItem {
        let runMode = appState.runMode

        // TUN / Manual 模式不需要系统代理
        if runMode == .tun {
            return DiagnosticItem(
                step: .systemProxy,
                title: String(localized: .DiagSystemProxy),
                subtitle: String(localized: .DiagProxyNotNeededTunnel),
                ok: true,
                problem: nil,
                actionTitle: nil,
                action: nil
            )
        }

        if runMode == .manual {
            return DiagnosticItem(
                step: .systemProxy,
                title: String(localized: .DiagSystemProxy),
                subtitle: String(localized: .DiagProxyNotNeededManual),
                ok: true,
                problem: nil,
                actionTitle: nil,
                action: nil
            )
        }

        if !appState.v2rayTurnOn {
            return DiagnosticItem(
                step: .systemProxy,
                title: String(localized: .DiagSystemProxy),
                subtitle: String(localized: .DiagProxyNotNeededOff),
                ok: true,
                problem: nil,
                actionTitle: nil,
                action: nil
            )
        }
        
        // PAC / Global 模式需要系统代理
        let (socksEnabled, socksPort) = getSystemProxyStatus(type: "socks")
        let (httpEnabled, httpPort) = getSystemProxyStatus(type: "http")

        let expectedSocks = localSocksPort
        let expectedHTTP = localHTTPPort

        let socksOK = socksEnabled && socksPort == expectedSocks
        let httpOK = httpEnabled && httpPort == expectedHTTP
        let ok = socksOK || httpOK

        let subtitle: String
        let problem: String?
        
        if ok {
            let port = socksOK ? expectedSocks : expectedHTTP
            subtitle = String(format: String(localized: .DiagSystemProxyOK), port)
            problem = nil
        } else if !socksEnabled && !httpEnabled {
            subtitle = String(localized: .DiagProxyNotEnabled)
            problem = String(localized: .DiagProxyNotEnabled)
        } else {
            let currentPort = socksEnabled ? socksPort : httpPort
            let expectedPort = socksEnabled ? expectedSocks : expectedHTTP
            subtitle = String(format: String(localized: .DiagProxyPortMismatch), currentPort, expectedPort)
            problem = String(format: String(localized: .DiagProxyPortMismatch), currentPort, expectedPort)
        }
        
        return DiagnosticItem(
            step: .systemProxy,
            title: String(localized: .DiagSystemProxy),
            subtitle: subtitle,
            ok: ok,
            problem: problem,
            actionTitle: ok ? nil : String(localized: .DiagOpenNetworkSettings),
            action: ok ? nil : { self.openSystemNetworkSettings() }
        )
    }

    private func checkLocalPortConflict() async -> DiagnosticItem {
        let socksPort = localSocksPort
        let httpPort = localHTTPPort
        let socksListening = ProcessChecker.isPortListening(socksPort)
        let httpListening = ProcessChecker.isPortListening(httpPort)
        let coreRunning = ProcessChecker.isProcessRunning("v2ray") || ProcessChecker.isProcessRunning("xray")
        
        let conflictSocks = socksListening && !coreRunning
        let conflictHTTP = httpListening && !coreRunning
        let ok = !(conflictSocks || conflictHTTP)
        
        let ownerSocks = ProcessChecker.portOwner(socksPort) ?? "未知"
        let ownerHTTP = ProcessChecker.portOwner(httpPort) ?? "未知"

        let subtitle: String
        let problem: String?
        
        if !socksListening && !httpListening {
            subtitle = String(localized: .DiagPassed)
            problem = nil
        } else if coreRunning {
            subtitle = String(localized: .DiagPassed)
            problem = nil
        } else if conflictSocks || conflictHTTP {
            subtitle = String(localized: .DiagPortOccupied)
            if conflictSocks {
                problem = String(format: String(localized: .DiagPortOccupied), socksPort, ownerSocks)
            } else {
                problem = String(format: String(localized: .DiagPortOccupied), httpPort, ownerHTTP)
            }
        } else {
            subtitle = String(localized: .DiagPassed)
            problem = nil
        }
        
        return DiagnosticItem(
            step: .localPortConflict,
            title: String(localized: .DiagLocalPortConflict),
            subtitle: subtitle,
            ok: ok,
            problem: problem,
            actionTitle: ok ? nil : String(localized: .DiagFixNow),
            action: ok ? nil : { self.restartCore() }
        )
    }
    
    // MARK: - 网络检查

    /// 新增：基础网络连通性（不走代理，测试 apple.com）
    private func checkBasicNetwork() async -> DiagnosticItem {
        let reachable = await NetworkChecker.canResolve(host: "www.apple.com", timeout: 5)

        let subtitle: String
        let problem: String?
        
        if reachable {
            subtitle = String(localized: .DiagBasicNetworkOK)
            problem = nil
        } else {
            subtitle = String(localized: .DiagBasicNetworkFailed)
            problem = String(localized: .DiagBasicNetworkFailed)
        }
        
        return DiagnosticItem(
            step: .basicNetwork,
            title: String(localized: .DiagBasicNetwork),
            subtitle: subtitle,
            ok: reachable,
            problem: problem,
            actionTitle: reachable ? nil : String(localized: .DiagCheckNetwork),
            action: reachable ? nil : { self.openSystemNetworkSettings() }
        )
    }
    
    private func checkNodeConnectivity() async -> DiagnosticItem {
        guard let host = nodeHostProvider() else {
            return DiagnosticItem(
                step: .nodeConnectivity,
                title: String(localized: .DiagNetworkConnectivity),
                subtitle: String(localized: .DiagNodeNotSelected),
                ok: false,
                problem: String(localized: .DiagNodeNotSelected),
                actionTitle: nil,
                action: nil
            )
        }

        let dnsOK = await NetworkChecker.canResolve(host: host)

        guard let port = nodePortProvider() else {
            return DiagnosticItem(
                step: .nodeConnectivity,
                title: String(localized: .DiagNetworkConnectivity),
                subtitle: String(localized: .DiagNodeNotSelected),
                ok: false,
                problem: String(localized: .DiagNodeNotSelected),
                actionTitle: nil,
                action: nil
            )
        }

        let portOK = dnsOK ? await TCPConnectivity.canConnect(host: host, port: port) : false

        let ok = dnsOK && portOK
        let subtitle: String
        let problem: String?
        
        if dnsOK && portOK {
            subtitle = String(localized: .DiagPassed)
            problem = nil
        } else if !dnsOK {
            subtitle = String(format: String(localized: .DiagDNSResolveFailed), host)
            problem = String(format: String(localized: .DiagDNSResolveFailed), host)
        } else {
            subtitle = String(format: String(localized: .DiagPortConnectFailed), host, port)
            problem = String(format: String(localized: .DiagPortConnectFailed), host, port)
        }
        
        return DiagnosticItem(
            step: .nodeConnectivity,
            title: String(localized: .DiagNetworkConnectivity),
            subtitle: subtitle,
            ok: ok,
            problem: problem,
            actionTitle: nil,
            action: nil
        )
    }
    
    /// 新增：通过本地代理端口访问外网
    private func checkProxyConnectivity() async -> DiagnosticItem {
        let coreRunning = ProcessChecker.isProcessRunning("v2ray") || ProcessChecker.isProcessRunning("xray")

        if !coreRunning {
            return DiagnosticItem(
                step: .proxyConnectivity,
                title: String(localized: .DiagProxyConnectivity),
                subtitle: String(localized: .DiagCoreNotRunning),
                ok: false,
                problem: String(localized: .DiagCoreNotRunning),
                actionTitle: String(localized: .DiagStartCore),
                action: { self.toggleCoreOnOff() }
            )
        }

        // 通过本地 SOCKS 代理端口测试连通性
        let proxyOK = await testProxyConnectivity(socksPort: UInt16(localSocksPort))

        let subtitle: String
        let problem: String?
        
        if proxyOK {
            subtitle = String(localized: .DiagProxyConnectOK)
            problem = nil
        } else {
            subtitle = String(localized: .DiagProxyConnectFailed)
            problem = String(localized: .DiagProxyConnectFailed)
        }
        
        return DiagnosticItem(
            step: .proxyConnectivity,
            title: String(localized: .DiagProxyConnectivity),
            subtitle: subtitle,
            ok: proxyOK,
            problem: problem,
            actionTitle: proxyOK ? nil : String(localized: .DiagRestartCore),
            action: proxyOK ? nil : { self.restartCore() }
        )
    }
    
    private func checkPingLatency() async -> DiagnosticItem {
        await PingAll.shared.run()
        let latency = appState.latency
        
        let subtitle: String
        let problem: String?
        let ok: Bool
        
        if latency > 0 {
            ok = true
            if latency < 300 {
                subtitle = "\(Int(latency))ms"
            } else {
                subtitle = String(format: String(localized: .DiagLatencyHigh), Int(latency))
            }
            problem = nil
        } else {
            ok = false
            subtitle = String(localized: .DiagLatencyFailed)
            problem = String(localized: .DiagLatencyFailed)
        }
        
        return DiagnosticItem(
            step: .pingLatency,
            title: String(localized: .DiagPingLatency),
            subtitle: subtitle,
            ok: ok,
            problem: problem,
            actionTitle: String(localized: .DiagReTest),
            action: { self.doPingNow() }
        )
    }
    
    // MARK: - 日志检查

    private func checkLogAnalysis() async -> DiagnosticItem {
        let problems = LogAnalyzer.analyze(logPath: logPath, lastLines: 500)
        self.logContent = LogAnalyzer.getSurroundingLog(logPath: logPath, lastLines: 500, contextLines: 3)
        let ok = problems.isEmpty || (problems.count == 1 && problems[0] == "未发现明显错误")
        return DiagnosticItem(
            step: .logAnalysis,
            title: String(localized: .DiagLogAnalysis),
            subtitle: ok ? String(localized: .DiagPassed) : String(localized: .DiagFailed),
            ok: ok,
            problem: ok ? nil : problems.joined(separator: "\n"),
            actionTitle: nil,
            action: nil
        )
    }
    
    // MARK: - 操作项

    private func openConfigFile() {
        let url = URL(fileURLWithPath: JsonConfigFilePath)
        NSWorkspace.shared.open(url)
    }
    
    private func openSystemNetworkSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.network") {
            NSWorkspace.shared.open(url)
        } else {
            showOpenSettingsAlert = true
        }
    }

    private func fixInstallAll() {
        Task {
            await AppInstaller.shared.checkInstall()
            await MainActor.run { self.runSequentialChecks() }
        }
    }
    
    private func fixV2rayUTool() {
        Task {
            await AppInstaller.shared.checkInstall()
            await MainActor.run { self.runSequentialChecks() }
        }
    }
    
    private func fixGeoip() {
        Task {
            await AppInstaller.shared.checkInstall()
            await MainActor.run { self.runSequentialChecks() }
        }
    }
    
    private func restartCore() {
        Task {
            await V2rayLaunch.shared.stop()
            try? await Task.sleep(nanoseconds: 300_000_000)
            await AppState.shared.turnOnCore()
            await MainActor.run { self.runSequentialChecks() }
        }
    }
    
    private func toggleCoreOnOff() {
        Task {
            if appState.v2rayTurnOn {
                await AppState.shared.turnOffCore()
            } else {
                await AppState.shared.turnOnCore()
            }
            try? await Task.sleep(nanoseconds: 500_000_000)
            await MainActor.run { self.runSequentialChecks() }
        }
    }
    
    private func doPingNow() {
        Task {
            await PingAll.shared.run()
            try? await Task.sleep(nanoseconds: 300_000_000)
            await MainActor.run { self.runSequentialChecks() }
        }
    }
    
    // MARK: - 系统代理状态读取

    /// 读取系统代理状态（支持 socks / http）
    private func getSystemProxyStatus(type: String) -> (enabled: Bool, port: Int) {
        let task = Process()
        task.launchPath = "/usr/sbin/networksetup"

        let networkService = getActiveNetworkService() ?? "Wi-Fi"

        switch type {
        case "socks":
            task.arguments = ["-getsocksfirewallproxy", networkService]
        case "http":
            task.arguments = ["-getwebproxy", networkService]
        default:
            return (false, 0)
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
    
    /// 获取当前活跃的网络服务名称
    private func getActiveNetworkService() -> String? {
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
            return nil
        } catch {
            return nil
        }
    }

    /// 通过 SOCKS 代理测试连通性（连接 google.com generate_204）
    private func testProxyConnectivity(socksPort: UInt16) async -> Bool {
        let portOK = ProcessChecker.isPortListening(Int(socksPort))
        guard portOK else { return false }

        return await withCheckedContinuation { cont in
            let task = Process()
            task.launchPath = "/usr/bin/curl"
            task.arguments = [
                "--socks5", "127.0.0.1:\(socksPort)",
                "--connect-timeout", "5",
                "--max-time", "8",
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
                cont.resume(returning: code == 204 || code == 200)
            } catch {
                cont.resume(returning: false)
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
    
    private func getFileArch(file: String) -> String? {
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: file))
            guard data.count >= 20 else { return nil }
            
            if data[0] == 0x7F && data[1] == 0x45 && data[2] == 0x4C && data[3] == 0x46 {
                let eMachine = data.withUnsafeBytes { $0.load(fromByteOffset: 18, as: UInt16.self) }
                switch eMachine {
                case 62: return "amd64"
                case 183: return "arm64"
                default: return "unknown"
                }
            }
            else if data[0] == 0xCF && data[1] == 0xFA && data[2] == 0xED && data[3] == 0xFE {
                let cpuType = data.withUnsafeBytes { $0.load(fromByteOffset: 4, as: Int32.self) }
                switch cpuType {
                case 0x01000007: return "x86_64"
                case 0x0100000C: return "arm64"
                default: return "unknown"
                }
            }
            
            return nil
        } catch {
            return nil
        }
    }
    
    // MARK: - 提交诊断报告（精简版：事实 + 脱敏配置 + 原始错误日志）

    /// 生成精简诊断报告（只保留事实，不含推断建议）
    func generateReport() -> String {
        let arch: String
        #if arch(arm64)
        arch = "arm64"
        #else
        arch = "x86_64"
        #endif

        // === 环境信息 ===
        var report = "## Environment\n"
        report += "- V2rayU: \(appVersion) | macOS: \(osVersion) | Arch: \(arch)\n"
        report += "- Core: \(coreVersion) | Mode: \(appState.runMode.rawValue) | Status: \(appState.v2rayTurnOn ? "ON" : "OFF")\n"
        report += "- SOCKS: \(localSocksPort) | HTTP: \(localHTTPPort)\n\n"

        // === 全部检查结果（每项只保留 ✅/❌ + 简短事实） ===
        report += "## Diagnostic Results\n"
        for category in DiagnosticCategory.allCases {
            let categoryItems = itemsForCategory(category)
            if categoryItems.isEmpty { continue }
            report += "### \(category.rawValue)\n"
            for item in categoryItems {
                let icon = item.ok ? "✅" : "❌"
                let detail = item.subtitle ?? item.defaultSubtitle
                report += "\(icon) \(item.title): \(detail)\n"
            }
            report += "\n"
        }

        // === 脱敏配置 ===
        if let server = appState.runningServer {
            report += "## Config (Sanitized)\n"
            report += "- Protocol: \(server.protocol.rawValue) | Network: \(server.network.rawValue) | Security: \(server.security.rawValue)\n"
            report += "- Port: \(server.port) | Addr: \(maskAddress(server.address))\n"
            if !server.sni.isEmpty {
                report += "- SNI: \(maskAddress(server.sni))\n"
            }
            report += "- Flow: \(server.flow.isEmpty ? "none" : server.flow) | ALPN: \(server.alpn.rawValue) | FP: \(server.fingerprint.rawValue)\n\n"
        }

        // === 错误日志（只提取原始 error/warning 行） ===
        if !logContent.isEmpty && logContent != "无 INFO 及以上级别日志" {
            report += "## Error Logs\n```\n"
            let rawErrorLines = extractRawErrorLines(from: logPath, maxLines: 30)
            if !rawErrorLines.isEmpty {
                report += rawErrorLines
            } else {
                report += String(logContent.prefix(3000))
            }
            report += "\n```\n"
        }

        return report
    }

    /// 提取原始 error/warning 日志行（不含推断，只要原始日志）
    private func extractRawErrorLines(from logPath: String, maxLines: Int) -> String {
        guard let content = try? String(contentsOfFile: logPath, encoding: .utf8) else { return "" }
        let lines = content.components(separatedBy: .newlines)
        let recentLines = Array(lines.suffix(500))

        var errorLines: [String] = []
        for line in recentLines {
            let lower = line.lowercased()
            if lower.contains("[error]") || lower.contains("[warning]") ||
               lower.contains("failed") || lower.contains("timeout") ||
               lower.contains("rejected") || lower.contains("denied") {
                errorLines.append(line)
            }
            if errorLines.count >= maxLines { break }
        }

        return errorLines.joined(separator: "\n")
    }

    /// 地址脱敏：example.com → ***.example.com, IP → ***.***.***.123
    private func maskAddress(_ addr: String) -> String {
        if addr.isEmpty { return "N/A" }

        // IP 地址脱敏
        let ipPattern = #"^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$"#
        if addr.range(of: ipPattern, options: .regularExpression) != nil {
            let parts = addr.split(separator: ".")
            if parts.count == 4 {
                return "***.***.***.\(parts[3])"
            }
        }

        // 域名脱敏：保留最后两级
        let components = addr.split(separator: ".")
        if components.count >= 2 {
            let lastTwo = components.suffix(2).joined(separator: ".")
            return "***.\(lastTwo)"
        }

        return "***"
    }

    // MARK: - 提交到 GitHub（带字符预算管理和剪贴板兜底）

    func submitToGitHub() {
        let report = generateReport()
        let title = "[Bug] V2rayU Diagnostic - \(Date().formatted(date: .abbreviated, time: .shortened))"
        let encodedTitle = title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedBody = report.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

        let baseURL = "https://github.com/yanue/V2rayU/issues/new?title=\(encodedTitle)&body="
        let fullURL = baseURL + encodedBody

        // GitHub URL 限制约 8192 字符
        let maxURLLength = 8000

        if fullURL.count <= maxURLLength {
            if let url = URL(string: fullURL) {
                NSWorkspace.shared.open(url)
            }
        } else {
            // 超出限制：复制到剪贴板 + 打开空 issue 页面
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(report, forType: .string)

            let fallbackURL = "https://github.com/yanue/V2rayU/issues/new?title=\(encodedTitle)"
            if let url = URL(string: fallbackURL) {
                NSWorkspace.shared.open(url)
            }

            makeToast(message: String(localized: .DiagReportCopied), displayDuration: 5)
        }
    }
}
