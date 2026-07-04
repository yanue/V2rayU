import SwiftUI
import OSLog
import KeyboardShortcuts

import FirebaseCore
import AppCenterAnalytics
import AppCenterCrashes

let AppResourcesPath = Bundle.main.bundlePath + "/Contents/Resources"
let AppHomePath = NSHomeDirectory() + "/.V2rayU"
let databasePath = NSHomeDirectory() + "/.V2rayU/.V2rayU.db"
// 系统级目录：存放需要 root 权限的二进制和工具（与用户数据分离）
let AppBinRoot = "/usr/local/v2rayu"
let v2rayUTool = AppBinRoot + "/V2rayUTool"
let appLogFilePath = AppHomePath + "/V2rayU.log"
let JsonConfigFilePath = AppHomePath + "/config.json"
let TunConfigFilePath = AppHomePath + "/tun.json"
let defaultCapabilityRulesBaseURL = "https://raw.githubusercontent.com/yanue/V2rayU/main/Build/capability-rules"
let coreApiPort = "11111"
let coreApiBaseUrl = "http://127.0.0.1:\(coreApiPort)"
let userHomeDirectory = FileManager.default.homeDirectoryForCurrentUser.path
let logger = Logger(subsystem: "net.yanue.V2rayU", category: "app")
let uiLogger = Logger(subsystem: "net.yanue.V2rayU", category: "ui")
let appVersion = getAppVersion()
let coreVersion = getCoreShortVersion()
let osVersion = ProcessInfo.processInfo.operatingSystemVersionString
let langStr = Locale.current.identifier
let isMainland = langStr == "zh-CN" || langStr == "zh" || langStr == "zh-Hans" || langStr == "zh-Hant"
let coreLogFilePath = AppHomePath + "/core.log"
// tun.log 也放在用户目录下，root daemon 以 root 运行同样可以写入用户目录
// 避免 /var/log 下的权限问题导致 App 无法读取日志
let tunLogFilePath = AppHomePath + "/tun.log"
let runTunLogFilePath = AppHomePath + "/run-tun.log"
let xrayCorePath = AppBinRoot + "/bin/xray-core"
let singboxRuleSetPath = AppBinRoot + "/bin/sing-box/rule-set"
let singboxBundledRuleSetFiles = [
    "geosite-category-ads-all.srs",
    "geosite-cn.srs",
    "geosite-geolocation-!cn.srs",
    "geoip-cn.srs",
]
#if arch(arm64)
let xrayCoreFile = xrayCorePath + "/xray-arm64"
#else
let xrayCoreFile = xrayCorePath + "/xray-64"
#endif

/// Mark - 入口
@main
struct V2rayUApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // 必须设置 settings, 不然无法输入框复制粘贴
        Settings {
            SettingView()
                .environment(\.locale, LanguageManager.shared.currentLocale)
        }
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button {
                    let year = Calendar.current.component(.year, from: Date())
                    let copyright = "© 2018-\(year) V2rayU. All rights reserved."
                    NSApplication.shared.orderFrontStandardAboutPanel(options: [
                        .credits: NSAttributedString(string: copyright)
                    ])
                } label: {
                    Text("About V2rayU")
                }
            }
        }
    }
}

/// AppDelegate - 应用
class AppDelegate: NSObject, NSApplicationDelegate {
    private var isTerminating = false

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        logger.info("Application did finish launching.")
        FirebaseCore.FirebaseApp.configure()
        AppCenter.start(withAppSecret: "d52dd1a1-7a3a-4143-b159-a30434f87713", services:[
          Analytics.self,
          Crashes.self
        ])
        // 初始化状态栏项目
        AppMenuManager.shared.setupStatusItem()
        Task{
            // 初始化helper（创建目录、修权限等）
            await AppInstaller.shared.checkInstall()
            // 初始化睡眠管理器
            await SystemSleepManager.shared.setup()
            // 初始化网络变化监听(切换 Wi-Fi/网络中断恢复时自动重建 TUN)
            await NetworkMonitor.shared.start()
            // 启动设置(内部会初始化默认路由、同步状态并一次性刷新所有菜单)
             await AppState.shared.appDidLaunch()

            // 检查并迁移旧版数据（首次启动时）
            _ = await LegacyMigrationHandler.shared.checkAndPromptForMigration()
        }
    }

    // 日志重定向，建议在 App 启动时调用
     static func redirectStdoutToFile() {
         freopen(appLogFilePath, "a+", stdout)
         freopen(appLogFilePath, "a+", stderr)
     }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        logger.info("applicationShouldTerminate")

        guard !isTerminating else {
            return .terminateNow
        }
        isTerminating = true

        // 停止所有快捷键监听
        KeyboardShortcuts.removeAllHandlers()

        // 停止 V2ray / TUN helper 后再允许退出，避免 root tun-helper 残留导致系统路由黑洞
        Task {
            // 停机会把 v2rayTurnOn 设为 false 并写入 UserDefaults，
            // 提前保存原值，停止后恢复，确保下次启动能正确读取。
            let wasRunning = await MainActor.run { AppState.shared.v2rayTurnOn }
            await V2rayLaunch.shared.stop()
            if wasRunning {
                await MainActor.run { AppState.shared.v2rayTurnOn = true }
            }
            // 终止 V2ray 进程
            killSelfV2ray()
            logger.info("applicationShouldTerminate end")
            NSApp.reply(toApplicationShouldTerminate: true)
        }

        return .terminateLater
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        logger.info("Application will terminate.")
        Task {
            await LocalHttpServer.shared.stop()
        }
    }
}
