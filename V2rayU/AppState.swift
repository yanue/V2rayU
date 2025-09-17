import Combine
import SwiftUI


@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    // UI 绑定状态
    @Published var mainTab: ContentView.Tab = .activity
    @Published var settingTab: SettingView.SettingTab = .general
    @Published var helpTab: HelpPageView.HelpTab = .diagnostic

    @Published var v2rayTurnOn: Bool = UserDefaults.getBool(forKey: .v2rayTurnOn) {
        didSet { UserDefaults.setBool(forKey: .v2rayTurnOn, value: v2rayTurnOn) }
    }
    @Published var runMode: RunMode = UserDefaults.getEnum(forKey: .runMode, type: RunMode.self, defaultValue: .off) {
        didSet { UserDefaults.set(forKey: .runMode, value: runMode.rawValue) }
    }
    @Published var icon: String = RunMode.off.icon
    @Published var runningProfile: String = UserDefaults.get(forKey: .runningProfile, defaultValue: "")
    @Published var runningRouting: String = UserDefaults.get(forKey: .runningRouting, defaultValue: "")
    @Published var runningServer: ProfileModel? = ProfileViewModel.getRunning()

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
        self.latency = latency
        self.directUpSpeed = directUpSpeed
        self.directDownSpeed = directDownSpeed
        self.proxyUpSpeed = proxyUpSpeed
        self.proxyDownSpeed = proxyDownSpeed
    }

    // MARK: - 启动/停止核心
    
    func setCoreRunning(_ running: Bool) {
        guard !isCoreOperationInProgress else { return }
        isCoreOperationInProgress = true

        Task {
            defer { isCoreOperationInProgress = false }

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
        logger.info("appState-switchRunMode: \(mode.rawValue), \(self.runMode.rawValue)")
        setCoreRunning(true)
        StatusItemManager.shared.refreshBasicMenus()
    }

    // MARK: - 切换路由
    func runRouting(uuid: String) {
        runningRouting = uuid
        setCoreRunning(true)
        StatusItemManager.shared.refreshRoutingItems()
    }

    // MARK: - 切换配置
    func runProfile(uuid: String) {
        runningProfile = uuid
        runningServer = ProfileViewModel.getRunning()
        setCoreRunning(true)
        StatusItemManager.shared.refreshServerItems()
    }

    // MARK: - App 启动时调用
    func appDidLaunch() {
        truncateLogFile(v2rayLogFilePath)
        truncateLogFile(appLogFilePath)
        startHttpServer()
        Task { await V2rayTrafficStats.shared.initTask() }
        
        logger.info("appDidLaunch: mode=\(self.runMode.rawValue),v2rayTurnOn=\(self.v2rayTurnOn.description)")

        if v2rayTurnOn {
            setCoreRunning(true)
        }
        StatusItemManager.shared.refreshBasicMenus()
        Task {
            if AppSettings.shared.autoUpdateServers {
                await SubscriptionHandler.shared.sync()
            }
        }
    }

    // MARK: - 菜单栏 Toggle
    func toggleCore() {
        v2rayTurnOn = !v2rayTurnOn
        setCoreRunning(v2rayTurnOn)
        StatusItemManager.shared.refreshBasicMenus()
    }
    
    func turnOnCore() {
        v2rayTurnOn = true
        v2rayTurnOn = true
        setCoreRunning(v2rayTurnOn)
        StatusItemManager.shared.refreshBasicMenus()
    }
    
    func turnOffCore() {
        v2rayTurnOn = false
        setCoreRunning(v2rayTurnOn)
        StatusItemManager.shared.refreshBasicMenus()
    }
}
