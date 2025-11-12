import ServiceManagement
import SwiftUI

// app 设置项
enum Theme: String, CaseIterable {
    case System = "FollowSystem"
    case Light
    case Dark
    var localized: String {
        return NSLocalizedString(rawValue, comment: "")
    }
}

@MainActor
final class AppSettings: ObservableObject {
    static var shared = AppSettings()
    var lock = NSLock()
    
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
    @Published var socksPort: Int = Int(getSocksProxyPort())
    @Published var httpPort: Int = Int(getHttpProxyPort())
    @Published var pacPort: Int = Int(getPacPort())
    @Published var allowLAN: Bool = UserDefaults.getBool(forKey: .allowLAN)
    @Published var enableUdp: Bool = UserDefaults.getBool(forKey: .enableUdp)
    @Published var enableSniffing: Bool = UserDefaults.getBool(forKey: .enableSniffing)
    @Published var enableMux: Bool = UserDefaults.getBool(forKey: .enableMux)
    @Published var mux: Int = UserDefaults.getInt(forKey: .muxConcurrent, defaultValue: 8)
    @Published var enableStat: Bool = UserDefaults.getBool(forKey: .enableStat)
    @Published var logLevel: V2rayLogLevel = UserDefaults.getEnum(forKey: .v2rayLogLevel, type: V2rayLogLevel.self, defaultValue: .info)
    @Published var dnsJson = UserDefaults.get(forKey: .dnsServers, defaultValue: defaultDns)
    @Published var gfwPacListUrl: String = UserDefaults.get(forKey: .gfwPacListUrl, defaultValue: GFWListURL)
    @Published var pingURL: URL = URL(string: "http://www.gstatic.com/generate_204")!
    
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
        logger.info("setAppearance: \(theme.rawValue)-\(theme.localized)")
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
        lock.lock()
        defer { lock.unlock() }
        AppSettings.shared = AppSettings()
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
        lock.lock()
        defer { self.lock.unlock() }
        // 保存到UserDefaults
        UserDefaults.setBool(forKey: .autoCheckVersion, value: checkForUpdates)
        UserDefaults.setBool(forKey: .autoUpdateServers, value: autoUpdateServers)
        UserDefaults.setBool(forKey: .autoSelectFastestServer, value: selectFastestServer)
        UserDefaults.setBool(forKey: .showSpeedOnTray, value: showSpeedOnTray)
        UserDefaults.setBool(forKey: .showLatencyOnTray, value: showLatencyOnTray)
        UserDefaults.setBool(forKey: .enableStat, value: enableStat)
        UserDefaults.setInt(forKey: .localSockPort, value: socksPort)
        UserDefaults.setInt(forKey: .localHttpPort, value: httpPort)
        UserDefaults.setInt(forKey: .localPacPort, value: pacPort)
        UserDefaults.setBool(forKey: .allowLAN, value: allowLAN)
        UserDefaults.setBool(forKey: .enableUdp, value: enableUdp)
        UserDefaults.setBool(forKey: .enableSniffing, value: enableSniffing)
        UserDefaults.setBool(forKey: .enableMux, value: enableMux)
        UserDefaults.setInt(forKey: .muxConcurrent, value: mux)
        UserDefaults.set(forKey: .v2rayLogLevel, value: logLevel.rawValue)
        UserDefaults.set(forKey: .dnsServers, value: dnsJson)
        UserDefaults.set(forKey: .gfwPacListUrl, value: gfwPacListUrl)
    }

    func handleChange(old: AppSettings) {
        // 处理设置变更逻辑
        var needRestartV2ray = false
        // 需要重启v2ray的情况
        if old.httpPort != httpPort ||
            old.socksPort != socksPort ||
            old.allowLAN != allowLAN ||
            old.enableUdp != enableUdp ||
            old.enableSniffing != enableSniffing ||
            old.enableMux != enableMux ||
            old.mux != mux ||
            old.enableStat != enableStat ||
            old.logLevel != logLevel ||
            old.dnsJson != dnsJson {
            needRestartV2ray = true
        }
        // 需要重新生成PAC文件的情况
        let needGeneratePAC = old.socksPort != socksPort || old.allowLAN != allowLAN || old.gfwPacListUrl != gfwPacListUrl
        // pac端口改变后, 需要重启HTTP服务器
        let needRestartHttpServer = pacPort != old.pacPort
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
}
