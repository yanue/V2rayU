//
//  V2rayLaunch.swift
//  V2rayU
//
//  Created by yanue on 2018/10/17.
//  Copyright © 2018 yanue. All rights reserved.
//

import Cocoa
import SystemConfiguration

enum RunMode: String, CaseIterable {
    case global
    case pac
    case manual
    case tun

    var icon: String {
        switch self {
        case .global:
            return "IconOnG"
        case .pac:
            return "IconOnP"
        case .manual:
            return "IconOnM"
        case .tun:
            return "IconOnT"
        }
    }

    var tip: LanguageLabel {
        switch self {
        case .global:
            return .GlobalTip
        case .pac:
            return .PacTip
        case .manual:
            return .ManualTip
        case .tun:
            return .TunTip
        }
    }
}

// MARK: - 统一运行状态

enum LaunchState: Equatable {
    case stopped
    case starting
    case running(coreType: CoreType, mode: RunMode)
    case stopping
    case failed(String)

    var isRunning: Bool {
        if case .running = self { return true }
        return false
    }
    var description: String {
        switch self {
        case .stopped: return "stopped"
        case .starting: return "starting"
        case .running(let c, let m): return "running(\(c.rawValue), \(m.rawValue))"
        case .stopping: return "stopping"
        case .failed(let e): return "failed(\(e))"
        }
    }
}

// MARK: - 核心启动器
actor V2rayLaunch {
    static let shared = V2rayLaunch()

    nonisolated(unsafe) private static var _launchState: LaunchState = .stopped
    nonisolated static var launchState: LaunchState { _launchState }

    /// 是否可以安全调用 start()
    nonisolated private static var canStart: Bool {
        V2rayLaunch._launchState == .stopped || { if case .failed = V2rayLaunch._launchState { return true }; return false }()
    }

    nonisolated private static func transition(to newState: LaunchState) {
        let old = _launchState
        _launchState = newState
        logger.info("LaunchState: \(old.description) → \(newState.description)")
        Task { @MainActor in
            AppState.shared.launchState = newState
        }
    }

    var lastCore: CoreType?

    private func localized(_ label: LanguageLabel) async -> String {
        await MainActor.run { String(localized: label) }
    }

    private func noticeLocalized(title: LanguageLabel, message: LanguageLabel) async {
        let titleText = await localized(title)
        let messageText = await localized(message)
        await showAlert(title: titleText, message: messageText)
    }

    /// 完全重启（先停后启）
    func restart() async {
        let wasRunning = V2rayLaunch._launchState.isRunning || V2rayLaunch._launchState == .starting
        if wasRunning { await stop() }
        let success = await start()
        if !wasRunning {
            await MainActor.run { AppState.shared.v2rayTurnOn = success }
        }
    }

    func start() async -> Bool {
        logger.info("start v2ray-core begin, current state=\(V2rayLaunch._launchState.description)")

        // 防止重复进入（允许从 .stopped / .failed 启动）
        guard V2rayLaunch.canStart else {
            logger.info("start skipped: invalid state=\(V2rayLaunch._launchState.description)")
            return false
        }
        Self.transition(to: .starting)

        // 检查组合配置
        let runningCombination = await MainActor.run { AppState.shared.runningCombination }
        if !runningCombination.isEmpty {
            let result = await startCombination(uuid: runningCombination)
            if !result { Self.transition(to: .stopped) }
            return result
        }

        // 获取运行中的 profile
        guard let running = ProfileStore.shared.getRunning() else {
            await noticeLocalized(title: .StartFailed, message: .NoAvailableServerConfig)
            await MainActor.run {
                AppState.shared.runningProfile = ""
                AppState.shared.runningServer = nil
            }
            Self.transition(to: .stopped)
            return false
        }
        // 启动前自动获取证书指纹
        let item = await CertPinningCoordinator.ensurePinnedCert(for: running)
        let coreDecision = item.resolveCoreCompatibility()
        if let warningMessage = coreDecision.warningMessage {
            if coreDecision.canLaunch {
                await showAlert(title: await localized(.XrayCompatibilityWarningTitle), message: warningMessage)
            } else {
                let downloadMsg = warningMessage + "\n\n正在自动下载兼容版本..."
                let needDownload = await showDownloadAlert(title: await localized(.XrayCompatibilityWarningTitle), message: downloadMsg)
                if needDownload {
                    await MainActor.run {
                        NavigationState.shared.mainTab = .setting
                        NavigationState.shared.settingTab = .core
                        NavigationState.shared.coreSettingTab = .download
                        MainWindowManager.shared.openMainWindow()
                    }
                    await CoreViewModel.shared.downloadMinimumVersion(for: coreDecision)
                }
                Self.transition(to: .stopped)
                return false
            }
        }
        if !coreDecision.canLaunch {
            Self.transition(to: .stopped)
            return false
        }
        // 同步 AppState
        await MainActor.run {
            if AppState.shared.runningProfile != item.uuid {
                AppState.shared.runningProfile = item.uuid
                AppState.shared.runningServer = item
                logger.info("V2rayLaunch.start: sync runningProfile to \(item.remark)")
            }
            AppMenuManager.shared.refreshServerItems()
        }
        await AppState.shared.resetSpeed()
        await CoreTrafficStatsHandler.shared.resetData()
        // 停止已有服务
        await TunHandler.shared.stop()
        await LaunchAgent.shared.stopAgent()

        createJsonFile(item: item)

        // 轮转日志
        truncateLogFile(appLogFilePath)
        LogRotation.rotateSessionLog(at: coreLogFilePath)
        LogRotation.rotateSessionLog(at: tunLogFilePath)
        LogRotation.rotateSessionLog(at: runTunLogFilePath)
        LogRotation.cleanSessionBackups(at: coreLogFilePath)
        LogRotation.cleanSessionBackups(at: tunLogFilePath)
        LogRotation.cleanSessionBackups(at: runTunLogFilePath)

        // 启动守护进程
        let started = await LaunchAgent.shared.startAgent(coreType: coreDecision.coreType)
        if !started {
            await noticeLocalized(title: .StartFailed, message: .LaunchDaemonStartFailed)
            Self.transition(to: .stopped)
            return false
        }
        // 等待代理端口就绪
        let mode = await AppState.shared.runMode
        guard await ensureLocalProxyReady(mode: mode, context: "start") else {
            await LaunchAgent.shared.stopAgent()
            setSystemProxy(mode: nil)
            Self.transition(to: .stopped)
            return false
        }
        // 设置系统代理
        setSystemProxy(mode: mode)
        logger.info("start v2ray-core ok: \(mode.rawValue)")
        // 后台统计 + ping（非关键，不阻塞）
        Task {
            await CoreTrafficStatsHandler.shared.startTask(coreType: coreDecision.coreType)
            do {
                try await PingRunning.shared.startPing()
            } catch {
                logger.error("PingRunning.startPing failed: \(error)")
            }
        }
        // TUN 模式开启 tun-helper
        if mode == .tun {
            guard await TunHandler.shared.start(item: item) else {
                await noticeLocalized(title: .StartFailed, message: .TunServiceStartFailed)
                await LaunchAgent.shared.stopAgent()
                setSystemProxy(mode: nil)
                Self.transition(to: .stopped)
                return false
            }
        }
        // DNS 设置
        Self.setupTunDns()
        self.lastCore = coreDecision.coreType

        DispatchQueue.global().asyncAfter(deadline: .now() + 2) {
            LogRotation.rotateIfNeeded()
            LogRotation.extractErrors()
        }

        Self.transition(to: .running(coreType: coreDecision.coreType, mode: mode))
        return true
    }

    private func startCombination(uuid: String) async -> Bool {
        guard let combination = CombinedConfigStore.shared.getValidCombination(uuid: uuid) else {
            await noticeLocalized(title: .StartFailed, message: .InvalidCombinationStartTip)
            await MainActor.run { AppState.shared.runningCombination = "" }
            Self.transition(to: .stopped)
            return false
        }

        let memberUUIDs = Set(combination.groups.flatMap { $0.outboundProfileUUIDs })
        let memberProfiles = ProfileStore.shared.fetchAll().filter { memberUUIDs.contains($0.uuid) }
        let pinningResults = await CertPinningCoordinator.ensurePinnedCerts(for: memberProfiles)
        let profileOverrides = pinningResults.map(\.profile)
        let forceSingboxUUIDs = Set(pinningResults.filter { $0.forceSingBox }.map { $0.profile.uuid })

        let cfg = CoreConfigHandler()
        guard let resolved = cfg.resolveCombination(
            combination,
            profileOverrides: profileOverrides,
            forceSingboxProfileUUIDs: forceSingboxUUIDs
        ), let firstProfile = resolved.firstProfile else {
            await noticeLocalized(title: .StartFailed, message: .CombinationNoAvailableOutbounds)
            Self.transition(to: .stopped)
            return false
        }

        if let warningMessage = resolved.warningMessage {
            if resolved.canLaunch {
                makeToast(message: warningMessage, displayDuration: 5)
            } else {
                let downloadMsg = warningMessage + "\n\n正在自动下载兼容版本..."
                let needDownload = await showDownloadAlert(title: await localized(.CoreCompatibilityWarningTitle), message: downloadMsg)
                if needDownload {
                    await MainActor.run {
                        NavigationState.shared.mainTab = .setting
                        NavigationState.shared.settingTab = .core
                        NavigationState.shared.coreSettingTab = .download
                        MainWindowManager.shared.openMainWindow()
                    }
                    await CoreViewModel.shared.downloadMinimumVersion(for: resolved)
                }
            }
        }
        if !resolved.canLaunch {
            logger.error("start combination aborted: incompatible with selected core")
            Self.transition(to: .stopped)
            return false
        }

        await MainActor.run {
            AppState.shared.runningProfile = firstProfile.uuid
            AppState.shared.runningServer = firstProfile
            AppMenuManager.shared.refreshCombinedConfigItems()
            AppMenuManager.shared.refreshServerItems()
        }
        await AppState.shared.resetSpeed()
        await CoreTrafficStatsHandler.shared.resetData()
        await LaunchAgent.shared.stopAgent()

        createJsonFile(combination: resolved)
        truncateLogFile(appLogFilePath)
        LogRotation.rotateSessionLog(at: coreLogFilePath)
        LogRotation.rotateSessionLog(at: tunLogFilePath)
        LogRotation.rotateSessionLog(at: runTunLogFilePath)
        LogRotation.cleanSessionBackups(at: coreLogFilePath)
        LogRotation.cleanSessionBackups(at: tunLogFilePath)
        LogRotation.cleanSessionBackups(at: runTunLogFilePath)

        let started = await LaunchAgent.shared.startAgent(coreType: resolved.coreType)
        if !started {
            await noticeLocalized(title: .StartFailed, message: .LaunchDaemonStartFailed)
            Self.transition(to: .stopped)
            return false
        }
        let mode = await AppState.shared.runMode
        guard await ensureLocalProxyReady(mode: mode, context: "start combined config") else {
            await LaunchAgent.shared.stopAgent()
            setSystemProxy(mode: nil)
            Self.transition(to: .stopped)
            return false
        }
        setSystemProxy(mode: mode)
        logger.info("start combined config ok: \(combination.displayName), core=\(resolved.coreType.rawValue), mode=\(mode.rawValue)")
        Task {
            await CoreTrafficStatsHandler.shared.startTask(coreType: resolved.coreType)
        }

        if mode == .tun {
            guard await TunHandler.shared.start(item: firstProfile) else {
                await noticeLocalized(title: .StartFailed, message: .TunServiceStartFailed)
                await LaunchAgent.shared.stopAgent()
                setSystemProxy(mode: nil)
                Self.transition(to: .stopped)
                return false
            }
        }

        Self.setupTunDns()
        self.lastCore = resolved.coreType

        DispatchQueue.global().asyncAfter(deadline: .now() + 2) {
            LogRotation.rotateIfNeeded()
            LogRotation.extractErrors()
        }

        Self.transition(to: .running(coreType: resolved.coreType, mode: mode))
        return true
    }

    func stop() async {
        logger.info("stop begin, current state=\(V2rayLaunch._launchState.description)")
        guard V2rayLaunch._launchState.isRunning || V2rayLaunch._launchState == .starting else {
            logger.info("stop skipped: not running")
            return
        }
        Self.transition(to: .stopping)

        // 1. 恢复 DNS
        Self.restoreTunDns()
        // 2. 停止 TUN
        await TunHandler.shared.stop()
        // 3. 停止代理核心
        await LaunchAgent.shared.stopAgent()
        // 4. 清理系统代理
        setSystemProxy(mode: nil)
        // 5. 重置 UI 状态
        await AppState.shared.resetSpeed()
        await CoreTrafficStatsHandler.shared.resetData()

        Self.transition(to: .stopped)
    }

    private func waitForLocalTCPReady(port: UInt16, timeout: TimeInterval) async -> Bool {
        guard port > 0 else { return false }
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if await TCPConnectivity.canConnect(host: "127.0.0.1", port: port, timeout: 0.8) {
                return true
            }
            try? await Task.sleep(nanoseconds: 300_000_000)
        }
        return false
    }

    private func ensureLocalProxyReady(mode: RunMode, context: String) async -> Bool {
        let port = getEffectiveSocksProxyPort()
        let ready = await waitForLocalTCPReady(port: port, timeout: 6)
        guard ready else {
            logger.error("\(context) aborted: local SOCKS/Mixed port \(port) is not ready, mode=\(mode.rawValue)")
            let message = mode == .tun ? LanguageLabel.SocksPortNotReadyForTun : LanguageLabel.LocalProxyPortNotReady
            await showAlert(title: await localized(.StartFailed), message: await localized(message))
            return false
        }
        return true
    }

    private func createJsonFile(item: ProfileEntity) {
        let cfg = CoreConfigHandler()
        let jsonText = cfg.toJSON(item: item)
        do {
            try jsonText.write(to: URL(fileURLWithPath: JsonConfigFilePath), atomically: true, encoding: .utf8)
            logger.info("createJsonFile: wrote \(JsonConfigFilePath)")
        } catch {
            logger.info("Failed to write JSON file: \(error)")
            noticeTip(title: "Failed to write JSON file: \(error)")
        }
    }

    private func createJsonFile(combination resolved: CombinedConfigResolved) {
        let cfg = CoreConfigHandler()
        let jsonText = cfg.toJSON(combination: resolved)
        do {
            try jsonText.write(to: URL(fileURLWithPath: JsonConfigFilePath), atomically: true, encoding: .utf8)
            logger.info("createCombinedJsonFile: wrote \(JsonConfigFilePath)")
        } catch {
            logger.info("Failed to write combined JSON file: \(error)")
            noticeTip(title: "Failed to write combined JSON file: \(error)")
        }
    }

    func setSystemProxy(mode: RunMode?) {
        let modeValue = mode?.rawValue ?? "off"
        logger.info("setSystemProxy: \(v2rayUTool), \(modeValue)")
        var httpPort = ""
        var sockPort = ""
        var pacUrl = ""
        if mode == .global {
            httpPort = String(getEffectiveHttpProxyPort())
            sockPort = String(getEffectiveSocksProxyPort())
        }
        if mode == .pac {
            if !GeneratePACFile(rewrite: false) {
                Task { @MainActor in
                    noticeTip(title: String(localized: .PacGenerateFailed), informativeText: String(localized: .PacGenerateFailedTip))
                }
            }
            pacUrl = getPacUrl()
        }
        do {
            let output = try runCommand(at: v2rayUTool, with: [
                "-mode", modeValue,
                "-pac-url", pacUrl,
                "-http-port", httpPort,
                "-sock-port", sockPort
            ])
            logger.info("setSystemProxy: ok \(output)")
        } catch {
            alertDialog(title: "setSystemProxy Error", message: error.localizedDescription, blocking: true)
            Task { await AppInstaller.shared.showInstallAlert() }
        }
    }

    // MARK: - DNS management

    nonisolated(unsafe) private static var savedOriginalDns: [String] = []

    /// 读取当前系统 DNS
    nonisolated private static func readCurrentDns() -> [String] {
        for svc in ["Wi-Fi", "Ethernet", "Thunderbolt"] {
            if let output = try? runCommand(at: "/usr/sbin/networksetup", with: ["-getdnsservers", svc]) {
                let servers = output.split(separator: "\n").filter { !$0.contains("empty") && !$0.contains("There") }
                if !servers.isEmpty {
                    return servers.map { $0.trimmingCharacters(in: .whitespaces) }
                }
            }
        }
        return []
    }

    /// 启动时设置系统 DNS 到 1.1.1.1（通过 V2rayUTool 提权）
    nonisolated static func setupTunDns() {
        let current = readCurrentDns()
        // 保存原值（可能为空 = DHCP 自动获取，在中国会拿到 223.5.5.5）
        savedOriginalDns = current

        if (try? runCommand(at: v2rayUTool, with: ["-dns-setup", "1.1.1.1"])) != nil {
            logger.info("DNS set to 1.1.1.1")
        } else {
            logger.warning("DNS change failed")
        }
    }

    /// 停止时恢复原始 DNS
    nonisolated static func restoreTunDns() {
        if savedOriginalDns.isEmpty {
            // 原值空 = DHCP 自动获取，清空让 DHCP 恢复
            _ = try? runCommand(at: v2rayUTool, with: ["-dns-clear"])
        } else {
            if (try? runCommand(at: v2rayUTool, with: ["-dns-restore"] + savedOriginalDns)) != nil {
                logger.info("DNS restored")
            }
        }
        savedOriginalDns = []
    }
}
