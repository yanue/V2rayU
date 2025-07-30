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

    @Published var pingURL: URL = URL(string: "http://www.gstatic.com/generate_204")!
    
    @Published var icon: String = "IconOff" // 默认图标

    @Published var v2rayTurnOn = UserDefaults.getBool(forKey: .v2rayTurnOn) // 是否开启v2ray
    @Published var runMode: RunMode = UserDefaults.getEnum(forKey: .runMode, type: RunMode.self, defaultValue: .off) // 运行模式
    @Published var runningProfile: String = UserDefaults.get(forKey: .runningProfile, defaultValue: "") // 当前运行的配置
    @Published var runningRouting: String = UserDefaults.get(forKey: .runningRouting, defaultValue: "") // 当前运行的路由
    @Published var runningServer: ProfileModel? = ProfileViewModel.getRunning() // 当前运行的配置文件

    @Published var launchAtLogin: Bool = SMAppService.mainApp.status == .enabled // 开机自启动(macOS13以上)
    @Published var checkForUpdates: Bool = UserDefaults.getBool(forKey: .autoCheckVersion) // 是否自动检查更新
    @Published var autoUpdateServers: Bool = UserDefaults.getBool(forKey: .autoUpdateServers) // 是否自动更新服务器列表
    @Published var selectFastestServer: Bool = UserDefaults.getBool(forKey: .autoSelectFastestServer) // 是否自动选择最快服务器
    @Published var enableStat = UserDefaults.getBool(forKey: .enableStat) // 是否启用统计

    @Published var logLevel = UserDefaults.getEnum(forKey: .v2rayLogLevel, type: V2rayLogLevel.self, defaultValue: .info)
    @Published var socksPort =  Int(getSocksProxyPort())
    @Published var httpPort =  Int(getHttpProxyPort())
    @Published var pacPort =  Int(getPacPort())
    @Published var enableUdp = UserDefaults.getBool(forKey: .enableUdp) // 是否启用 UDP 转发
    @Published var enableSniffing = UserDefaults.getBool(forKey: .enableSniffing) // 是否启用 sniffing
    @Published var enableMux = UserDefaults.getBool(forKey: .enableMux) // 是否启用 Mux
    @Published var gfwPacListUrl = UserDefaults.get(forKey: .gfwPacListUrl, defaultValue: "https://raw.githubusercontent.com/yanue/V2rayU/master/gfwlist.txt") // GFW 列表 URL
    @Published var mux = UserDefaults.getInt(forKey: .muxConcurrent, defaultValue: 8)
    @Published var dnsJson = UserDefaults.get(forKey: .dnsServers, defaultValue: defaultDns) // DNS JSON
    @Published var allowLAN = UserDefaults.getBool(forKey: .allowLAN)  // 允许局域网访问

    @Published var latency = 0.0 // 网络延迟(ping值ms)
    @Published var directUpSpeed = 0.0
    @Published var directDownSpeed = 0.0
    @Published var proxyUpSpeed = 0.0
    @Published var proxyDownSpeed = 0.0
    
    @StateObject var viewModel = ProfileViewModel()

    private var cancellables = Set<AnyCancellable>()

    init() {
        // 启用自动绑定更新
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
        
        $launchAtLogin
            .sink { launch in
                UserDefaults.setBool(forKey: .autoLaunch, value: launch)
                debugPrint("设置开机自启", launch, SMAppService.mainApp.status == .enabled)
                do {
                    if SMAppService.mainApp.status == .enabled {
                        try SMAppService.mainApp.unregister()
                    } else {
                        try SMAppService.mainApp.register()
                    }
                } catch {
                    Swift.print(error.localizedDescription)
                }
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
                debugPrint("设置Socks端口", port)
                UserDefaults.setInt(forKey: .localSockPort, value: port)
                // 重启v2ray
                V2rayLaunch.restartV2ray()
            }
            .store(in: &cancellables)

        $httpPort
            .sink { port in
                debugPrint("设置HTTP端口", port)
                UserDefaults.setInt(forKey: .localHttpPort, value: port)
                // 重启v2ray
                V2rayLaunch.restartV2ray()
            }
            .store(in: &cancellables)

        $pacPort
            .sink { port in
                debugPrint("设置PAC端口", port)
                UserDefaults.setInt(forKey: .localPacPort, value: port)
                // 重启 http
                Task {
                    await LocalHttpServer.shared.restart()
                }
               }
            .store(in: &cancellables)
        
        $allowLAN
            .sink { enabled in
                debugPrint("设置允许局域网访问", enabled)
                UserDefaults.setBool(forKey: .allowLAN, value: enabled)
                // 重启 http
                Task {
                    await LocalHttpServer.shared.restart()
                }
                // 重启 v2ray
                V2rayLaunch.restartV2ray()
                // 重启 pac
                _ = GeneratePACFile(rewrite: true)
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
