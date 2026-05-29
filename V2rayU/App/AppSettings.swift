import ServiceManagement
import SwiftUI

let defaultLatencyTestConcurrency = 5
let defaultLatencyTestTimeout = 5
// 选用 gstatic 的原因:
// 1) 始终直接返回 204, 不会 301/302
// 2) HTTP 即可, 避免 TLS 握手把延迟数字撑大
// 3) 国内代理出口后访问普遍稳定
let defaultPingTestURL = "http://www.gstatic.com/generate_204"
let defaultUDPTestURL = "ntp.pool.ntp.org"
let defaultCurrentConnectionTestURL = ""

// app 设置项
enum Theme: String, CaseIterable {
    case System = "FollowSystem"
    case Light
    case Dark
}

@MainActor
final class AppSettings: ObservableObject {
    static var shared = AppSettings()

    @Published var selectedTheme: Theme {
        didSet {
            setAppearance(selectedTheme)
        }
    }
    
    @Published var launchAtLogin: Bool = SMAppService.mainApp.status == .enabled
    @Published var checkForUpdates: Bool = UserDefaults.getBool(forKey: .autoCheckVersion)
    @Published var autoUpdateServers: Bool = UserDefaults.getBool(forKey: .autoUpdateServers)
    @Published var selectFastestServer: Bool = UserDefaults.getBool(forKey: .autoSelectFastestServer)
    @Published var showSpeedOnTray: Bool = UserDefaults.getBool(forKey: .showSpeedOnTray)
    @Published var showLatencyOnTray: Bool = UserDefaults.getBool(forKey: .showLatencyOnTray)
    @Published var showCountryFlag: Bool = UserDefaults.getBool(forKey: .showCountryFlag, default: true)
    @Published var socksPort: Int = Int(getSocksProxyPort())
    @Published var httpPort: Int = Int(getHttpProxyPort())
    @Published var enableMixedPort: Bool = UserDefaults.getBool(forKey: .enableMixedPort)
    @Published var mixedPort: Int = UserDefaults.getInt(forKey: .mixedPort, defaultValue: Int(getSocksProxyPort()))
    @Published var pacPort: Int = Int(getPacPort())
    @Published var allowLAN: Bool = UserDefaults.getBool(forKey: .allowLAN)
    @Published var enableUdp: Bool = UserDefaults.getBool(forKey: .enableUdp)
    @Published var enableSniffing: Bool = UserDefaults.getBool(forKey: .enableSniffing)
    @Published var enableMux: Bool = UserDefaults.getBool(forKey: .enableMux)
    @Published var mux: Int = UserDefaults.getInt(forKey: .muxConcurrent, defaultValue: 8)
    @Published var enableStat: Bool = UserDefaults.getBool(forKey: .enableStat)
    @Published var logLevel: V2rayLogLevel = UserDefaults.getEnum(forKey: .v2rayLogLevel, type: V2rayLogLevel.self, defaultValue: .info)
    @Published var dnsJson = getDefaultDnsSetting()
    @Published var dnsJsonSingbox: String = UserDefaults.get(forKey: .dnsJsonSingbox, defaultValue: defaultSingboxDns)
    @Published var gfwPacListUrl: String = UserDefaults.get(forKey: .gfwPacListUrl, defaultValue: GFWListURL)
    @Published var latencyTestConcurrency: Int = UserDefaults.getInt(forKey: .latencyTestConcurrency, defaultValue: defaultLatencyTestConcurrency)
    @Published var pingTestURL: String = UserDefaults.get(forKey: .pingTestURL, defaultValue: defaultPingTestURL)
    @Published var udpTestURL: String = UserDefaults.get(forKey: .udpTestURL, defaultValue: defaultUDPTestURL)
    @Published var currentConnectionTestURL: String = UserDefaults.get(forKey: .currentConnectionTestURL, defaultValue: defaultCurrentConnectionTestURL)

    var pingURL: URL {
        URL(string: pingTestURL) ?? URL(string: defaultPingTestURL) ?? URL(fileURLWithPath: "/")
    }

    var safeLatencyTestConcurrency: Int {
        min(max(latencyTestConcurrency, 1), 20)
    }

    // MARK: - TUN settings
    @Published var tunAddress: String = UserDefaults.get(forKey: .tunAddress, defaultValue: "10.0.0.1/30")
    @Published var tunMtu: Int = UserDefaults.getInt(forKey: .tunMtu, defaultValue: 1500)
    @Published var tunStack: TunStack = UserDefaults.getEnum(forKey: .tunStack, type: TunStack.self, defaultValue: .system)
    @Published var tunDnsDefault: String = UserDefaults.get(forKey: .tunDnsDefault, defaultValue: defaultDomesticDns)
    @Published var tunDnsChina: String = UserDefaults.get(forKey: .tunDnsChina, defaultValue: secondaryDomesticDns)
    @Published var tunFakeipRange: String = UserDefaults.get(forKey: .tunFakeipRange, defaultValue: "198.18.0.0/15")
    // strict_route: 强制路由, 默认开启
    @Published var tunStrictRoute: Bool = UserDefaults.getBool(forKey: .tunStrictRoute, default: true)
    // 网络变化/唤醒后自动重建 TUN, 默认开启
    @Published var tunAutoRebuild: Bool = UserDefaults.getBool(forKey: .tunAutoRebuild, default: true)

    init() {
        if let savedTheme = UserDefaults.standard.string(forKey: "AppleThemes"),
           let theme = Theme(rawValue: savedTheme) {
            selectedTheme = theme
        } else {
            selectedTheme = .System
        }
        // 初始化应用外观,等待主线程完成后再执行
        DispatchQueue.main.async {
            self.setAppearance(self.selectedTheme)
        }
    }

    // 更新应用外观的方法
    private func setAppearance(_ theme: Theme) {
        logger.info("setAppearance: \(theme.rawValue)")
        // 保存主题设置
        UserDefaults.standard.set(theme.rawValue, forKey: "AppleThemes")
        // 刷新应用外观
        if #available(macOS 10.14, *) {
            switch theme {
            case .Light:
                // 浅色模式
                NSApp.appearance = NSAppearance(named: .aqua)
            case .Dark:
                // 深色模式
                NSApp.appearance = NSAppearance(named: .darkAqua)
            default:
                // 系统默认模式
                NSApp.appearance = nil
            }
        }
    }
    
    func reload() {
        // 从 UserDefaults 重新读取所有设置到当前实例（保持 UI 绑定有效）
        checkForUpdates = UserDefaults.getBool(forKey: .autoCheckVersion)
        autoUpdateServers = UserDefaults.getBool(forKey: .autoUpdateServers)
        selectFastestServer = UserDefaults.getBool(forKey: .autoSelectFastestServer)
        showSpeedOnTray = UserDefaults.getBool(forKey: .showSpeedOnTray)
        showLatencyOnTray = UserDefaults.getBool(forKey: .showLatencyOnTray)
        showCountryFlag = UserDefaults.getBool(forKey: .showCountryFlag, default: true)
        socksPort = Int(getSocksProxyPort())
        httpPort = Int(getHttpProxyPort())
        enableMixedPort = UserDefaults.getBool(forKey: .enableMixedPort)
        mixedPort = UserDefaults.getInt(forKey: .mixedPort, defaultValue: Int(getSocksProxyPort()))
        pacPort = Int(getPacPort())
        allowLAN = UserDefaults.getBool(forKey: .allowLAN)
        enableUdp = UserDefaults.getBool(forKey: .enableUdp)
        enableSniffing = UserDefaults.getBool(forKey: .enableSniffing)
        enableMux = UserDefaults.getBool(forKey: .enableMux)
        mux = UserDefaults.getInt(forKey: .muxConcurrent, defaultValue: 8)
        enableStat = UserDefaults.getBool(forKey: .enableStat)
        logLevel = UserDefaults.getEnum(forKey: .v2rayLogLevel, type: V2rayLogLevel.self, defaultValue: .info)
        dnsJson = getDefaultDnsSetting()
        dnsJsonSingbox = UserDefaults.get(forKey: .dnsJsonSingbox, defaultValue: defaultSingboxDns)
        gfwPacListUrl = UserDefaults.get(forKey: .gfwPacListUrl, defaultValue: GFWListURL)
        latencyTestConcurrency = UserDefaults.getInt(forKey: .latencyTestConcurrency, defaultValue: defaultLatencyTestConcurrency)
        pingTestURL = UserDefaults.get(forKey: .pingTestURL, defaultValue: defaultPingTestURL)
        udpTestURL = UserDefaults.get(forKey: .udpTestURL, defaultValue: defaultUDPTestURL)
        currentConnectionTestURL = UserDefaults.get(forKey: .currentConnectionTestURL, defaultValue: defaultCurrentConnectionTestURL)
        launchAtLogin = SMAppService.mainApp.status == .enabled
        tunAddress = UserDefaults.get(forKey: .tunAddress, defaultValue: "10.0.0.1/30")
        tunMtu = UserDefaults.getInt(forKey: .tunMtu, defaultValue: 1500)
        tunStack = UserDefaults.getEnum(forKey: .tunStack, type: TunStack.self, defaultValue: .system)
        tunDnsDefault = UserDefaults.get(forKey: .tunDnsDefault, defaultValue: defaultDomesticDns)
        tunDnsChina = UserDefaults.get(forKey: .tunDnsChina, defaultValue: secondaryDomesticDns)
        tunFakeipRange = UserDefaults.get(forKey: .tunFakeipRange, defaultValue: "198.18.0.0/15")
        tunStrictRoute = UserDefaults.getBool(forKey: .tunStrictRoute, default: true)
        tunAutoRebuild = UserDefaults.getBool(forKey: .tunAutoRebuild, default: true)
    }

    func saveSettings() {
        // 主线程异步执行，确保 UI 更新
        DispatchQueue.main.async {
            // 注册或注销登录项
            do {
                if !self.launchAtLogin && SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
                if self.launchAtLogin && SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } catch {
                uiLogger.info("Failed to update launch at login setting: \(error.localizedDescription)")
            }

            // 先保存旧值
            let old = AppSettings() // 这里会从UserDefaults读取
            // 保存当前设置
            self._save()
            // 处理设置变更
            self.handleChange(old: old)
        }
    }

    func _save() {
        // 保存到UserDefaults
        UserDefaults.setBool(forKey: .autoCheckVersion, value: checkForUpdates)
        UserDefaults.setBool(forKey: .autoUpdateServers, value: autoUpdateServers)
        UserDefaults.setBool(forKey: .autoSelectFastestServer, value: selectFastestServer)
        UserDefaults.setBool(forKey: .showSpeedOnTray, value: showSpeedOnTray)
        UserDefaults.setBool(forKey: .showLatencyOnTray, value: showLatencyOnTray)
        UserDefaults.setBool(forKey: .showCountryFlag, value: showCountryFlag)
        UserDefaults.setBool(forKey: .enableStat, value: enableStat)
        UserDefaults.setInt(forKey: .localSockPort, value: socksPort)
        UserDefaults.setInt(forKey: .localHttpPort, value: httpPort)
        UserDefaults.setBool(forKey: .enableMixedPort, value: enableMixedPort)
        UserDefaults.setInt(forKey: .mixedPort, value: mixedPort)
        UserDefaults.setInt(forKey: .localPacPort, value: pacPort)
        UserDefaults.setBool(forKey: .allowLAN, value: allowLAN)
        UserDefaults.setBool(forKey: .enableUdp, value: enableUdp)
        UserDefaults.setBool(forKey: .enableSniffing, value: enableSniffing)
        UserDefaults.setBool(forKey: .enableMux, value: enableMux)
        UserDefaults.setInt(forKey: .muxConcurrent, value: mux)
        UserDefaults.set(forKey: .v2rayLogLevel, value: logLevel.rawValue)
        UserDefaults.set(forKey: .dnsServers, value: dnsJson)
        UserDefaults.set(forKey: .dnsJsonSingbox, value: dnsJsonSingbox)
        UserDefaults.set(forKey: .gfwPacListUrl, value: gfwPacListUrl)
        latencyTestConcurrency = safeLatencyTestConcurrency
        UserDefaults.setInt(forKey: .latencyTestConcurrency, value: latencyTestConcurrency)
        UserDefaults.set(forKey: .pingTestURL, value: pingTestURL)
        UserDefaults.set(forKey: .udpTestURL, value: udpTestURL)
        UserDefaults.set(forKey: .currentConnectionTestURL, value: currentConnectionTestURL)
        UserDefaults.set(forKey: .tunAddress, value: tunAddress)
        UserDefaults.setInt(forKey: .tunMtu, value: tunMtu)
        UserDefaults.set(forKey: .tunStack, value: tunStack.rawValue)
        UserDefaults.set(forKey: .tunDnsDefault, value: tunDnsDefault)
        UserDefaults.set(forKey: .tunDnsChina, value: tunDnsChina)
        UserDefaults.set(forKey: .tunFakeipRange, value: tunFakeipRange)
        UserDefaults.setBool(forKey: .tunStrictRoute, value: tunStrictRoute)
        UserDefaults.setBool(forKey: .tunAutoRebuild, value: tunAutoRebuild)
    }

    func handleChange(old: AppSettings) {
        // 处理设置变更逻辑
        var needRestartV2ray = false
        let oldEffectiveHttpPort = old.effectiveHttpPort
        let newEffectiveHttpPort = effectiveHttpPort
        let oldEffectiveSocksPort = old.effectiveSocksPort
        let newEffectiveSocksPort = effectiveSocksPort
        // 需要重启v2ray的情况
        if old.enableMixedPort != enableMixedPort ||
            oldEffectiveHttpPort != newEffectiveHttpPort ||
            oldEffectiveSocksPort != newEffectiveSocksPort ||
            old.allowLAN != allowLAN ||
            old.enableUdp != enableUdp ||
            old.enableSniffing != enableSniffing ||
            old.enableMux != enableMux ||
            old.mux != mux ||
            old.enableStat != enableStat ||
            old.logLevel != logLevel ||
            old.dnsJson != dnsJson ||
            old.dnsJsonSingbox != dnsJsonSingbox ||
            old.pingTestURL != pingTestURL ||
            old.tunAddress != tunAddress ||
            old.tunMtu != tunMtu ||
            old.tunStack != tunStack ||
            old.tunDnsDefault != tunDnsDefault ||
            old.tunDnsChina != tunDnsChina ||
            old.tunFakeipRange != tunFakeipRange ||
            old.tunStrictRoute != tunStrictRoute {
            needRestartV2ray = true
        }

        if old.showCountryFlag != showCountryFlag {
            Task { AppMenuManager.shared.refreshServerItems() }
        }
        // 需要重新生成PAC文件的情况
        let needGeneratePAC = oldEffectiveSocksPort != newEffectiveSocksPort || old.allowLAN != allowLAN || old.gfwPacListUrl != gfwPacListUrl
        // pac端口改变后, 需要重启HTTP服务器
        let needRestartHttpServer = pacPort != old.pacPort || old.allowLAN != allowLAN
        if needGeneratePAC {
            _ = GeneratePACFile(rewrite: true)
        }
        if needRestartV2ray {
            Task {
              await V2rayLaunch.shared.restart()
            }
        }
        if needRestartHttpServer {
            Task {
                await LocalHttpServer.shared.restart()
            }
        }
        if old.autoUpdateServers != autoUpdateServers {
            Task {
                await SubscriptionScheduler.shared.refreshAll()
            }
        }
    }

    var effectiveHttpPort: Int {
        effectivePort(enableMixedPort: enableMixedPort, mixedPort: mixedPort, fallbackPort: httpPort)
    }

    var effectiveSocksPort: Int {
        effectivePort(enableMixedPort: enableMixedPort, mixedPort: mixedPort, fallbackPort: socksPort)
    }

    private func effectivePort(enableMixedPort: Bool, mixedPort: Int, fallbackPort: Int) -> Int {
        if enableMixedPort, mixedPort > 0 {
            return mixedPort
        }
        return fallbackPort
    }
}
