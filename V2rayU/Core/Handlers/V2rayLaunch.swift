//
//  V2rayLaunch.swift
//  V2rayU
//
//  Created by yanue on 2018/10/17.
//  Copyright © 2018 yanue. All rights reserved.
//

import Cocoa
import SystemConfiguration
import Network

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

    var tip: String {
        switch self {
        case .global:
            return "Global.tip"
        case .pac:
            return "Pac.tip"
        case .manual:
            return "Manual.tip"
        case .tun:
            return "Tun.tip"
        }
    }
}

// MARK: - 核心启动器
actor V2rayLaunch {
    static let shared = V2rayLaunch()
    var lastCore: CoreType?
    private var rebuildInProgress = false
    private var lastRebuildAt: Date?
    private let minRebuildInterval: TimeInterval = 8

    private func localized(_ label: LanguageLabel) async -> String {
        await MainActor.run { String(localized: label) }
    }

    private func noticeLocalized(title: LanguageLabel, message: LanguageLabel) async {
        let titleText = await localized(title)
        let messageText = await localized(message)
        noticeTip(title: titleText, informativeText: messageText)
    }

    func restart() async {
        let _ = await start()
    }

    func start() async -> Bool {
        logger.info("start v2ray-core begin")
        let runningCombination = await MainActor.run { AppState.shared.runningCombination }
        if !runningCombination.isEmpty {
            return await startCombination(uuid: runningCombination)
        }

        guard let running = ProfileStore.shared.getRunning() else {
            await noticeLocalized(title: .StartFailed, message: .NoAvailableServerConfig)
            await MainActor.run {
                AppState.shared.runningProfile = ""
                AppState.shared.runningServer = nil
            }
            return false
        }
        // 启动前自动获取证书指纹（allowInsecure 已被新 Xray-core 移除）；失败则回退 Sing-Box。
        let item = await CertPinningCoordinator.ensurePinnedCert(for: running)
        let coreDecision = item.resolveCoreCompatibility()
        if let warningMessage = coreDecision.warningMessage {
            await showAlert(title: await localized(.XrayCompatibilityWarningTitle), message: warningMessage)
        }
        if !coreDecision.canLaunch {
            return false
        }
        // 同步 AppState 与实际使用的服务器
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
        await LaunchAgent.shared.stopAgent()

        createJsonFile(item: item)

        // Clear log files on start
        truncateLogFile(appLogFilePath)
        truncateLogFile(coreLogFilePath)
        truncateLogFile(tunLogFilePath)
        truncateLogFile(runTunLogFilePath)

        // 启动
        let started = await LaunchAgent.shared.startAgent(coreType: coreDecision.coreType)
        if !started {
            await noticeLocalized(title: .StartFailed, message: .LaunchDaemonStartFailed)
            return false
        }
        let mode = await AppState.shared.runMode
        guard await ensureLocalProxyReady(mode: mode, context: "start") else {
            await LaunchAgent.shared.stopAgent()
            setSystemProxy(mode: nil)
            return false
        }
        setSystemProxy(mode: mode)
        logger.info("start v2ray-core ok: \(mode.rawValue)")
        Task {
            await CoreTrafficStatsHandler.shared.startTask(coreType: coreDecision.coreType)
            do {
                try await PingRunning.shared.startPing()
            } catch {
                logger.error("PingRunning.startPing failed: \(error)")
            }
        }
        // TUN模式: 使用sing-box(tun) -> xray/sing(socks)
        if mode == .tun {
            createTunJsonFile(item: item)
            logger.info("create tun config ok, path: \(TunConfigFilePath)")

            let tunStarted = await LaunchAgent.shared.startTunHelper()
            if !tunStarted {
                await noticeLocalized(title: .StartFailed, message: .TunServiceStartFailed)
                await LaunchAgent.shared.stopAgent()
                setSystemProxy(mode: nil)
                return false
            }
            logger.info("start tun-helper ok")
        }
        self.lastCore = coreDecision.coreType

        DispatchQueue.global().asyncAfter(deadline: .now() + 2) {
            LogRotation.rotateIfNeeded()
            LogRotation.extractErrors()
        }

        return true
    }

    private func startCombination(uuid: String) async -> Bool {
        guard let combination = CombinedConfigStore.shared.getValidCombination(uuid: uuid) else {
            await noticeLocalized(title: .StartFailed, message: .InvalidCombinationStartTip)
            await MainActor.run {
                AppState.shared.runningCombination = ""
            }
            return false
        }

        // 启动前为组合内各 TLS 节点自动获取证书指纹（持久化到 DB，供 resolveCombination 读取）。
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
            return false
        }

        if let warningMessage = resolved.warningMessage {
            if resolved.canLaunch {
                makeToast(message: warningMessage, displayDuration: 5)
            } else {
                await showAlert(title: await localized(.CoreCompatibilityWarningTitle), message: warningMessage)
            }
        }
        if !resolved.canLaunch {
            logger.error("start combination aborted: combined config is incompatible with selected core")
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
        truncateLogFile(coreLogFilePath)
        truncateLogFile(tunLogFilePath)
        truncateLogFile(runTunLogFilePath)

        let started = await LaunchAgent.shared.startAgent(coreType: resolved.coreType)
        if !started {
            await noticeLocalized(title: .StartFailed, message: .LaunchDaemonStartFailed)
            return false
        }
        let mode = await AppState.shared.runMode
        guard await ensureLocalProxyReady(mode: mode, context: "start combined config") else {
            await LaunchAgent.shared.stopAgent()
            setSystemProxy(mode: nil)
            return false
        }
        setSystemProxy(mode: mode)
        logger.info("start combined config ok: \(combination.displayName), core=\(resolved.coreType.rawValue), mode=\(mode.rawValue)")
        Task {
            await CoreTrafficStatsHandler.shared.startTask(coreType: resolved.coreType)
        }

        if mode == .tun {
            createTunJsonFile(item: firstProfile)
            logger.info("create tun config ok, path: \(TunConfigFilePath)")

            let tunStarted = await LaunchAgent.shared.startTunHelper()
            if !tunStarted {
                await noticeLocalized(title: .StartFailed, message: .TunServiceStartFailed)
                await LaunchAgent.shared.stopAgent()
                setSystemProxy(mode: nil)
                return false
            }
            logger.info("start tun-helper ok")
        }

        self.lastCore = resolved.coreType

        DispatchQueue.global().asyncAfter(deadline: .now() + 2) {
            LogRotation.rotateIfNeeded()
            LogRotation.extractErrors()
        }

        return true
    }

    func stop() async {
        await LaunchAgent.shared.stopAgent()
        await AppState.shared.resetSpeed()
        await CoreTrafficStatsHandler.shared.resetData()
        setSystemProxy(mode: nil)
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

    private func currentDefaultRoute() -> (gateway: String?, interface: String?) {
        do {
            let output = try runCommand(at: "/sbin/route", with: ["-n", "get", "default"])
            var gateway: String?
            var interface: String?
            for line in output.components(separatedBy: .newlines) {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.hasPrefix("gateway:") {
                    gateway = trimmed.replacingOccurrences(of: "gateway:", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                } else if trimmed.hasPrefix("interface:") {
                    interface = trimmed.replacingOccurrences(of: "interface:", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
            return (gateway, interface)
        } catch {
            logger.info("currentDefaultRoute failed: \(error)")
            return (nil, nil)
        }
    }

    private func hasPhysicalDefaultRoute() -> Bool {
        let route = currentDefaultRoute()
        guard let interface = route.interface, !interface.isEmpty else { return false }
        // TUN/loopback 默认路由说明还未回到物理网络，不能据此重建 TUN。
        if interface.hasPrefix("utun") || interface == "lo0" || interface.hasPrefix("lo") {
            logger.info("physical route not ready: default interface=\(interface), gateway=\(route.gateway ?? "")")
            return false
        }
        logger.info("physical route ready: interface=\(interface), gateway=\(route.gateway ?? "")")
        return true
    }

    /// 等待物理网络就绪（接口可用），用于唤醒/换网后避免过早重启导致接口探测失败。
    /// 同时要求默认路由回到非 utun/loopback 接口，避免旧 TUN 路由让 NWPathMonitor 误报 satisfied。
    /// - Parameter timeout: 最长等待时间，超时也返回（由调用方决定是否继续重启）
    /// - Returns: true 表示在超时前网络已就绪
    func waitForNetworkReady(timeout: TimeInterval = 15) async -> Bool {
        let ready = await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            let monitor = NWPathMonitor()
            let flag = ResumeFlag()
            monitor.pathUpdateHandler = { path in
                if path.status == .satisfied {
                    Task {
                        await flag.tryResumeBool(cont, result: true)
                        monitor.cancel()
                    }
                }
            }
            monitor.start(queue: DispatchQueue(label: "net.yanue.V2rayU.networkReady"))
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
                Task {
                    await flag.tryResumeBool(cont, result: false)
                    monitor.cancel()
                }
            }
        }
        guard ready else { return false }

        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if hasPhysicalDefaultRoute() {
                // 网络刚就绪时路由/DHCP 可能仍在收敛，额外等待一小段时间再确认一次
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                return hasPhysicalDefaultRoute()
            }
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
        return false
    }

    /// 网络变化/唤醒后安全重建（仅在 TUN 模式且已开启时）。
    /// 先等待物理网络就绪，再走完整 restart()（重建 core + tun + 系统代理），
    /// 确保不会在内核未就绪时让 TUN 抢占路由形成黑洞。
    func rebuildAfterNetworkChange(reason: String) async {
        if rebuildInProgress {
            logger.info("rebuildAfterNetworkChange skip: rebuild already in progress (\(reason))")
            return
        }
        if let lastRebuildAt = lastRebuildAt, Date().timeIntervalSince(lastRebuildAt) < minRebuildInterval {
            logger.info("rebuildAfterNetworkChange skip: too soon after previous rebuild (\(reason))")
            return
        }

        let (turnOn, mode) = await MainActor.run { (AppState.shared.v2rayTurnOn, AppState.shared.runMode) }
        guard turnOn else {
            logger.info("rebuildAfterNetworkChange skip: not running (\(reason))")
            return
        }
        guard mode == .tun else {
            logger.info("rebuildAfterNetworkChange skip: mode=\(mode.rawValue) (\(reason))")
            return
        }
        guard UserDefaults.getBool(forKey: .tunAutoRebuild, default: true) else {
            logger.info("rebuildAfterNetworkChange skip: tunAutoRebuild disabled (\(reason))")
            return
        }

        rebuildInProgress = true
        defer { rebuildInProgress = false }

        logger.info("rebuildAfterNetworkChange: \(reason), stopping stale TUN before waiting for network...")
        await LaunchAgent.shared.stopTunHelper()

        logger.info("rebuildAfterNetworkChange: \(reason), waiting for network...")
        let ready = await waitForNetworkReady()
        guard ready else {
            logger.info("rebuildAfterNetworkChange: network not ready, skip restart (\(reason))")
            return
        }

        logger.info("rebuildAfterNetworkChange: network ready=\(ready), restarting (\(reason))")
        await restart()
        lastRebuildAt = Date()
    }

    private func createJsonFile(item: ProfileEntity) {
        let cfg = CoreConfigHandler()
        let jsonText = cfg.toJSON(item: item)
        do {
            try jsonText.write(to: URL(fileURLWithPath: JsonConfigFilePath), atomically: true, encoding: .utf8)
            logger.info("createJsonFile: \(jsonText)")
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
            logger.info("createCombinedJsonFile: \(jsonText)")
        } catch {
            logger.info("Failed to write combined JSON file: \(error)")
            noticeTip(title: "Failed to write combined JSON file: \(error)")
        }
    }

    // TUN模式: 创建tun配置文件
    private func createTunJsonFile(item: ProfileEntity) {
        // TUN模式使用sing-box
        let cfg = SingboxConfigHandler(enableTun: true)
        let jsonText = cfg.toJSON(item: item)
        do {
            try jsonText.write(to: URL(fileURLWithPath: TunConfigFilePath), atomically: true, encoding: .utf8)
            logger.info("createTunJsonFile: \(jsonText)")
        } catch {
            logger.info("Failed to write tun JSON file: \(error)")
            noticeTip(title: "Failed to write tun JSON file: \(error)")
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
            alertDialog(title: "setSystemProxy Error", message: error.localizedDescription)
            Task { await AppInstaller.shared.showInstallAlert() }
        }
    }
}
