import SwiftData
import SwiftUI
import Foundation
import OSLog

//import FirebaseCore
//import AppCenter
//import AppCenterAnalytics
//import AppCenterCrashes

let AppResourcesPath = Bundle.main.bundlePath + "/Contents/Resources"
let AppHomePath = NSHomeDirectory() + "/.V2rayU"
let databasePath = NSHomeDirectory() + "/.V2rayU/.V2rayU.db"
let v2rayUTool = AppHomePath + "/V2rayUTool"
let v2rayCorePath = AppHomePath + "/v2ray-core"
let v2rayCoreFile = v2rayCorePath + "/v2ray"
let v2rayLogFilePath = AppHomePath + "/v2ray-core.log"
let appLogFilePath = AppHomePath + "/V2rayU.log"
let JsonConfigFilePath = AppHomePath + "/config.json"
let userHomeDirectory = FileManager.default.homeDirectoryForCurrentUser.path
let logger = Logger(subsystem: "net.yanue.V2rayU", category: "app")
let uiLogger = Logger(subsystem: "net.yanue.V2rayU", category: "ui")

/// Mark - 入口
@main
struct V2rayUApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    var body: some Scene {
        // 留空
    }
}

/// AppDelegate - 应用
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        logger.info("Application did finish launching.")
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
        AppLogStream.stopLogging()
        V2rayLogStream.stopLogging()
        Task {
            await LocalHttpServer.shared.stop()
        }
    }
}
