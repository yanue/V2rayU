import SwiftData
import SwiftUI
import Foundation
import OSLog

import FirebaseCore
import AppCenterAnalytics
import AppCenterCrashes

let AppResourcesPath = Bundle.main.bundlePath + "/Contents/Resources"
let AppHomePath = NSHomeDirectory() + "/.V2rayU"
let databasePath = NSHomeDirectory() + "/.V2rayU/.V2rayU.db"
let v2rayUTool = AppHomePath + "/V2rayUTool"
let appLogFilePath = AppHomePath + "/V2rayU.log"
let JsonConfigFilePath = AppHomePath + "/config.json"
let userHomeDirectory = FileManager.default.homeDirectoryForCurrentUser.path
let logger = Logger(subsystem: "net.yanue.V2rayU", category: "app")
let uiLogger = Logger(subsystem: "net.yanue.V2rayU", category: "ui")
let appVersion = getAppVersion()
let coreVersion = getCoreShortVersion()
let osVersion = ProcessInfo.processInfo.operatingSystemVersionString
let langStr = Locale.current.identifier
let isMainland = langStr == "zh-CN" || langStr == "zh" || langStr == "zh-Hans" || langStr == "zh-Hant"
let coreLogFilePath = AppHomePath + "/xray-core.log"
let xrayCorePath = AppHomePath + "/bin/xray-core"
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
            EmptyView()
        }
    }
}

/// AppDelegate - 应用
class AppDelegate: NSObject, NSApplicationDelegate {
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
            // 初始化helper
            await AppInstaller.shared.checkInstall()
            // 初始化睡眠管理器
            await SystemSleepManager.shared.setup()
            // 启动设置
            AppState.shared.appDidLaunch()
        }
    }
    
    // 日志重定向，建议在 App 启动时调用
     static func redirectStdoutToFile() {
         freopen(appLogFilePath, "a+", stdout)
         freopen(appLogFilePath, "a+", stderr)
     }
    
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        logger.info("applicationShouldTerminate")

        // 停止所有快捷键监听
        // todo

        // 停止 V2ray
        Task{
            await V2rayLaunch.shared.stop()
        }

        // 终止 V2ray 进程
        killSelfV2ray()

        logger.info("applicationShouldTerminate end")
        return .terminateNow
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        logger.info("Application will terminate.")
        Task {
            await LocalHttpServer.shared.stop()
        }
    }
}
