import Combine
import SwiftUI
import ServiceManagement

enum RunMode: String, CaseIterable {
    case global
    case off
    case manual
    case tunnel

    var icon: String {
        switch self {
        case .global:
            return "IconOn"
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

    // 设置相关属性
    var settings = AppSettings()

    // 其它非设置相关属性
    @Published var pingURL: URL = URL(string: "http://www.gstatic.com/generate_204")!
    @Published var icon: String = "IconOff"
    @Published var v2rayTurnOn = UserDefaults.getBool(forKey: .v2rayTurnOn)
    @Published var runMode: RunMode = UserDefaults.getEnum(forKey: .runMode, type: RunMode.self, defaultValue: .off)
    @Published var runningProfile: String = UserDefaults.get(forKey: .runningProfile, defaultValue: "")
    @Published var runningRouting: String = UserDefaults.get(forKey: .runningRouting, defaultValue: "")
    @Published var runningServer: ProfileModel? = ProfileViewModel.getRunning()
    @Published var dnsJson = UserDefaults.get(forKey: .dnsServers, defaultValue: defaultDns)

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
        $gfwPacListUrl
            .sink { url in
                UserDefaults.set(forKey: .gfwPacListUrl, value: url)
            }
            .store(in: &cancellables)
        $dnsJson
            .sink { json in
                UserDefaults.set(forKey: .v2rayDnsJson, value: json)
            }
            .store(in: &cancellables)
    }

    func setRunMode(mode: RunMode) {
        NSLog("setRunMode: \(mode)")
        self.runMode = mode
        self.icon = mode.icon // 更新图标
    }
    
    func setRunning(uuid: String) {
        print("setRunning: \(uuid)")
        self.runningProfile = uuid
        self.runMode = .global
        self.icon = RunMode.global.icon // 更新图标
        UserDefaults.set(forKey: .runningProfile, value: uuid)
    }
    
    func runMode(mode: RunMode) {
        UserDefaults.set(forKey: .runMode, value: mode.rawValue)
        self.runMode = mode
        V2rayLaunch.startV2rayCore()
    }
    
    func runRouting(uuid: String) {
        UserDefaults.set(forKey: .runningRouting, value: uuid)
        self.runningRouting = uuid
        V2rayLaunch.startV2rayCore()
    }
    
    func runProfile(uuid: String) {
        UserDefaults.set(forKey: .runningProfile, value: uuid)
        self.runningProfile = uuid
        self.runningServer = ProfileViewModel.getRunning()
        V2rayLaunch.startV2rayCore()
    }
    
    func setSpeed(latency: Double, directUpSpeed: Double, directDownSpeed: Double, proxyUpSpeed: Double, proxyDownSpeed: Double) {
        self.latency = latency
        self.directUpSpeed = directUpSpeed
        self.directDownSpeed = directDownSpeed
        self.proxyUpSpeed = proxyUpSpeed
        self.proxyDownSpeed = proxyDownSpeed
    }
}
