import SwiftUI

// app 设置项

final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @Published var launchAtLogin: Bool = SMAppService.mainApp.status == .enabled
    @Published var checkForUpdates: Bool = UserDefaults.getBool(forKey: .autoCheckVersion)
    @Published var autoUpdateServers: Bool = UserDefaults.getBool(forKey: .autoUpdateServers)
    @Published var selectFastestServer: Bool = UserDefaults.getBool(forKey: .autoSelectFastestServer)
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

    func saveSettings() {
        // 主线程异步执行，确保 UI 更新
        DispatchQueue.main.async {
            // 先保存旧值
            let old = AppSettings() // 这里会从UserDefaults读取

            // 注册或注销登录项
            do {
                if !self.launchAtLogin && SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
                if self.launchAtLogin && SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } catch {
                Swift.print(error.localizedDescription)
            }

            // 保存到UserDefaults
            UserDefaults.setBool(forKey: .autoCheckVersion, value: checkForUpdates)
            UserDefaults.setBool(forKey: .autoUpdateServers, value: autoUpdateServers)
            UserDefaults.setBool(forKey: .autoSelectFastestServer, value: selectFastestServer)
            UserDefaults.setInt(forKey: .localSockPort, value: socksPort)
            UserDefaults.setInt(forKey: .localHttpPort, value: httpPort)
            UserDefaults.setInt(forKey: .localPacPort, value: pacPort)
            UserDefaults.setBool(forKey: .allowLAN, value: allowLAN)
            UserDefaults.setBool(forKey: .enableUdp, value: enableUdp)
            UserDefaults.setBool(forKey: .enableSniffing, value: enableSniffing)
            UserDefaults.setBool(forKey: .enableMux, value: enableMux)
            UserDefaults.setInt(forKey: .muxConcurrent, value: mux)
            UserDefaults.setBool(forKey: .enableStat, value: enableStat)
            UserDefaults.set(forKey: .v2rayLogLevel, value: logLevel.rawValue)

            // 处理设置变更
            handleChange(old: old)
        }
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
            old.logLevel != logLevel {
            needRestartV2ray = true
        }
        // socks断开或allowLan改变后, 需要重新生成PAC文件
        let needGeneratePAC = old.socksPort != socksPort || old.allowLAN != allowLAN
        // pac端口改变后, 需要重启HTTP服务器
        let needRestartHttpServer = pacPort != old.pacPort
        if needGeneratePAC {
            GeneratePACFile()
        }
        if needRestartV2ray {
            V2rayLaunch.restartV2ray()
        }
        if needRestartHttpServer {
            Task {
                await LocalHttpServer.shared.restart()
            }
        }
    }
}