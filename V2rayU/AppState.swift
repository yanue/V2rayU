import Combine
import SwiftUI


@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    // UI 绑定状态
    @Published var mainTab: ContentView.Tab = .server
    @Published var settingTab: SettingView.SettingTab = .general
    @Published var helpTab: HelpPageView.HelpTab = .qa

    @Published var v2rayTurnOn: Bool = UserDefaults.getBool(forKey: .v2rayTurnOn) {
        didSet { UserDefaults.setBool(forKey: .v2rayTurnOn, value: v2rayTurnOn) }
    }
    @Published var runMode: RunMode = UserDefaults.getEnum(forKey: .runMode, type: RunMode.self, defaultValue: .off) {
        didSet { UserDefaults.set(forKey: .runMode, value: runMode.rawValue) }
    }
    @Published var icon: String = RunMode.off.icon
    @Published var runningProfile: String = UserDefaults.get(forKey: .runningProfile, defaultValue: "")
    {
        didSet { UserDefaults.set(forKey: .runningProfile, value: runningProfile) }
    }
    @Published var runningRouting: String = UserDefaults.get(forKey: .runningRouting, defaultValue: "")
    {
        didSet { UserDefaults.set(forKey: .runningRouting, value: runningRouting) }
    }
    @Published var runningServer: ProfileDTO? = ProfileViewModel.getRunning()

    @Published var latency = 0.0
    @Published var directUpSpeed = 0.0
    @Published var directDownSpeed = 0.0
    @Published var proxyUpSpeed = 0.0
    @Published var proxyDownSpeed = 0.0
    
    init() {
        self.icon = runMode.icon
    }
    
    private var isCoreOperationInProgress = false

    // MARK: - 更新速度
    func setSpeed(latency: Double, directUpSpeed: Double, directDownSpeed: Double, proxyUpSpeed: Double, proxyDownSpeed: Double) {
        if !self.v2rayTurnOn {
            return
        }
        self.latency = latency
        self.directUpSpeed = directUpSpeed
        self.directDownSpeed = directDownSpeed
        self.proxyUpSpeed = proxyUpSpeed
        self.proxyDownSpeed = proxyDownSpeed
        // 更新数据库
        ProfileViewModel.update_speed(uuid: self.runningProfile, speed: Int(latency))
    }

    func resetSpeed(){
        self.latency = 0
        self.directUpSpeed = 0
        self.directDownSpeed = 0
        self.proxyUpSpeed = 0
        self.proxyDownSpeed = 0
    }
    
    // MARK: - 启动/停止核心
    
    func setCoreRunning(_ running: Bool) {
        guard !isCoreOperationInProgress else { return }
        isCoreOperationInProgress = true

        Task {
            defer { isCoreOperationInProgress = false }

            self.resetSpeed()

            if running {
                let success = await V2rayLaunch.shared.start()
                if success {
                    v2rayTurnOn = true
                    icon = runMode.icon
                } else {
                    v2rayTurnOn = false
                    icon = RunMode.off.icon
                }
            } else {
                await V2rayLaunch.shared.stop()
                v2rayTurnOn = false
                icon = RunMode.off.icon
            }
        }
    }

    // MARK: - 切换运行模式
    func switchRunMode(mode: RunMode) {
        runMode = mode
        v2rayTurnOn = true // 先更改状态
        logger.info("appState-switchRunMode: \(mode.rawValue), \(self.runMode.rawValue)")
        setCoreRunning(v2rayTurnOn)
        AppMenuManager.shared.refreshBasicMenus()
    }

    // MARK: - 切换路由
    func switchRouting(uuid: String) {
        runningRouting = uuid
        v2rayTurnOn = true // 先更改状态
        setCoreRunning(v2rayTurnOn)
        logger.info("switchRouting: \(self.runningRouting)")
        AppMenuManager.shared.refreshRoutingItems()
    }

    // MARK: - 切换配置
    func switchServer(uuid: String) {
        runningProfile = uuid
        v2rayTurnOn = true // 先更改状态
        setCoreRunning(v2rayTurnOn)
        runningServer = ProfileViewModel.getRunning()
        logger.info("switchServer-end: \(self.runningProfile)")
        AppMenuManager.shared.refreshServerItems()
    }

    // MARK: - App 启动时调用
    func appDidLaunch() {
        truncateLogFile(v2rayLogFilePath)
        truncateLogFile(appLogFilePath)
        startHttpServer()
        Task { await V2rayTrafficStats.shared.initTask() }
        
        logger.info("appDidLaunch: mode=\(self.runMode.rawValue),v2rayTurnOn=\(self.v2rayTurnOn.description)")

        if v2rayTurnOn {
            setCoreRunning(v2rayTurnOn)
        }
        // 刷新图标等
        AppMenuManager.shared.refreshBasicMenus()
        Task {
            await SubscriptionScheduler.shared.runAtStart()
        }
        // 检查是否需要更新
        if AppSettings.shared.checkForUpdates {
            // 10秒后检查
            DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                AppMenuManager.shared.versionController.checkForUpdates(showWindow: false)
            }
        }
    }

    // MARK: - 菜单栏 Toggle
    func toggleCore() {
        v2rayTurnOn = !v2rayTurnOn  // 先更改状态
        setCoreRunning(v2rayTurnOn)
        AppMenuManager.shared.refreshBasicMenus()
    }
    
    func turnOnCore() {
        v2rayTurnOn = true // 先更改状态
        setCoreRunning(v2rayTurnOn)
        AppMenuManager.shared.refreshBasicMenus()
    }
    
    func turnOffCore() {
        v2rayTurnOn = false // 先更改状态
        setCoreRunning(v2rayTurnOn)
        AppMenuManager.shared.refreshBasicMenus()
    }
}
