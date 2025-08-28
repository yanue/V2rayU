import Combine
import SwiftUI

enum RunMode: String, CaseIterable {
    case global
    case off
    case pac
    case manual
    case tunnel

    var icon: String {
        switch self {
        case .global:
            return "IconOn"
        case .pac:
            return "IconM"
        case .off:
            return "IconOff"
        case .manual:
            return "IconM"
        case .tunnel:
            return "IconT"
        }
    }

    var isEnabled: Bool {
        switch self {
        case .off, .tunnel: return false
        default: return true
        }
    }
}

@MainActor
final class AppState: ObservableObject {
    static let shared = AppState() // 单例实例
    
    @Published var mainTab: ContentView.Tab = .activity
    @Published var settingTab: SettingView.SettingTab = .general

    // 其它非设置相关属性
    @Published var icon: String = "IconOff"
    @Published var v2rayTurnOn = UserDefaults.getBool(forKey: .v2rayTurnOn)
    @Published var runMode: RunMode = UserDefaults.getEnum(forKey: .runMode, type: RunMode.self, defaultValue: .off)
    @Published var runningProfile: String = UserDefaults.get(forKey: .runningProfile, defaultValue: "")
    @Published var runningRouting: String = UserDefaults.get(forKey: .runningRouting, defaultValue: "")
    @Published var runningServer: ProfileModel? = ProfileViewModel.getRunning()

    // 其它统计属性
    @Published var latency = 0.0
    @Published var directUpSpeed = 0.0
    @Published var directDownSpeed = 0.0
    @Published var proxyUpSpeed = 0.0
    @Published var proxyDownSpeed = 0.0

    @StateObject var viewModel = ProfileViewModel()
    private var cancellables = Set<AnyCancellable>()

    init() {
        setupBindings()
    }

    private func setupBindings() {
        $runMode
            .sink { mode in
                UserDefaults.set(forKey: .runMode, value: mode.rawValue)
            }
            .store(in: &cancellables)
        $runningProfile
            .sink { uuid in
                UserDefaults.set(forKey: .runningProfile, value: uuid)
            }
            .store(in: &cancellables)
        $runningRouting
            .sink { uuid in
                UserDefaults.set(forKey: .runningRouting, value: uuid)
            }
            .store(in: &cancellables)
    }

    func setRunning(uuid: String) {
        logger.info("setRunning: \(uuid)")
        runningProfile = uuid
        UserDefaults.set(forKey: .runningProfile, value: uuid)
        StatusItemManager.shared.refreshMenuItems()
    }
    
    func switchRunMode(mode: RunMode) {
        runMode = mode
        icon = mode.icon  // 更新图标
        reloadCore(trigger: "setRunMode(\(mode))")
    }
    
    func turnOnCore() {
        if !v2rayTurnOn {
            v2rayTurnOn = true
            UserDefaults.setBool(forKey: .v2rayTurnOn, value: true)
        }
        reloadCore(trigger: "turnOn")
    }
    
    func turnOffCore() {
        if v2rayTurnOn {
            v2rayTurnOn = false
            UserDefaults.setBool(forKey: .v2rayTurnOn, value: false)
        }
        V2rayLaunch.stopV2rayCore()
    }

    func runRouting(uuid: String) {
        logger.info("setRouting: \(uuid)")
        runningRouting = uuid
        reloadCore(trigger: "runRouting(\(uuid))")
    }

    func runProfile(uuid: String) {
        logger.info("setProfile: \(uuid)")
        runningProfile = uuid
        runningServer = ProfileViewModel.getRunning()
        reloadCore(trigger: "runProfile(\(uuid))")
    }

    func setSpeed(latency: Double, directUpSpeed: Double, directDownSpeed: Double, proxyUpSpeed: Double, proxyDownSpeed: Double) {
        self.latency = latency
        self.directUpSpeed = directUpSpeed
        self.directDownSpeed = directDownSpeed
        self.proxyUpSpeed = proxyUpSpeed
        self.proxyDownSpeed = proxyDownSpeed
    }
}

extension AppState {
    /// 修改了配置后，统一调用该方法来刷新 v2ray-core
    func reloadCore(trigger: String) {
        if !v2rayTurnOn {
            return
        }
        Task {
            let success = await V2rayLaunch.startV2rayCore()
            if !success {
                switchRunMode(mode: .off)
            }
            logger.info("reloadCore triggered by: \(trigger)")
            StatusItemManager.shared.refreshMenuItems()
        }
    }

    func appDidLaunch() {
        // 清理日志
        truncateLogFile(v2rayLogFilePath)
        truncateLogFile(appLogFilePath)
        // 初始化依赖
        // start http server
        startHttpServer()
        Task {
            await V2rayTrafficStats.shared.initTask()
        }
        // 根据状态判断是否启动
        if v2rayTurnOn {
            reloadCore(trigger: "appDidLaunch with v2rayTurnOn")
        }
        // 自动更新订阅
        Task {
            if AppSettings.shared.autoUpdateServers {
                await SubscriptionHandler.shared.sync()
            }
        }
    }

    func ToggleRunning() {
        v2rayTurnOn.toggle()
        if v2rayTurnOn {
            reloadCore(trigger: "toggleRunning on")
        } else {
            V2rayLaunch.stopV2rayCore()
            switchRunMode(mode: .off)
        }
    }
}
