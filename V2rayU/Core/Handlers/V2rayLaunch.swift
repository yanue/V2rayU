//
//  V2rayLaunch.swift
//  V2rayU
//
//  Created by yanue on 2018/10/17.
//  Copyright © 2018 yanue. All rights reserved.
//
//  架构说明（重构后）
//  ------------------------------------------------------------------
//  运行时由三个相互独立的部分组成, 任意一个变化都不应牵连其它两个:
//
//    1. 代理核心 (proxy core)  : sing-box / xray, 以用户级 LaunchAgent 运行,
//                               读取 config.json, 暴露固定的本地 SOCKS/Mixed 端口。
//                               config.json 只与 "运行的 profile/combination + 路由"
//                               有关, 与 RunMode 无关。
//    2. TUN 守护进程 (tun daemon): sing-box, 以特权 LaunchDaemon 运行, 读取 tun.json,
//                               把全局流量转发到上面那个固定的本地 SOCKS 端口。
//                               tun.json 只与 TUN 设置有关, 与 profile/路由无关。
//    3. 系统代理 (system proxy) : pac / global / manual, 通过 V2rayUTool 设置。
//
//  因此各种"切换"只需触碰真正变化的那一部分:
//    - 切服务器 / 路由 / 组合      → 只重载核心 (reloadCore), 不动 TUN / 系统代理。
//    - 切模式 (pac/global/manual/tun) → 只调整 TUN 与系统代理 (applyMode), 不重启核心。
//    - 网络变化 / 唤醒              → TUN 模式重建 TUN (rebuildTun); 唤醒时 full restart (核心上游连接已失效)。
//
//  所有改变运行状态的公开方法都经由内部串行锁, 保证彼此不会交错执行,
//  从而消除 TUN 切换时的竞态与不稳定。
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
    private static let tunBackendReadyTimeout: TimeInterval = 30

    enum TunStartResult: Equatable {
        case started
        case backendUnavailable
        case daemonFailed
    }

    static func startTunWhenBackendReady(
        waitForBackend: @Sendable () async -> Bool,
        startDaemon: @Sendable () async -> Bool
    ) async -> TunStartResult {
        guard await waitForBackend() else {
            return .backendUnavailable
        }
        return await startDaemon() ? .started : .daemonFailed
    }

    /// 当前是否处于"已启动"状态（核心已拉起）。唯一的运行状态来源。
    private var running = false
    /// 最近一次使用的核心类型（供诊断/统计读取）。
    var lastCore: CoreType?

    /// 对外暴露的只读运行状态。
    var isRunning: Bool { running }
    /// 是否有启动/停止/重载等操作正在进行（持锁中）。存活检测据此跳过核心检查, 避免把主动重启误判为退出。
    var isBusy: Bool { locked }

    /// 公共 Wi-Fi 需要网页登录时暂停 TUN（核心照常运行、系统 DNS 保持原值）, 由此任务轮询检测, 登录成功后自动恢复。
    private var captiveWaitTask: Task<Void, Never>?
    /// 每次开始/结束等待递增; 过期的等待任务据此退出, 不会接管新的等待
    private var captiveGeneration = 0
    private static let captivePollInterval: TimeInterval = 5

    // MARK: - 串行锁
    // actor 在 await 处会让出执行权, 多个公开操作可能交错。用一个公平的串行锁
    // 把每个完整操作包成临界区, 保证 start/stop/reloadCore/applyMode/rebuildTun
    // 永不交错执行。

    private var locked = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    private func lock() async {
        if !locked {
            locked = true
            return
        }
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            waiters.append(cont)
        }
    }

    private func unlock() {
        if waiters.isEmpty {
            locked = false
        } else {
            let next = waiters.removeFirst()
            next.resume()
        }
    }

    // MARK: - 本地化辅助

    private func localized(_ label: LanguageLabel) async -> String {
        await MainActor.run { String(localized: label) }
    }

    private func noticeLocalized(title: LanguageLabel, message: LanguageLabel) async {
        let titleText = await localized(title)
        let messageText = await localized(message)
        await showAlert(title: titleText, message: messageText)
    }

    private func syncTurnOn(_ value: Bool) async {
        await MainActor.run { AppState.shared.v2rayTurnOn = value }
    }

    /// TUN 守护进程确实未起来时, 用非阻塞 Toast 告知（不再像旧版那样弹窗 + 整体回滚）。
    /// 仅用于用户主动发起的 TUN 拉起, 自动重建(rebuildTun)失败不打扰。
    private func notifyTunFailed() async {
        let msg = await localized(.TunServiceStartFailed)
        makeToast(message: msg, displayDuration: 4)
    }

    // MARK: - 公开操作（均经过串行锁）

    /// 完整启动: 核心 + (TUN, 若为 tun 模式) + 系统代理。
    /// 已在运行则视为空操作。
    @discardableResult
    func start() async -> Bool {
        await lock(); defer { unlock() }
        if running {
            logger.info("start skipped: already running")
            return true
        }
        return await startAll()
    }

    /// 完整停止: 系统代理 + TUN + 核心。
    func stop() async {
        await lock(); defer { unlock() }
        await stopAll()
    }

    /// 睡眠前停止 TUN（daemon + 恢复 DNS）。与 start/stop/restart 共用串行锁,
    /// 避免唤醒时 restart() 与 DNS 恢复操作交错; 唤醒后由 restart() 重建。
    func stopTunForSleep() async {
        await lock(); defer { unlock() }
        await stopTun()
    }

    /// 完整重启（先全停后全启）。供端口/核心二进制等"影响全部"的设置变更使用。
    @discardableResult
    func restart() async -> Bool {
        await lock(); defer { unlock() }
        await stopAll()
        return await startAll()
    }

    /// 只重载代理核心（重写 config.json + 重启 LaunchAgent）, 不动 TUN 与系统代理。
    /// 适用于: 切服务器 / 切路由 / 切组合。
    /// 若当前未运行, 等价于完整 start()。
    @discardableResult
    func reloadCore() async -> Bool {
        await lock(); defer { unlock() }
        if !running {
            return await startAll()
        }
        guard await prepareAndStartCore() != nil else {
            // 核心重载失败: 回到安全的全停状态
            await stopAll()
            return false
        }
        // TUN 仍指向同一个固定 SOCKS 端口, 系统代理也不变, 无需触碰。
        running = true
        await syncTurnOn(true)
        return true
    }

    /// 只调整运行模式相关部分（TUN 启停 + 系统代理）。
    /// 适用于 pac/global/manual/tun 之间切换。
    /// 例外: xray 核心在 TUN 链路下配置不同（见 V2rayConfigHandler.applyTunChainOptions）,
    /// 进出 TUN 时需重新生成配置并重启核心; sing-box 核心配置与模式无关, 不重启。
    @discardableResult
    func applyMode(from oldMode: RunMode) async -> Bool {
        await lock(); defer { unlock() }
        guard running else {
            // 未运行: 无可应用; 由调用方决定是否 start()
            return true
        }
        let newMode = await MainActor.run { AppState.shared.runMode }
        if newMode == oldMode {
            return true
        }
        // xray 配置与是否 TUN 有关, 进出 TUN 时需按目标模式重载; 只判断一次（prepareAndStartCore 会改写 lastCore）
        let reloadXray = (newMode == .tun) != (oldMode == .tun) && lastCore == .XrayCore

        if oldMode == .tun && newMode != .tun {
            await stopTun()
        }
        if reloadXray, await prepareAndStartCore(tunMode: newMode == .tun) == nil {
            logger.warning("applyMode: core reload failed, restoring \(oldMode.rawValue)")
            return await restoreMode(oldMode, reloadXray: reloadXray)
        }
        if newMode == .tun && oldMode != .tun {
            switch await startTunWhenBackendReady() {
            case .started:
                break
            case .backendUnavailable:
                await noticeLocalized(title: .StartFailed, message: .SocksPortNotReadyForTun)
                logger.info("applyMode: TUN backend unavailable, reverting")
                return await restoreMode(oldMode, reloadXray: reloadXray)
            case .daemonFailed:
                await notifyTunFailed()
                logger.info("applyMode: TUN start failed, reverting")
                return await restoreMode(oldMode, reloadXray: reloadXray)
            }
        } else if reloadXray, !(await waitForLocalTCPReady(port: getEffectiveSocksProxyPort(), timeout: 6)) {
            logger.warning("applyMode: SOCKS port not ready in time, continuing anyway")
        }
        setSystemProxy(mode: newMode)
        logger.info("applyMode: \(oldMode.rawValue) -> \(newMode.rawValue)")
        return true
    }

    /// 模式切换失败后按旧模式恢复（核心配置 + TUN + 系统代理）, 恒返回 false 供调用方回退 UI。
    /// 旧模式也无法恢复时整体停止, 避免 UI 显示运行而实际不可用（调用方据 isRunning 同步开关状态）。
    private func restoreMode(_ oldMode: RunMode, reloadXray: Bool) async -> Bool {
        if reloadXray, await prepareAndStartCore(tunMode: oldMode == .tun) == nil {
            logger.warning("restoreMode: core restore failed, stopping all")
            await stopAll()
            return false
        }
        if oldMode == .tun, await startTunWhenBackendReady() != .started {
            logger.warning("restoreMode: TUN restore failed, stopping all")
            await stopAll()
            return false
        }
        setSystemProxy(mode: oldMode)
        return false
    }

    /// 只重建 TUN（停 TUN → 重写 tun.json → 起 TUN → 重设 DNS）, 不重启核心。
    /// 适用于网络变化 / 系统唤醒后恢复。仅在 tun 模式且运行中时生效。
    /// 若检测到代理核心已死亡（长时间睡眠后可能被系统回收）, 自动 fallback 到完整重启。
    /// - Parameter reloadXray: xray 是否按当前物理网卡重新生成配置并重启。
    ///   网络变化后需要（绑定的网卡可能已变）; tun-helper 意外退出的恢复不需要。
    @discardableResult
    func rebuildTun(reloadXray: Bool = true) async -> Bool {
        await lock(); defer { unlock() }
        guard running else {
            logger.info("rebuildTun skip: not running")
            return false
        }
        let mode = await MainActor.run { AppState.shared.runMode }
        guard mode == .tun else {
            logger.info("rebuildTun skip: mode=\(mode.rawValue)")
            return false
        }
        // 代理核心进程可能在长时间睡眠后被系统回收, 检查 SOCKS 端口是否可达
        let socksPort = getEffectiveSocksProxyPort()
        let coreAlive = await TCPConnectivity.canConnect(host: "127.0.0.1", port: socksPort, timeout: 1)
        if !coreAlive {
            logger.warning("rebuildTun: proxy core dead (SOCKS port \(socksPort) unreachable), falling back to full restart")
            await stopTun()
            return await startAll()
        }
        await stopTun()
        // xray 出站绑定了物理网卡名, 网络变化后需按新网卡重新生成配置并重启核心
        if reloadXray, lastCore == .XrayCore, await prepareAndStartCore(tunMode: true) == nil {
            logger.warning("rebuildTun: xray core reload failed, falling back to full restart")
            return await startAll()
        }
        let ok = await startTunWhenBackendReady() == .started
        logger.info("rebuildTun done: \(ok.description)")
        return ok
    }

    // MARK: - 内部组合操作（已持有锁时调用）

    private func startAll() async -> Bool {
        // 干净起步: 清掉可能残留的 TUN
        await stopTun()

        guard let _ = await prepareAndStartCore() else {
            setSystemProxy(mode: nil)
            running = false
            await syncTurnOn(false)
            return false
        }

        let mode = await MainActor.run { AppState.shared.runMode }
        if mode == .tun {
            switch await startTunWhenBackendReady() {
            case .started:
                break
            case .backendUnavailable:
                await stopAll()
                await noticeLocalized(title: .StartFailed, message: .SocksPortNotReadyForTun)
                return false
            case .daemonFailed:
                await notifyTunFailed()
                // TUN 启动失败: 整体回滚, 避免状态不一致
                await stopAll()
                return false
            }
        } else {
            // 非 TUN: 尽力等 SOCKS 就绪再设系统代理, 缩短首次请求失败窗口(不就绪也继续)。
            if !(await waitForLocalTCPReady(port: getEffectiveSocksProxyPort(), timeout: 6)) {
                logger.warning("startAll: SOCKS port not ready in time, continuing anyway")
            }
        }
        setSystemProxy(mode: mode)

        running = true
        await syncTurnOn(true)

        DispatchQueue.global().asyncAfter(deadline: .now() + 2) {
            LogRotation.rotateIfNeeded()
            LogRotation.extractErrors()
        }
        logger.info("startAll ok: mode=\(mode.rawValue)")
        return true
    }

    private func stopAll() async {
        logger.info("stopAll begin, running=\(self.running.description)")
        await stopTun()
        await LaunchAgent.shared.stopAgent()
        setSystemProxy(mode: nil)
        await AppState.shared.resetSpeed()
        await CoreTrafficStatsHandler.shared.resetData()
        running = false
        await syncTurnOn(false)
        logger.info("stopAll done")
    }

    // MARK: - 代理核心（不含 TUN / 系统代理 / DNS）

    /// 写配置 + 启动代理核心。返回核心类型, 失败返回 nil。
    /// 不触碰 TUN、系统代理、DNS。
    /// - Parameter tunMode: 生成核心配置时是否按 TUN 链路处理; nil 表示取当前运行模式。
    private func prepareAndStartCore(tunMode: Bool? = nil) async -> CoreType? {
        let currentMode = await MainActor.run { AppState.shared.runMode }
        let tunMode = tunMode ?? (currentMode == .tun)
        let runningCombination = await MainActor.run { AppState.shared.runningCombination }
        if !runningCombination.isEmpty {
            return await prepareAndStartCombinationCore(uuid: runningCombination, tunMode: tunMode)
        }

        // 获取运行中的 profile
        guard let running = ProfileStore.shared.getRunning() else {
            await noticeLocalized(title: .StartFailed, message: .NoAvailableServerConfig)
            await MainActor.run {
                AppState.shared.runningProfile = ""
                AppState.shared.runningServer = nil
            }
            return nil
        }
        guard await ProfileValidator.ensureLaunchable([running]) else { return nil }
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
                        NavigationState.shared.mainTab = .core
                        NavigationState.shared.coreSettingTab = .download
                        MainWindowManager.shared.openMainWindow()
                    }
                    await CoreViewModel.shared.downloadMinimumVersion(for: coreDecision)
                }
                return nil
            }
        }
        if !coreDecision.canLaunch {
            return nil
        }
        // 同步 AppState
        await MainActor.run {
            if AppState.shared.runningProfile != item.uuid {
                AppState.shared.runningProfile = item.uuid
                logger.info("prepareAndStartCore: sync runningProfile to \(item.remark)")
            }
            // 始终同步 runningServer，防止因 profile 编辑/重建导致内存态 stale
            AppState.shared.runningServer = item
            AppMenuManager.shared.refreshServerItems()
        }
        await AppState.shared.resetSpeed()
        await CoreTrafficStatsHandler.shared.resetData()

        // 停止旧核心
        await LaunchAgent.shared.stopAgent()
        // 等待旧核心释放 SOCKS 端口（避免新核心 bind 失败）
        guard await waitForLocalTCPReleased(port: getEffectiveSocksProxyPort(), timeout: 2) else {
            await noticeLocalized(title: .StartFailed, message: .LocalProxyPortNotReady)
            return nil
        }

        createJsonFile(item: item, tunMode: tunMode)

        // 轮转日志
        truncateLogFile(appLogFilePath)
        LogRotation.rotateSessionLog(at: coreLogFilePath)
        LogRotation.cleanSessionBackups(at: coreLogFilePath)

        // 启动守护进程
        let started = await LaunchAgent.shared.startAgent(coreType: coreDecision.coreType)
        if !started {
            await noticeLocalized(title: .StartFailed, message: .LaunchDaemonStartFailed)
            return nil
        }

        // 这里不等待 SOCKS 端口。调用方必须在启用 TUN 或系统代理前按模式协调就绪状态。
        // 后台统计 + ping（非关键, 不阻塞）
        Task {
            await CoreTrafficStatsHandler.shared.startTask(coreType: coreDecision.coreType)
            do {
                try await RunningProfileCheck.shared.check()
            } catch {
                logger.error("RunningProfileCheck.check failed: \(error)")
            }
        }
        self.lastCore = coreDecision.coreType
        logger.info("prepareAndStartCore ok: core=\(coreDecision.coreType.rawValue)")
        return coreDecision.coreType
    }

    private func prepareAndStartCombinationCore(uuid: String, tunMode: Bool) async -> CoreType? {
        guard let combination = CombinedConfigStore.shared.getValidCombination(uuid: uuid) else {
            await noticeLocalized(title: .StartFailed, message: .InvalidCombinationStartTip)
            await MainActor.run { AppState.shared.runningCombination = "" }
            return nil
        }

        let memberUUIDs = Set(combination.groups.flatMap { $0.outboundProfileUUIDs })
        let memberProfiles = ProfileStore.shared.fetchAll().filter { memberUUIDs.contains($0.uuid) }
        guard await ProfileValidator.ensureLaunchable(memberProfiles) else { return nil }
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
            return nil
        }

        if let warningMessage = resolved.warningMessage {
            if resolved.canLaunch {
                makeToast(message: warningMessage, displayDuration: 5)
            } else {
                let downloadMsg = warningMessage + "\n\n正在自动下载兼容版本..."
                let needDownload = await showDownloadAlert(title: await localized(.CoreCompatibilityWarningTitle), message: downloadMsg)
                if needDownload {
                    await MainActor.run {
                        NavigationState.shared.mainTab = .core
                        NavigationState.shared.coreSettingTab = .download
                        MainWindowManager.shared.openMainWindow()
                    }
                    await CoreViewModel.shared.downloadMinimumVersion(for: resolved)
                }
            }
        }
        if !resolved.canLaunch {
            logger.error("start combination aborted: incompatible with selected core")
            return nil
        }

        await MainActor.run {
            AppState.shared.runningProfile = firstProfile.uuid
            AppState.shared.runningServer = firstProfile
            AppMenuManager.shared.refreshCombinedConfigItems()
            AppMenuManager.shared.refreshServerItems()
            logger.info("prepareAndStartCombinationCore: sync runningProfile to \(firstProfile.remark)")
        }
        await AppState.shared.resetSpeed()
        await CoreTrafficStatsHandler.shared.resetData()

        await LaunchAgent.shared.stopAgent()
        guard await waitForLocalTCPReleased(port: getEffectiveSocksProxyPort(), timeout: 2) else {
            await noticeLocalized(title: .StartFailed, message: .LocalProxyPortNotReady)
            return nil
        }

        createJsonFile(combination: resolved, tunMode: tunMode)
        truncateLogFile(appLogFilePath)
        LogRotation.rotateSessionLog(at: coreLogFilePath)
        LogRotation.cleanSessionBackups(at: coreLogFilePath)

        let started = await LaunchAgent.shared.startAgent(coreType: resolved.coreType)
        if !started {
            await noticeLocalized(title: .StartFailed, message: .LaunchDaemonStartFailed)
            return nil
        }

        // 同 prepareAndStartCore: 不在此等待 SOCKS, 由调用方在启用下游转发前协调。
        Task {
            await CoreTrafficStatsHandler.shared.startTask(coreType: resolved.coreType)
        }
        self.lastCore = resolved.coreType
        logger.info("prepareAndStartCombinationCore ok: \(combination.displayName), core=\(resolved.coreType.rawValue)")
        return resolved.coreType
    }

    // MARK: - TUN（守护进程 + DNS）

    private func startTunWhenBackendReady() async -> TunStartResult {
        let port = getEffectiveSocksProxyPort()
        let result = await Self.startTunWhenBackendReady(
            waitForBackend: {
                await self.waitForLocalTCPReady(
                    port: port,
                    timeout: Self.tunBackendReadyTimeout
                )
            },
            startDaemon: {
                await self.startTun()
            }
        )
        if result == .backendUnavailable {
            logger.warning(
                "startTun: SOCKS port \(port) not ready after \(Self.tunBackendReadyTimeout)s; TUN not started"
            )
        }
        return result
    }

    /// 重写 tun.json、启动 TUN 守护进程、设置防污染 DNS。调用前必须确认 SOCKS 已就绪。
    /// 检测到需要网页登录时不启动 TUN, 进入暂停并返回 true（TUN 模式保持, 登录后自动恢复）。
    private func startTun() async -> Bool {
        if await CaptivePortal.loginRequired() {
            beginCaptiveWait()
            return true
        }
        // 检测并迁移旧版默认地址
        let migrated = await TunConfigHandler.migrateLegacyDefaults()
        if migrated {
            await MainActor.run {
                AppSettings.shared.tunAddress = UserDefaults.get(forKey: .tunAddress, defaultValue: TunConfigHandler.defaultTunAddress)
                AppSettings.shared.tunAddressIPv6 = UserDefaults.get(forKey: .tunAddressIPv6, defaultValue: TunConfigHandler.defaultTunIPv6)
            }
        }

        LogRotation.rotateSessionLog(at: tunLogFilePath)
        LogRotation.rotateSessionLog(at: runTunLogFilePath)
        LogRotation.cleanSessionBackups(at: tunLogFilePath)
        LogRotation.cleanSessionBackups(at: runTunLogFilePath)
        let ok = await TunHandler.shared.start()
        if ok {
            Self.setupTunDns()
            logger.info("startTun ok")
            let ipv6Enabled = await AppSettings.shared.tunEnableIPv6
            let showReminder = await AppSettings.shared.tunShowIPv6Reminder
            if ipv6Enabled && showReminder {
                let title = await localized(.TunEnableIPv6AlertTitle)
                let msg = await localized(.TunEnableIPv6ChromeWarning)
                let settingsLabel = await localized(.Settings)
                let okLabel = await localized(.OK)
                if await showConfirmAlert(title: title, message: msg, confirmTitle: settingsLabel, cancelTitle: okLabel) {
                    await MainActor.run {
                        NavigationState.shared.mainTab = .setting
                        NavigationState.shared.settingTab = .tun
                        MainWindowManager.shared.openMainWindow()
                    }
                }
            }
        } else {
            logger.warning("startTun: TUN daemon failed to start (continuing without teardown)")
        }
        return ok
    }

    /// 先停止 TUN 守护进程（移除路由）, 再恢复 DNS, 避免 DNS 已清除但路由仍指向失效 TUN 的中间状态。
    private func stopTun() async {
        // 停止/重建/切换模式时结束登录等待; 若仍需登录, 下次 startTun 会重新进入暂停
        captiveWaitTask?.cancel()
        captiveWaitTask = nil
        captiveGeneration += 1
        await TunHandler.shared.stop()
        Self.restoreTunDns()
    }

    // MARK: - 公共 Wi-Fi 网页登录

    private func beginCaptiveWait() {
        guard captiveWaitTask == nil else { return }
        logger.warning("captive portal detected: TUN paused until login")
        Task { @MainActor in makeToast(message: String(localized: .CaptivePortalTunPaused), displayDuration: 6) }
        captiveGeneration += 1
        let generation = captiveGeneration
        captiveWaitTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(Self.captivePollInterval * 1_000_000_000))
                if Task.isCancelled { return }
                if !(await CaptivePortal.loginRequired()) {
                    await self?.resumeAfterCaptive(generation: generation)
                    return
                }
            }
        }
    }

    private func resumeAfterCaptive(generation: Int) async {
        await lock(); defer { unlock() }
        // 只认当前这一轮等待; 只清引用不取消: 当前正运行在该任务内
        guard generation == captiveGeneration, captiveWaitTask != nil else { return }
        captiveWaitTask = nil
        let mode = await MainActor.run { AppState.shared.runMode }
        guard running, mode == .tun else { return }
        logger.info("captive portal login done, resuming TUN")
        switch await startTunWhenBackendReady() {
        case .started:
            Task { @MainActor in makeToast(message: String(localized: .CaptivePortalTunResumed), displayDuration: 4) }
        case .backendUnavailable:
            await noticeLocalized(title: .StartFailed, message: .SocksPortNotReadyForTun)
        case .daemonFailed:
            await notifyTunFailed()
        }
    }

    /// TUN 运行中检测到需要登录（登录过期、中途换网）: 重建 TUN, 由 startTun 进入暂停。
    func pauseTunForCaptivePortal() async {
        logger.warning("captive portal detected while TUN running, pausing TUN")
        _ = await rebuildTun(reloadXray: false)
    }

    // MARK: - 端口探测

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

    /// 等待旧核心释放端口（端口从可连接变为不可连接）
    private func waitForLocalTCPReleased(port: UInt16, timeout: TimeInterval) async -> Bool {
        guard port > 0 else { return true }
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if !(await TCPConnectivity.canConnect(host: "127.0.0.1", port: port, timeout: 0.5)) {
                return true
            }
            try? await Task.sleep(nanoseconds: 200_000_000)
        }
        logger.warning("waitForLocalTCPReleased: port \(port) still occupied after \(timeout)s")
        return false
    }

    // MARK: - 配置文件生成

    private func createJsonFile(item: ProfileEntity, tunMode: Bool) {
        let cfg = CoreConfigHandler()
        let jsonText = cfg.toJSON(item: item, tunMode: tunMode)
        do {
            try jsonText.write(to: URL(fileURLWithPath: JsonConfigFilePath), atomically: true, encoding: .utf8)
            logger.info("createJsonFile: wrote \(JsonConfigFilePath)")
        } catch {
            logger.info("Failed to write JSON file: \(error)")
            noticeTip(title: "Failed to write JSON file: \(error)")
        }
    }

    private func createJsonFile(combination resolved: CombinedConfigResolved, tunMode: Bool) {
        let cfg = CoreConfigHandler()
        let jsonText = cfg.toJSON(combination: resolved, tunMode: tunMode)
        do {
            try jsonText.write(to: URL(fileURLWithPath: JsonConfigFilePath), atomically: true, encoding: .utf8)
            logger.info("createCombinedJsonFile: wrote \(JsonConfigFilePath)")
        } catch {
            logger.info("Failed to write combined JSON file: \(error)")
            noticeTip(title: "Failed to write combined JSON file: \(error)")
        }
    }

    // MARK: - 系统代理

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
            if !GeneratePACFile(rewrite: true) {
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

    /// 读取当前系统 DNS
    nonisolated private static func readCurrentDns() -> [String] {
        // V2rayUTool 对所有网络服务设置 DNS, 这里遍历全部服务（服务名因机型/用户重命名而异）
        let listing = (try? runCommand(at: "/usr/sbin/networksetup", with: ["-listallnetworkservices"])) ?? ""
        let services = listing.split(separator: "\n").dropFirst().map(String.init).filter { !$0.hasPrefix("*") }
        for svc in services {
            if let output = try? runCommand(at: "/usr/sbin/networksetup", with: ["-getdnsservers", svc]) {
                let servers = output.split(separator: "\n").filter { !$0.contains("empty") && !$0.contains("There") }
                if !servers.isEmpty {
                    return servers.map { $0.trimmingCharacters(in: .whitespaces) }
                }
            }
        }
        return []
    }

    /// TUN 启动后把系统 DNS 指向占位地址（通过 V2rayUTool 提权），使系统 DNS 查询进入 TUN 由 hijack-dns 分流。
    /// 原因与地址选择见 TunConfigHandler.systemDnsAddress。
    nonisolated static func setupTunDns() {
        let dnsServer = TunConfigHandler.systemDnsAddress()
        let current = readCurrentDns()
        let lastSet = UserDefaults.get(forKey: .tunDnsSetValue)
        // 上次写入后未恢复（异常退出）且系统 DNS 仍是当时写入的值: 沿用当时记录的用户原始 DNS;
        // 否则以当前值为用户原始 DNS。
        if lastSet.isEmpty || current != [lastSet] {
            UserDefaults.set(forKey: .tunDnsOriginal, value: current.joined(separator: " "))
        }
        // 系统 DNS 已是占位地址（上次恢复失败）时先清除再设置: 只有 DNS 配置真正变化时 mDNSResponder 才会清空缓存,
        // 否则 TUN 不在期间直连占位 DNS 得到的污染结果（如 google → 69.171.235.22）会被继续使用。
        if current == [dnsServer] {
            _ = try? runCommand(at: v2rayUTool, with: ["-dns-clear"])
        }
        if (try? runCommand(at: v2rayUTool, with: ["-dns-setup", dnsServer])) != nil {
            UserDefaults.set(forKey: .tunDnsSetValue, value: dnsServer)
            logger.info("DNS set to \(dnsServer), original=\(current)")
        } else {
            logger.warning("DNS change failed")
        }
    }

    /// 恢复 TUN 启动前的用户 DNS。仅当记录表明本程序写入过 DNS 时才生效（不会误改用户自己的 DNS）;
    /// 若用户在此期间手动改过系统 DNS, 尊重用户设置, 只清除记录。
    /// 停止 TUN 时调用; App 启动时也调用一次以恢复上次异常退出的残留。
    nonisolated static func restoreTunDns() {
        let lastSet = UserDefaults.get(forKey: .tunDnsSetValue)
        guard !lastSet.isEmpty else {
            logger.info("restoreTunDns skip: DNS was not set by V2rayU")
            return
        }
        let original = UserDefaults.get(forKey: .tunDnsOriginal).split(separator: " ").map(String.init)
        let current = readCurrentDns()
        guard current == [lastSet] else {
            logger.info("restoreTunDns: system DNS changed by user (\(current)), keep it")
            clearTunDnsRecord()
            return
        }
        let args = original.isEmpty ? ["-dns-clear"] : ["-dns-restore"] + original
        if (try? runCommand(at: v2rayUTool, with: args)) != nil {
            clearTunDnsRecord()
            logger.info("DNS restored to \(original.isEmpty ? "DHCP" : original.joined(separator: " "))")
        } else {
            // 保留记录, 下次停止/启动时重试
            logger.warning("restoreTunDns failed, will retry later")
        }
    }

    /// 旧版本 TUN 期间可能写入系统 DNS 的值: 8f63189 固定 1.1.1.1, 之后为"Tun 国外 DNS"选项
    /// （1.1.1.1 / 8.8.8.8 / 9.9.9.9 / 208.67.222.222）。写入时用的选项可能已被用户改过, 因此全部视为候选。
    static let legacyTunSystemDns = ["1.1.1.1", "8.8.8.8", "9.9.9.9", "208.67.222.222"]

    /// 一次性迁移（升级后首次启动）: 旧版本异常退出会残留上述 DNS, 且没有新版的写入记录, restoreTunDns 不会处理。
    /// 无新版记录且系统 DNS 恰好是单个候选值时视为旧版残留, 恢复为 DHCP（与旧版本自身的残留判断一致）。
    nonisolated static func migrateLegacyTunDns() {
        guard !UserDefaults.getBool(forKey: .tunDnsLegacyMigrated) else { return }
        // 只有用过 TUN 的用户才可能有旧版残留（tun.json 仅在启动 TUN 时生成）; 未用过 TUN 的用户手动设的 8.8.8.8 等不能动
        guard FileManager.default.fileExists(atPath: TunConfigFilePath) else {
            UserDefaults.setBool(forKey: .tunDnsLegacyMigrated, value: true)
            return
        }
        var candidates = Set(legacyTunSystemDns)
        candidates.insert(UserDefaults.get(forKey: .tunDnsRemote, defaultValue: "1.1.1.1"))
        let current = readCurrentDns()
        if UserDefaults.get(forKey: .tunDnsSetValue).isEmpty, current.count == 1, candidates.contains(current[0]) {
            guard (try? runCommand(at: v2rayUTool, with: ["-dns-clear"])) != nil else {
                logger.warning("migrateLegacyTunDns: clear failed, will retry next launch")
                return
            }
            logger.info("migrateLegacyTunDns: cleared legacy TUN DNS residue \(current)")
        }
        UserDefaults.setBool(forKey: .tunDnsLegacyMigrated, value: true)
    }

    nonisolated private static func clearTunDnsRecord() {
        UserDefaults.del(forKey: .tunDnsSetValue)
        UserDefaults.del(forKey: .tunDnsOriginal)
    }
}
