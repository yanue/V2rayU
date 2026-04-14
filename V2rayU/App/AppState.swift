import Combine
import SwiftUI
import KeyboardShortcuts

@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    // UI 绑定状态
    @Published var mainTab: ContentView.Tab = .server
    @Published var settingTab: SettingView.SettingTab = .general

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
    
    private var isCoreOperationInProgress = false

    // MARK: - 更新速度
    func setSpeed(latency: Double, directUpSpeed: Double, directDownSpeed: Double, proxyUpSpeed: Double, proxyDownSpeed: Double) {
        if !self.v2rayTurnOn { return }
        self.latency = latency
        self.directUpSpeed = directUpSpeed
        self.directDownSpeed = directDownSpeed
        self.proxyUpSpeed = proxyUpSpeed
        self.proxyDownSpeed = proxyDownSpeed
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
    func setCoreRunning(_ running: Bool) async {
        guard !isCoreOperationInProgress else {
            logger.info("setCoreRunning: isCoreOperationInProgress, return")
            return
        }
        isCoreOperationInProgress = true
        defer { isCoreOperationInProgress = false }

        if running {
            let success = await V2rayLaunch.shared.start()
            v2rayTurnOn = success
            logger.info("setCoreRunning: started=\(success), v2rayTurnOn=\(self.v2rayTurnOn.description)")
            if !success {
                await V2rayLaunch.shared.stop()
                v2rayTurnOn = false
                logger.info("setCoreRunning: stopped, v2rayTurnOn=\(self.v2rayTurnOn.description)")
            }
        } else {
            await V2rayLaunch.shared.stop()
            v2rayTurnOn = false
            logger.info("setCoreRunning: stopped, v2rayTurnOn=\(self.v2rayTurnOn.description)")
        }
    }

    // MARK: - 切换运行模式
    func switchRunMode(mode: RunMode) async {
        runMode = mode
        v2rayTurnOn = true
        logger.info("switchRunMode: \(mode.rawValue), \(self.runMode.rawValue)")
        await setCoreRunning(v2rayTurnOn)
        AppMenuManager.shared.refreshBasicMenus()
    }

    // MARK: - 切换路由
    func switchRouting(uuid: String) async {
        runningRouting = uuid
        v2rayTurnOn = true
        await setCoreRunning(v2rayTurnOn)
        logger.info("switchRouting: \(self.runningRouting)")
        AppMenuManager.shared.refreshRoutingItems()
    }

    // MARK: - 切换配置
    func switchServer(uuid: String) async {
        runningProfile = uuid
        v2rayTurnOn = true
        await setCoreRunning(v2rayTurnOn)
        runningServer = ProfileStore.shared.getRunning()
        latency = Double(runningServer?.speed ?? 0)
        logger.info("switchServer-end: \(self.runningProfile)")
        AppMenuManager.shared.refreshServerItems()
        AppMenuManager.shared.refreshBasicMenus()
    }

    // MARK: - App 启动时调用
    func appDidLaunch() {
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
        
        logger.info("appDidLaunch: mode=\(self.runMode.rawValue),v2rayTurnOn=\(self.v2rayTurnOn.description),runningProfile=\(self.runningProfile)")

        Task {
            // 根据启动状态
            await setCoreRunning(v2rayTurnOn)
            // 刷新菜单必须在 setCoreRunning 之后,确保菜单反映实际状态
            AppMenuManager.shared.refreshAllMenus()
        }

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
