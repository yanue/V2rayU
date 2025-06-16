import Combine
import SwiftUI

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

    @Published var pingURL: URL = URL(string: "http://www.gstatic.com/generate_204")!
    
    @Published var icon: String = "IconOff" // 默认图标

    @Published var v2rayTurnOn = true // 是否开启v2ray
    @Published var runMode: RunMode = .off // 运行模式
    @Published var runningProfile: String = "" // 当前运行的配置
    @Published var runningRouting: String = "" // 当前运行的路由

    @Published var launchAtLogin: Bool = true
    @Published var checkForUpdates: Bool = true
    @Published var autoUpdateServers: Bool = true
    @Published var selectFastestServer: Bool = true
    @Published var enableStat = true

    @Published var logLevel = V2rayLogLevel.info
    @Published var socksPort = 1080
    @Published var socksHost = "127.0.0.1"
    @Published var httpPort = 1087
    @Published var httpHost = "127.0.0.1"
    @Published var enableUdp = false
    @Published var enableSniffing = true
    @Published var enableMux = false
    @Published var mux = 8
    @Published var dnsJson = ""
    
    @Published var latency = 0.0 // 网络延迟(ping值ms)
    @Published var directUpSpeed = 0.0
    @Published var directDownSpeed = 0.0
    @Published var proxyUpSpeed = 0.0
    @Published var proxyDownSpeed = 0.0
    
    @StateObject var viewModel = ProfileViewModel()

    private var cancellables = Set<AnyCancellable>()

    init() {
        runMode = UserDefaults.getEnum(forKey: .runMode, type: RunMode.self, defaultValue: .off)
        v2rayTurnOn = UserDefaults.getBool(forKey: .v2rayTurnOn)
        runningProfile = UserDefaults.get(forKey: .runningProfile, defaultValue: "")
        runningRouting = UserDefaults.get(forKey: .runningRouting, defaultValue: "")
        
        enableMux = UserDefaults.getBool(forKey: .enableMux)
        enableUdp = UserDefaults.getBool(forKey: .enableUdp)
        enableSniffing = UserDefaults.getBool(forKey: .enableSniffing)
        enableStat = UserDefaults.getBool(forKey: .enableStat)

        httpPort = UserDefaults.getInt(forKey: .localHttpPort, defaultValue: 1087)
        httpHost = UserDefaults.get(forKey: .localHttpHost, defaultValue: "127.0.0.1")
        socksPort = UserDefaults.getInt(forKey: .localSockPort, defaultValue: 1080)
        socksHost = UserDefaults.get(forKey: .localSockHost, defaultValue: "127.0.0.1")
        mux = UserDefaults.getInt(forKey: .muxConcurrent, defaultValue: 8)

        logLevel = UserDefaults.getEnum(forKey: .v2rayLogLevel, type: V2rayLogLevel.self, defaultValue: .info)

        launchAtLogin = UserDefaults.getBool(forKey: .autoLaunch)
        autoUpdateServers = UserDefaults.getBool(forKey: .autoUpdateServers)
        checkForUpdates = UserDefaults.getBool(forKey: .autoCheckVersion)
        selectFastestServer = UserDefaults.getBool(forKey: .autoSelectFastestServer)

        setupBindings()
    }

    private func setupBindings() {
        $runMode
            .sink { mode in
                UserDefaults.set(forKey: .runMode, value: mode.rawValue)
            }
            .store(in: &cancellables)

        $launchAtLogin
            .sink { launch in
                UserDefaults.setBool(forKey: .autoLaunch, value: launch)
            }
            .store(in: &cancellables)

        $autoUpdateServers
            .sink { _bool in
                UserDefaults.setBool(forKey: .autoUpdateServers, value: _bool)
            }
            .store(in: &cancellables)

        $checkForUpdates
            .sink { _bool in
                UserDefaults.setBool(forKey: .autoCheckVersion, value: _bool)
            }
            .store(in: &cancellables)

        $selectFastestServer
            .sink { _bool in
                UserDefaults.setBool(forKey: .autoSelectFastestServer, value: _bool)
            }
            .store(in: &cancellables)

        $logLevel
            .sink { level in
                UserDefaults.set(forKey: .v2rayLogLevel, value: level.rawValue)
            }
            .store(in: &cancellables)

        $socksPort
            .sink { port in
                UserDefaults.setInt(forKey: .localSockPort, value: port)
            }
            .store(in: &cancellables)

        $socksHost
            .sink { host in
                UserDefaults.set(forKey: .localSockHost, value: host)
            }
            .store(in: &cancellables)

        $httpPort
            .sink { port in
                UserDefaults.setInt(forKey: .localHttpPort, value: port)
            }
            .store(in: &cancellables)

        $httpHost
            .sink { host in
                UserDefaults.set(forKey: .localHttpHost, value: host)
            }
            .store(in: &cancellables)

        $enableMux
            .sink { enabled in
                UserDefaults.setBool(forKey: .enableMux, value: enabled)
            }
            .store(in: &cancellables)

        $enableUdp
            .sink { enabled in
                UserDefaults.setBool(forKey: .enableUdp, value: enabled)
            }
            .store(in: &cancellables)

        $enableSniffing
            .sink { enabled in
                UserDefaults.setBool(forKey: .enableSniffing, value: enabled)
            }
            .store(in: &cancellables)

        $mux
            .sink { value in
                UserDefaults.set(forKey: .muxConcurrent, value: "\(value)")
            }
            .store(in: &cancellables)

        $dnsJson
            .sink { json in
                UserDefaults.set(forKey: .v2rayDnsJson, value: json)
            }
            .store(in: &cancellables)

        $enableStat
            .sink { enabled in
                UserDefaults.setBool(forKey: .enableStat, value: enabled)
            }
            .store(in: &cancellables)
    }

    func setRunMode(mode: RunMode) {
        NSLog("setRunMode: \(mode)")
        self.runMode = mode
        self.icon = mode.icon // 更新图标
    }
    
    func setRunning(profile: String, mode: RunMode) {
        self.runMode = mode
        self.icon = mode.icon
        self.runningProfile = profile
        UserDefaults.set(forKey: .runningProfile, value: profile)
        UserDefaults.set(forKey: .runMode, value: mode.rawValue)
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
