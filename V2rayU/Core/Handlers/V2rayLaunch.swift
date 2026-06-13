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

// MARK: - 核心启动器
actor V2rayLaunch {
    static let shared = V2rayLaunch()
    var lastCore: CoreType?

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
                return false
            }
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

        // Rotate log files on start (save previous session, start fresh)
        truncateLogFile(appLogFilePath)
        LogRotation.rotateSessionLog(at: coreLogFilePath)
        LogRotation.rotateSessionLog(at: tunLogFilePath)
        LogRotation.rotateSessionLog(at: runTunLogFilePath)
        LogRotation.cleanSessionBackups(at: coreLogFilePath)
        LogRotation.cleanSessionBackups(at: tunLogFilePath)
        LogRotation.cleanSessionBackups(at: runTunLogFilePath)

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
        if mode == .tun {
            guard await TunHandler.shared.start(item: item) else {
                await noticeLocalized(title: .StartFailed, message: .TunServiceStartFailed)
                await LaunchAgent.shared.stopAgent()
                setSystemProxy(mode: nil)
                return false
            }
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
        LogRotation.rotateSessionLog(at: coreLogFilePath)
        LogRotation.rotateSessionLog(at: tunLogFilePath)
        LogRotation.rotateSessionLog(at: runTunLogFilePath)
        LogRotation.cleanSessionBackups(at: coreLogFilePath)
        LogRotation.cleanSessionBackups(at: tunLogFilePath)
        LogRotation.cleanSessionBackups(at: runTunLogFilePath)

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
            guard await TunHandler.shared.start(item: firstProfile) else {
                await noticeLocalized(title: .StartFailed, message: .TunServiceStartFailed)
                await LaunchAgent.shared.stopAgent()
                setSystemProxy(mode: nil)
                return false
            }
        }

        self.lastCore = resolved.coreType

        DispatchQueue.global().asyncAfter(deadline: .now() + 2) {
            LogRotation.rotateIfNeeded()
            LogRotation.extractErrors()
        }

        return true
    }

    func stop() async {
        await TunHandler.shared.stop()
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
            alertDialog(title: "setSystemProxy Error", message: error.localizedDescription)
            Task { await AppInstaller.shared.showInstallAlert() }
        }
    }
}
