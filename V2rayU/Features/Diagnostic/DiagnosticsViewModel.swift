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
        case .appDataDir:        return String(localized: .DiagAppDataDir)
        case .v2rayUTool:        return String(localized: .DiagV2rayUTool)
        case .xrayCore:          return String(localized: .DiagXrayCore)
        case .singBox:           return String(localized: .DiagSingBox)
        case .updateScript:      return String(localized: .DiagUpdateScript)
        case .sudoersCheck:      return String(localized: .DiagSudoersCheck)
        case .tunDaemon:         return String(localized: .DiagTunDaemon)
        case .configCheck:       return String(localized: .DiagConfigCheck)
        case .geoDataFiles:      return String(localized: .DiagGeoDataFiles)
        case .coreRunning:       return String(localized: .DiagCoreRunning)
        case .launchdProcess:    return String(localized: .DiagLaunchdProcess)
        case .systemProxy:       return String(localized: .DiagSystemProxy)
        case .localPortConflict: return String(localized: .DiagLocalPortConflict)
        case .basicNetwork:      return String(localized: .DiagBasicNetwork)
        case .nodeConnectivity:  return String(localized: .DiagNetworkConnectivity)
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
        case .appDataDir:        return await checkAppDataDir()
        case .v2rayUTool:        return await checkV2rayUTool()
        case .xrayCore:          return await checkXrayCore()
        case .singBox:           return await checkSingBox()
        case .updateScript:      return await checkUpdateScript()
        case .sudoersCheck:      return await checkSudoers()
        case .tunDaemon:         return await checkTunDaemon()
        case .configCheck:       return await checkConfig()
        case .geoDataFiles:      return await checkGeoDataFiles()
        case .coreRunning:       return await checkCoreRunning()
        case .launchdProcess:    return await checkLaunchdProcess()
        case .systemProxy:       return await checkSystemProxy()
        case .localPortConflict: return await checkLocalPortConflict()
        case .basicNetwork:      return await checkBasicNetwork()
        case .nodeConnectivity:  return await checkNodeConnectivity()
        case .pingLatency:       return await checkPingLatency()
        case .logAnalysis:       return await checkLogAnalysis()
        }
    }

    // MARK: ── File Checks ──

    /// ~/.V2rayU 目录: 存在 → 可写 → owner → .V2rayU.db 存在 → db可写
    private func checkAppDataDir() async -> CheckResult {
        let dirPath = AppHomePath
        let dbPath = databasePath
        let fm = FileManager.default
        var details: [String] = []

        // ① 目录存在
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: dirPath, isDirectory: &isDir), isDir.boolValue else {
            return .fail(.appDataDir, subtitle: String(localized: .DiagAppDataDirMissing),
                         problem: String(localized: .DiagAppDataDirMissing), action: .fixInstall)
        }
        details.append("✓ \(String(localized: .DiagSubDirExists))")

        // ② 目录可写
        guard fm.isWritableFile(atPath: dirPath) else {
            details.append("✗ \(String(localized: .DiagSubDirNotWritable))")
            return .fail(.appDataDir, subtitle: details.joined(separator: "\n"),
                         problem: String(localized: .DiagAppDataDirNotWritable), action: .fixInstall)
        }
        details.append("✓ \(String(localized: .DiagSubDirWritable))")

        // ③ 目录 owner 是当前用户
        let ownerOk = await runInBackground {
            do {
                let attrs = try FileManager.default.attributesOfItem(atPath: dirPath)
                let owner = attrs[.ownerAccountName] as? String ?? ""
                return owner == NSUserName()
            } catch {
                return false
            }
        }
        if !ownerOk {
            details.append("✗ \(String(localized: .DiagSubDirOwnerWrong))")
            return .fail(.appDataDir, subtitle: details.joined(separator: "\n"),
                         problem: String(localized: .DiagAppDataDirOwnerWrong), action: .fixInstall)
        }
        details.append("✓ \(String(localized: .DiagSubDirOwnerOK))")

        // ④ 数据库文件存在
        guard fm.fileExists(atPath: dbPath) else {
            // db 不存在不一定是错误（首次启动会自动创建），但标记为信息
            details.append("⚠ \(String(localized: .DiagSubDbNotExists))")
            return .pass(.appDataDir, details.joined(separator: "\n"))
        }
        details.append("✓ \(String(localized: .DiagSubDbExists))")

        // ⑤ 数据库文件可写（readonly 问题诊断关键）
        guard fm.isWritableFile(atPath: dbPath) else {
            details.append("✗ \(String(localized: .DiagSubDbReadonly))")
            return .fail(.appDataDir, subtitle: details.joined(separator: "\n"),
                         problem: String(localized: .DiagDbReadonly), action: .fixInstall)
        }
        details.append("✓ \(String(localized: .DiagSubDbWritable))")

        // ⑥ 数据库 WAL/SHM 文件可写（SQLite WAL 模式需要）
        let walPath = dbPath + "-wal"
        let shmPath = dbPath + "-shm"
        for (path, name) in [(walPath, "WAL"), (shmPath, "SHM")] {
            if fm.fileExists(atPath: path) && !fm.isWritableFile(atPath: path) {
                details.append("✗ \(name) \(String(localized: .DiagSubDbReadonly))")
                return .fail(.appDataDir, subtitle: details.joined(separator: "\n"),
                             problem: String(localized: .DiagDbReadonly), action: .fixInstall)
            }
        }

        return .pass(.appDataDir, details.joined(separator: "\n"))
    }

    /// V2rayUTool: 存在 → 可执行 → root:admin → setuid(+s) → 隔离标记 → 版本
    private func checkV2rayUTool() async -> CheckResult {
        let path = v2rayUTool
        var details: [String] = []

        // ① 文件存在
        guard FileManager.default.fileExists(atPath: path) else {
            return .fail(.v2rayUTool, subtitle: String(localized: .DiagToolMissing),
                         problem: String(localized: .DiagToolMissing), action: .fixTool)
        }
        details.append("✓ \(String(localized: .DiagSubFileExists))")

        // ② 可执行
        guard FileManager.default.isExecutableFile(atPath: path) else {
            details.append("✗ \(String(localized: .DiagSubNotExecutable))")
            return .fail(.v2rayUTool, subtitle: details.joined(separator: "\n"),
                         problem: String(localized: .DiagToolNoPermission), action: .fixTool)
        }
        details.append("✓ \(String(localized: .DiagSubExecutable))")

        // ③ root:admin 权限
        let isRootAdmin = checkFileIsRootAdmin(file: path)
        if !isRootAdmin {
            details.append("✗ \(String(localized: .DiagSubNotRootAdmin))")
            return .fail(.v2rayUTool, subtitle: details.joined(separator: "\n"),
                         problem: String(localized: .DiagToolNoPermission), action: .fixTool)
        }
        details.append("✓ \(String(localized: .DiagSubRootAdmin))")

        // ④ setuid(+s) 权限
        let hasSetuid = await runInBackground {
            do {
                let attrs = try FileManager.default.attributesOfItem(atPath: path)
                if let perms = attrs[.posixPermissions] as? Int {
                    return (perms & 0o4000) != 0  // S_ISUID
                }
            } catch {}
            return false
        }
        if !hasSetuid {
            details.append("✗ \(String(localized: .DiagSubNoSetuid))")
            return .fail(.v2rayUTool, subtitle: details.joined(separator: "\n"),
                         problem: String(localized: .DiagToolNoSetuid), action: .fixTool)
        }
        details.append("✓ \(String(localized: .DiagSubSetuid))")

        // ⑤ 隔离标记
        if isFileQuarantined(at: path) {
            details.append("✗ \(String(localized: .DiagSubQuarantined))")
            return .fail(.v2rayUTool, subtitle: details.joined(separator: "\n"),
                         problem: String(localized: .DiagFileQuarantined), action: .fixTool)
        }
        details.append("✓ \(String(localized: .DiagSubNoQuarantine))")

        // ⑥ 版本检查
        let toolVersion = await runInBackground {
            shell(launchPath: "/bin/bash", arguments: ["-c", "\(v2rayUTool) version"])
        }
        if let version = toolVersion {
            if version.contains("Usage:") || version.compare("4.0.0", options: .numeric) == .orderedAscending {
                details.append("✗ \(String(localized: .DiagSubVersionTooOld))")
                return .fail(.v2rayUTool, subtitle: details.joined(separator: "\n"),
                             problem: String(localized: .DiagToolVersionOld), action: .fixTool)
            }
            details.append("✓ v\(version.trimmingCharacters(in: .whitespacesAndNewlines))")
        } else {
            details.append("✗ \(String(localized: .DiagSubVersionUnknown))")
            return .fail(.v2rayUTool, subtitle: details.joined(separator: "\n"),
                         problem: String(localized: .DiagToolVersionOld), action: .fixTool)
        }

        return .pass(.v2rayUTool, details.joined(separator: "\n"))
    }

    /// Xray Core: 存在 → 可执行 → 架构匹配 → 版本号 → 隔离标记
    private func checkXrayCore() async -> CheckResult {
        let path = xrayCoreFile
        var details: [String] = []

        // ① 文件存在
        guard FileManager.default.fileExists(atPath: path) else {
            return .fail(.xrayCore, subtitle: String(localized: .DiagCoreNotInstalled),
                         problem: String(localized: .DiagCoreNotInstalled), action: .fixInstall)
        }
        details.append("✓ \(String(localized: .DiagSubFileExists))")

        // ② 可执行
        guard FileManager.default.isExecutableFile(atPath: path) else {
            details.append("✗ \(String(localized: .DiagSubNotExecutable))")
            return .fail(.xrayCore, subtitle: details.joined(separator: "\n"),
                         problem: String(localized: .DiagCoreNotExecutable), action: .fixInstall)
        }
        details.append("✓ \(String(localized: .DiagSubExecutable))")

        // ③ 架构匹配
        let currentArch = getArch()
        let actualArch = await getFileArch(file: path)
        if actualArch != currentArch {
            let msg = String(format: String(localized: .DiagCoreArchMismatch), actualArch ?? "unknown", currentArch)
            details.append("✗ \(msg)")
            return .fail(.xrayCore, subtitle: details.joined(separator: "\n"),
                         problem: msg, action: .fixInstall)
        }
        details.append("✓ \(String(format: String(localized: .DiagCoreArchCorrect), currentArch))")

        // ④ 版本号
        let ver = getCoreVersion()
        if !ver.isEmpty {
            details.append("✓ v\(ver)")
        }

        // ⑤ 隔离标记
        if isFileQuarantined(at: path) {
            details.append("✗ \(String(localized: .DiagSubQuarantined))")
            return .fail(.xrayCore, subtitle: details.joined(separator: "\n"),
                         problem: String(localized: .DiagFileQuarantined), action: .fixInstall)
        }
        details.append("✓ \(String(localized: .DiagSubNoQuarantine))")

        return .pass(.xrayCore, details.joined(separator: "\n"))
    }

    /// SingBox: 存在 → 可执行 → 架构匹配 → 隔离标记
    private func checkSingBox() async -> CheckResult {
        let path = getCoreFile(mode: .SingBox)
        var details: [String] = []

        // ① 文件存在
        guard FileManager.default.fileExists(atPath: path) else {
            return .fail(.singBox, subtitle: String(localized: .DiagSingBoxNotInstalled),
                         problem: String(localized: .DiagSingBoxNotInstalled), action: .fixInstall)
        }
        details.append("✓ \(String(localized: .DiagSubFileExists))")

        // ② 可执行
        guard FileManager.default.isExecutableFile(atPath: path) else {
            details.append("✗ \(String(localized: .DiagSubNotExecutable))")
            return .fail(.singBox, subtitle: details.joined(separator: "\n"),
                         problem: String(localized: .DiagSingBoxNotExecutable), action: .fixInstall)
        }
        details.append("✓ \(String(localized: .DiagSubExecutable))")

        // ③ 架构匹配
        let currentArch = getArch()
        let actualArch = await getFileArch(file: path)
        if actualArch != currentArch {
            let msg = String(format: String(localized: .DiagSingBoxArchMismatch), actualArch ?? "unknown", currentArch)
            details.append("✗ \(msg)")
            return .fail(.singBox, subtitle: details.joined(separator: "\n"),
                         problem: msg, action: .fixInstall)
        }
        details.append("✓ \(String(format: String(localized: .DiagCoreArchCorrect), currentArch))")

        // ④ 隔离标记
        if isFileQuarantined(at: path) {
            details.append("✗ \(String(localized: .DiagSubQuarantined))")
            return .fail(.singBox, subtitle: details.joined(separator: "\n"),
                         problem: String(localized: .DiagFileQuarantined), action: .fixInstall)
        }
        details.append("✓ \(String(localized: .DiagSubNoQuarantine))")

        return .pass(.singBox, details.joined(separator: "\n"))
    }

    /// 更新脚本: 存在 → 可执行权限
    private func checkUpdateScript() async -> CheckResult {
        let path = AppBinRoot + "/update-xray.sh"
        var details: [String] = []

        // ① 文件存在
        guard FileManager.default.fileExists(atPath: path) else {
            return .fail(.updateScript, subtitle: String(localized: .DiagUpdateScriptMissing),
                         problem: String(localized: .DiagUpdateScriptMissing), action: .fixInstall)
        }
        details.append("✓ \(String(localized: .DiagSubFileExists))")

        // ② 可执行
        guard FileManager.default.isExecutableFile(atPath: path) else {
            details.append("✗ \(String(localized: .DiagSubNotExecutable))")
            return .fail(.updateScript, subtitle: details.joined(separator: "\n"),
                         problem: String(localized: .DiagUpdateScriptNoPermission), action: .fixInstall)
        }
        details.append("✓ \(String(localized: .DiagSubExecutable))")

        return .pass(.updateScript, details.joined(separator: "\n"))
    }

    private func checkSudoers() async -> CheckResult {
        let sudoerFile = "/private/etc/sudoers.d/v2rayu-sudoer"
        guard FileManager.default.fileExists(atPath: sudoerFile) else {
            let msg = String(localized: .DiagSudoersFileMissing)
            return .fail(.sudoersCheck, subtitle: msg, problem: msg, action: .fixInstall)
        }
        // 验证 NOPASSWD 规则实际可用
        let ok = await runInBackground {
            let task = Process()
            task.launchPath = "/usr/bin/sudo"
            task.arguments = ["-n", "-l"]
            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError = Pipe()
            do {
                try task.run()
                task.waitUntilExit()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                return output.contains("NOPASSWD")
            } catch {
                return false
            }
        }
        if ok { return .pass(.sudoersCheck) }
        let msg = String(localized: .DiagSudoersNotEffective)
        return .fail(.sudoersCheck, subtitle: msg, problem: msg, action: .fixInstall)
    }

    private func checkTunDaemon() async -> CheckResult {
        let plist = "/Library/LaunchDaemons/yanue.v2rayu.tun-helper.plist"
        if FileManager.default.fileExists(atPath: plist) { return .pass(.tunDaemon) }
        let msg = String(localized: .DiagTunDaemonMissing)
        return .fail(.tunDaemon, subtitle: msg, problem: msg, action: .fixInstall)
    }

    /// 配置文件: 存在 → 非空 → JSON合法性
    private func checkConfig() async -> CheckResult {
        let path = JsonConfigFilePath
        var details: [String] = []

        // ① 文件存在
        guard FileManager.default.fileExists(atPath: path) else {
            return .fail(.configCheck, subtitle: String(localized: .DiagConfigFileMissing),
                         problem: String(localized: .DiagConfigFileMissing), action: .fixInstall)
        }
        details.append("✓ \(String(localized: .DiagSubFileExists))")

        // ② 非空
        let size = (try? FileManager.default.attributesOfItem(atPath: path)[.size] as? Int) ?? 0
        if size == 0 {
            details.append("✗ \(String(localized: .DiagConfigFileEmpty))")
            return .fail(.configCheck, subtitle: details.joined(separator: "\n"),
                         problem: String(localized: .DiagConfigFileEmpty), action: .fixInstall)
        }
        details.append("✓ \(String(format: String(localized: .DiagConfigFileExists), size))")

        // ③ JSON 合法性
        let (valid, problems) = await ConfigValidator.validateConfig(filePath: path)
        if !valid {
            let joined = problems.joined(separator: "; ")
            details.append("✗ \(String(localized: .DiagFailed))")
            return .fail(.configCheck, subtitle: details.joined(separator: "\n"),
                         problem: String(format: String(localized: .DiagConfigValidProblems), joined),
                         action: .openConfig)
        }
        details.append("✓ \(String(localized: .DiagConfigValidOK))")

        return .pass(.configCheck, details.joined(separator: "\n"))
    }

    /// GeoData: geoip.dat + geosite.dat
    private func checkGeoDataFiles() async -> CheckResult {
        var details: [String] = []
        var allOk = true

        let geoipExists = FileManager.default.fileExists(atPath: xrayCorePath + "/geoip.dat")
        if geoipExists {
            details.append("✓ geoip.dat")
        } else {
            details.append("✗ geoip.dat \(String(localized: .DiagGeoipMissing))")
            allOk = false
        }

        let geositeExists = FileManager.default.fileExists(atPath: xrayCorePath + "/geosite.dat")
        if geositeExists {
            details.append("✓ geosite.dat")
        } else {
            details.append("✗ geosite.dat \(String(localized: .DiagGeositeMissing))")
            allOk = false
        }

        if allOk {
            return .pass(.geoDataFiles, details.joined(separator: "\n"))
        }
        return .fail(.geoDataFiles, subtitle: details.joined(separator: "\n"),
                     problem: details.filter { $0.hasPrefix("✗") }.joined(separator: "\n"),
                     action: .fixGeoip)
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
        let runMode = appState.runMode
        let result = await runInBackground { () -> (loaded: Bool, pid: String?) in
            // Use launchctl list to check if agent is loaded and get PID
            var agentNames = [LaunchAgent.shared.singBoxAgentName, LaunchAgent.shared.xrayCoreAgentName]
            // 判断是否启动tun
            if runMode == .tun {
                agentNames.append(LaunchAgent.shared.tunHelperDaemon)
            }
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
                case 62:  return "x86_64"
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
        return "***"
    }

    // MARK: ── Report & Submit ──
    func generateReport() -> String {
        let arch = getArch()

        var report = ""

        // ── 1. Environment ──
        report += "## Environment\n"
        report += "- V2rayU: \(appVersion) | macOS: \(osVersion) | Arch: \(arch)\n"
        report += "- Core: \(coreVersion) | Mode: \(appState.runMode.rawValue) | Status: \(appState.v2rayTurnOn ? "ON" : "OFF")\n"
        report += "- SOCKS: \(localSocksPort) | HTTP: \(localHTTPPort)"
        if appState.latency > 0 { report += " | Latency: \(Int(appState.latency))ms" }
        report += "\n\n"

        // ── 2. Diagnostic Results ──
        report += "## Diagnostic Results (\(passedCount)/\(totalCount) passed)\n"
        for item in items {
            report += "\(item.ok ? "✅" : "❌") \(item.title)\n"
        }
        report += "\n"

        // ── 3. Node Config ──
        if let s = appState.runningServer {
            report += "## Config\n"
            report += "- Protocol: \(s.protocol.rawValue) | Network: \(s.network.rawValue) | Security: \(s.security.rawValue)\n"
            report += "- Address: \(maskAddress(s.address)):\(s.port)"
            if !s.sni.isEmpty { report += " | SNI: \(maskAddress(s.sni))" }
            if !s.flow.isEmpty { report += " | Flow: \(s.flow)" }
            report += "\n"
            if !s.fingerprint.rawValue.isEmpty {
                report += "- FP: \(s.fingerprint.rawValue) | ALPN: \(s.alpn.rawValue)\n"
            }
            report += "\n"
        }

        // ── 4. Error Logs ──
        if !logContent.isEmpty {
            report += "## Error Logs\n```\n"
            report += String(logContent.prefix(3000))
            if logContent.count > 3000 { report += "\n... (truncated)" }
            report += "\n```\n"
        }

        return report
    }

    /// URL query 参数值的安全字符集
    /// .urlQueryAllowed 不会编码 &、#、+、= 等字符，但这些字符在 query string 中有特殊含义
    /// 作为单个参数的值，必须把它们全部编码
    private static let queryValueAllowed: CharacterSet = {
        var cs = CharacterSet.urlQueryAllowed
        cs.remove(charactersIn: "&#+=")
        return cs
    }()

    func submitToGitHub() {
        Task {
            let report = generateReport()
            let title = "[Bug] V2rayU Diagnostic - \(Date().formatted(date: .abbreviated, time: .shortened))"
            let encodedTitle = title.addingPercentEncoding(withAllowedCharacters: Self.queryValueAllowed) ?? title
            let encodedBody = report.addingPercentEncoding(withAllowedCharacters: Self.queryValueAllowed) ?? ""
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
                // 提示用户粘贴
                makeToast(message: String(localized: .DiagReportCopied), displayDuration: 5)
            }
        }
    }
}
