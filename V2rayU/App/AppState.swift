import Combine
import SwiftUI
import KeyboardShortcuts

@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()


    // 运行状态的"真值"在 V2rayLaunch actor 的 `running`(受串行锁保护)。
    // `v2rayTurnOn` 是它在 UI 侧的镜像: 每个 V2rayLaunch 操作结束都会把它同步成 running,
    // 各 switch 方法对它的写入也始终等于该操作的返回值, 因此最终值恒等于 running(不会脑裂)。
    // `icon` 完全由 (v2rayTurnOn, runMode) 派生(见下方 didSet), 不存在第二个写入点,
    // 所以图标永远与 v2rayTurnOn 一致。
    // 需要判断"子系统是否该在运行"的并发逻辑(如网络重建)一律以 actor 的 running 为准, 而非本字段。
    @Published var v2rayTurnOn: Bool = UserDefaults.getBool(forKey: .v2rayTurnOn) {
        didSet {
            UserDefaults.setBool(forKey: .v2rayTurnOn, value: v2rayTurnOn)
            icon = v2rayTurnOn ? runMode.icon : "IconOff"
        }
    }
    @Published var runMode: RunMode = UserDefaults.getEnum(forKey: .runMode, type: RunMode.self, defaultValue: .tun) {
        didSet {
            UserDefaults.set(forKey: .runMode, value: runMode.rawValue)
            lastRunMode = runMode
            icon = v2rayTurnOn ? runMode.icon : "IconOff"
        }
    }
    @Published var lastRunMode: RunMode = UserDefaults.getEnum(forKey: .lastRunMode, type: RunMode.self, defaultValue: .pac) {
        didSet { UserDefaults.set(forKey: .lastRunMode, value: lastRunMode.rawValue) }
    }
    @Published var icon: String = "IconOff"
    @Published var runningProfile: String = UserDefaults.get(forKey: .runningProfile, defaultValue: "") {
        didSet { UserDefaults.set(forKey: .runningProfile, value: runningProfile) }
    }
    @Published var runningRouting: String = UserDefaults.get(forKey: .runningRouting, defaultValue: "") {
        didSet { UserDefaults.set(forKey: .runningRouting, value: runningRouting) }
    }
    @Published var runningCombination: String = UserDefaults.get(forKey: .runningCombination, defaultValue: "") {
        didSet { UserDefaults.set(forKey: .runningCombination, value: runningCombination) }
    }
    @Published var runningServer: ProfileEntity? = nil

    @Published var latency = 0.0
    @Published var directUpSpeed = 0.0
    @Published var directDownSpeed = 0.0
    @Published var proxyUpSpeed = 0.0
    @Published var proxyDownSpeed = 0.0

    init() {
        self.icon = v2rayTurnOn ? runMode.icon : "IconOff"

        // NOTE: runningServer is loaded later in appDidLaunch() to avoid
        // triggering nested singleton initialization (AppState → ProfileStore → AppDatabase)
        // during AppState.shared dispatch_once, which causes a crash.

        // 注册键盘快捷键处理
        KeyboardShortcuts.onKeyDown(for: .toggleV2rayOnOff) { [weak self] in
            Task { @MainActor in
                await self?.toggleCore()
            }
        }

        KeyboardShortcuts.onKeyDown(for: .switchProxyMode) { [weak self] in
            Task { @MainActor in
                guard let self = self else { return }
                // 循环切换: pac -> manual -> global -> tun -> pac
                let modes: [RunMode] = [.pac, .manual, .global, .tun]
                if let currentIndex = modes.firstIndex(of: self.runMode) {
                    let nextIndex = (currentIndex + 1) % modes.count
                    await self.switchRunMode(mode: modes[nextIndex])
                } else {
                    await self.switchRunMode(mode: .pac)
                }
            }
        }

        KeyboardShortcuts.onKeyDown(for: .switchToTunnelMode) { [weak self] in
            Task { @MainActor in
                await self?.switchRunMode(mode: .tun)
            }
        }

        KeyboardShortcuts.onKeyDown(for: .switchToGlobalMode) { [weak self] in
            Task { @MainActor in
                await self?.switchRunMode(mode: .global)
            }
        }

        KeyboardShortcuts.onKeyDown(for: .switchToManualMode) { [weak self] in
            Task { @MainActor in
                await self?.switchRunMode(mode: .manual)
            }
        }

        KeyboardShortcuts.onKeyDown(for: .switchToPacMode) { [weak self] in
            Task { @MainActor in
                await self?.switchRunMode(mode: .pac)
            }
        }

        KeyboardShortcuts.onKeyDown(for: .viewConfigJson) {
            AppMenuManager.shared.openConfigFile()
        }

        KeyboardShortcuts.onKeyDown(for: .viewPacFile) {
            AppMenuManager.shared.openPacFile()
        }

        KeyboardShortcuts.onKeyDown(for: .viewLog) {
            AppMenuManager.shared.openLogsFile()
        }

        KeyboardShortcuts.onKeyDown(for: .pingSpeed) {
            AppMenuManager.shared.pingSpeedTest()
        }

        KeyboardShortcuts.onKeyDown(for: .importServers) {
            AppMenuManager.shared.importFromPasteboard()
        }

        KeyboardShortcuts.onKeyDown(for: .scanQRCode) {
            AppMenuManager.shared.scanQRCode()
        }

        KeyboardShortcuts.onKeyDown(for: .shareQRCode) {
            AppMenuManager.shared.shareQRCode()
        }

        KeyboardShortcuts.onKeyDown(for: .copyHttpProxy) {
            AppMenuManager.shared.copyProxyExportCommand()
        }
    }

    // MARK: - 更新速度
    func setSpeed(latency: Double, directUpSpeed: Double, directDownSpeed: Double, proxyUpSpeed: Double, proxyDownSpeed: Double) {
        if !self.v2rayTurnOn { return }
        // 延迟到下一 runloop，避免在 AppKit 菜单/事件处理期间触发 AttributeGraph 重入
        Task { @MainActor in
            self.latency = latency
            self.directUpSpeed = directUpSpeed
            self.directDownSpeed = directDownSpeed
            self.proxyUpSpeed = proxyUpSpeed
            self.proxyDownSpeed = proxyDownSpeed
        }
        // 组合模式下, 各 profile 的 speed 已由 XrayApiStatsHandler.parseV2RayStats 单独更新
        guard runningCombination.isEmpty else { return }
        ProfileStore.shared.updateSpeed(uuid: self.runningProfile, speed: Int(latency))
    }

    func setTraffic(upSpeed: Double, downSpeed: Double) {
        self.proxyUpSpeed = upSpeed
        self.proxyDownSpeed = downSpeed
    }

    func setLatency(latency: Double) {
        self.latency = latency
    }

    func resetSpeed() {
        self.latency = 0
        self.directUpSpeed = 0
        self.directDownSpeed = 0
        self.proxyUpSpeed = 0
        self.proxyDownSpeed = 0
    }

    // MARK: - 启动/停止核心
    // 状态机收敛到 V2rayLaunch actor（内部串行锁 + running 标志）。
    // AppState 只负责: 更新可观察状态 → 调用 V2rayLaunch 的某个粒度操作 → 刷新菜单。
    func setCoreRunning(_ on: Bool) async {
        if on {
            let success = await V2rayLaunch.shared.start()
            v2rayTurnOn = success
            logger.info("setCoreRunning: started=\(success)")
        } else {
            await V2rayLaunch.shared.stop()
            v2rayTurnOn = false
            logger.info("setCoreRunning: stopped")
        }
    }

    // MARK: - 切换运行模式
    // 模式只影响"系统代理"与"TUN", 与核心配置无关 → 不重启核心。
    func switchRunMode(mode: RunMode) async {
        let oldMode = runMode
        guard oldMode != mode else { return }
        runMode = mode
        v2rayTurnOn = true
        logger.info("switchRunMode: \(oldMode.rawValue) -> \(mode.rawValue)")
        if await V2rayLaunch.shared.isRunning {
            // 运行中: 只调整 TUN + 系统代理, 核心保持不动。
            await V2rayLaunch.shared.applyMode(from: oldMode)
        } else {
            // 未运行: 直接按新模式拉起。
            let success = await V2rayLaunch.shared.start()
            v2rayTurnOn = success
        }
        AppMenuManager.shared.refreshBasicMenus()
    }

    // MARK: - 切换路由
    // 路由属于核心配置 → 只重载核心, 不动 TUN / 系统代理。
    func switchRouting(uuid: String) async {
        runningRouting = uuid
        v2rayTurnOn = true
        let success = await V2rayLaunch.shared.reloadCore()
        v2rayTurnOn = success
        logger.info("switchRouting: \(self.runningRouting)")
        AppMenuManager.shared.refreshRoutingItems()
        AppMenuManager.shared.refreshBasicMenus()
    }

    // MARK: - 切换组合配置 (toggle 行为)
    func switchCombination(uuid: String) async {
        // 已激活 → 取消选择 → 停止
        if runningCombination == uuid {
            runningCombination = ""
            runningProfile = ""
            runningServer = nil
            v2rayTurnOn = false
            await V2rayLaunch.shared.stop()
            logger.info("switchCombination-deselect: \(uuid)")
            AppMenuManager.shared.refreshCombinedConfigItems()
            AppMenuManager.shared.refreshServerItems()
            AppMenuManager.shared.refreshBasicMenus()
            return
        }
        guard let combo = CombinedConfigStore.shared.getValidCombination(uuid: uuid) else {
            runningCombination = ""
            noticeTip(title: String(localized: .InvalidCombination), informativeText: String(localized: .InvalidCombinationTip))
            AppMenuManager.shared.refreshCombinedConfigItems()
            AppMenuManager.shared.refreshBasicMenus()
            return
        }
        runningCombination = uuid
        logger.info("switchCombination: \(self.runningCombination)")
        // 选择组合内第一个有效 profile 作为入口 server, 以便单核心也能跑起来
        if let firstProfileId = combo.groups.flatMap({ $0.outboundProfileUUIDs }).first,
           let profile = ProfileStore.shared.fetchOne(uuid: firstProfileId) {
            runningProfile = profile.uuid
            runningServer = profile
        }
        v2rayTurnOn = true
        // 组合属于核心配置 → 只重载核心。
        let success = await V2rayLaunch.shared.reloadCore()
        v2rayTurnOn = success
        AppMenuManager.shared.refreshCombinedConfigItems()
        AppMenuManager.shared.refreshServerItems()
        AppMenuManager.shared.refreshBasicMenus()
    }

    // MARK: - 切换配置
    // 服务器属于核心配置 → 只重载核心, 不动 TUN / 系统代理。
    func switchServer(uuid: String) async {
        // 点击已激活的单服务器不做任何操作
        if runningProfile == uuid, runningCombination.isEmpty {
            return
        }
        runningCombination = ""
        runningProfile = uuid
        v2rayTurnOn = true

        let success = await V2rayLaunch.shared.reloadCore()
        v2rayTurnOn = success

        runningServer = ProfileStore.shared.getRunning()
        latency = Double(runningServer?.speed ?? 0)
        logger.info("switchServer-end: \(self.runningProfile)")
        AppMenuManager.shared.refreshServerItems()
        AppMenuManager.shared.refreshBasicMenus()
    }

    // MARK: - App 启动时调用
    func appDidLaunch() async {
        LogRotation.rotateIfNeeded()
        LogRotation.extractErrors()
        startHttpServer()

        // 同步运行中的服务器配置
        if let running = ProfileStore.shared.getRunning() {
            if runningProfile != running.uuid {
                runningProfile = running.uuid
                logger.info("appDidLaunch: sync server to \(running.remark)")
            }
            runningServer = running
            latency = Double(running.speed)
        } else {
            runningProfile = ""
            runningServer = nil
            latency = 0
            // 没有可用服务器时，强制关闭启动状态
            v2rayTurnOn = false
            logger.info("appDidLaunch: no available server, force v2rayTurnOn=false")
        }

        // 同步运行中的路由配置
        let routingManager = RoutingManager()
        let runningRoutingEntity = routingManager.getRunningEntity()
        if runningRouting != runningRoutingEntity.uuid {
            runningRouting = runningRoutingEntity.uuid
            logger.info("appDidLaunch: sync routing to \(runningRoutingEntity.remark)")
        }

        if !runningCombination.isEmpty,
           CombinedConfigStore.shared.getValidCombination(uuid: runningCombination) == nil {
            logger.info("appDidLaunch: invalid runningCombination, clear")
            runningCombination = ""
        }

        logger.info("appDidLaunch: mode=\(self.runMode.rawValue),v2rayTurnOn=\(self.v2rayTurnOn.description),runningProfile=\(self.runningProfile)")

        // 根据启动状态
        await setCoreRunning(v2rayTurnOn)
        // 刷新菜单必须在 setCoreRunning 之后,确保菜单反映实际状态
        AppMenuManager.shared.refreshAllMenus()

        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
            Task {
                await SubscriptionScheduler.shared.runAtStart()
            }
        }

        if AppSettings.shared.checkForUpdates {
            DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                AppMenuManager.shared.versionController.checkForUpdates(showWindow: false)
            }
        }

        // 首次启动时拷贝 bundle rules 到 ~/.V2rayU/capability-rules/
        DispatchQueue.main.asyncAfter(deadline: .now() + 15) {
            CapabilityRulesLoader.seedOverrideIfNeeded()
            // 检查远程更新（1 天一次）
            CapabilityRulesLoader.checkForUpdatesIfNeeded()
        }
    }

    // MARK: - 菜单栏 Toggle
    func toggleCore() async {
        v2rayTurnOn.toggle()
        await setCoreRunning(v2rayTurnOn)
        AppMenuManager.shared.refreshBasicMenus()
    }

    func turnOnCore() async {
        v2rayTurnOn = true
        await setCoreRunning(v2rayTurnOn)
        AppMenuManager.shared.refreshBasicMenus()
    }

    func turnOffCore() async {
        v2rayTurnOn = false
        await setCoreRunning(v2rayTurnOn)
        AppMenuManager.shared.refreshBasicMenus()
    }
}
