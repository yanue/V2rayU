import SwiftUI
import Combine

enum RunMode: String {
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
}

@MainActor
final class AppState: ObservableObject {
    static let shared = AppState() // 单例实例

    @Published var pingURL: URL = URL(string: "http://www.gstatic.com/generate_204")!
    
    @Published var runMode: RunMode = .off
    
    @Published var launchAtLogin: Bool = true
    @Published var checkForUpdates: Bool = true
    @Published var autoUpdateServers: Bool = true
    @Published var selectFastestServer: Bool = true
    @Published var enableStat = true

    @Published var logLevel = V2rayLog.logLevel.info
    @Published var socksPort = 1080
    @Published var socksHost = "127.0.0.1"
    @Published var httpPort = 1087
    @Published var httpHost = "127.0.0.1"
    @Published var enableUdp = false
    @Published var enableSniffing = true
    @Published var enableMux = false
    @Published var mux = 8
    @Published var dnsJson = ""
    
    private var cancellables = Set<AnyCancellable>()

    init() {
        self.runMode = UserDefaults.getEnum(forKey: .runMode, type: RunMode.self, defaultValue: .off)
        self.enableMux = UserDefaults.getBool(forKey: .enableMux)
        self.enableUdp = UserDefaults.getBool(forKey: .enableUdp)
        self.enableSniffing = UserDefaults.getBool(forKey: .enableSniffing)
        self.enableStat = UserDefaults.getBool(forKey: .enableStat)

        self.httpPort = UserDefaults.getInt(forKey: .localHttpPort, defaultValue: 1087)
        self.httpHost = UserDefaults.get(forKey: .localHttpHost, defaultValue: "127.0.0.1")
        self.socksPort = UserDefaults.getInt(forKey: .localSockPort,defaultValue: 1080)
        self.socksHost = UserDefaults.get(forKey: .localSockHost, defaultValue: "127.0.0.1")
        self.mux = UserDefaults.getInt(forKey: .muxConcurrent, defaultValue: 8)

        self.logLevel = UserDefaults.getEnum(forKey: .v2rayLogLevel, type: V2rayLog.logLevel.self, defaultValue: .info)

        self.launchAtLogin = UserDefaults.getBool(forKey: .autoLaunch)
        self.autoUpdateServers = UserDefaults.getBool(forKey: .autoUpdateServers)
        self.checkForUpdates = UserDefaults.getBool(forKey: .autoCheckVersion)
        self.selectFastestServer = UserDefaults.getBool(forKey: .autoSelectFastestServer)
        print("AppState init", self.launchAtLogin, self.autoUpdateServers, self.checkForUpdates, self.selectFastestServer)
        
        self.setupBindings()
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
                UserDefaults.set(forKey: .v2rayLogLevel, value: level)
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
    }

    
    func setRunMode(mode: RunMode) async {
        self.runMode = mode
    }

}
