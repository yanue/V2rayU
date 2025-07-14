import SwiftUI
import Foundation
//import FirebaseCore
//import AppCenter
//import AppCenterAnalytics
//import AppCenterCrashes

let LAUNCH_AGENT_NAME = "yanue.v2rayu.v2ray-core"
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

@MainActor let windowDelegate = WindowDelegate()

class AppDelegate: NSObject, NSApplicationDelegate {
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        print("Application did finish launching.")
        
        V2rayLaunch.checkInstall()
        V2rayLaunch.runAtStart()
        // 日志流
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            Task { @MainActor in
                AppLogStream.startLogging()
                V2rayLogStream.startLogging()
            }
        }
        // 自动更新订阅服务器
        Task{
            await SubscriptionHandler.shared.sync()
        }
        // 监听系统睡眠和唤醒通知
        DistributedNotificationCenter.default.addObserver(
            self,
            selector: #selector(onWakeNote),
            name: NSNotification.Name(rawValue: "com.apple.screenIsUnlocked"),
            object: nil
        )

        DistributedNotificationCenter.default.addObserver(
            self,
            selector: #selector(onSleepNote),
            name: NSNotification.Name(rawValue: "com.apple.screenIsLocked"),
            object: nil
        )
    }
    
    // 日志重定向，建议在 App 启动时调用
     static func redirectStdoutToFile() {
         freopen(appLogFilePath, "a+", stdout)
         freopen(appLogFilePath, "a+", stderr)
     }
    
    @objc func onWakeNote(note: NSNotification) {
        NSLog("onWakeNote")
        if UserDefaults.getBool(forKey: .v2rayTurnOn) {
            NSLog("V2rayLaunch restart")
            V2rayLaunch.restartV2ray()
        }
        if UserDefaults.getBool(forKey: .autoCheckVersion) {
            // 自动检查更新
//            V2rayUpdater.checkForUpdates()
        }
        if UserDefaults.getBool(forKey: .autoUpdateServers) {
            // 自动更新订阅服务器
            Task{
                await SubscriptionHandler.shared.sync()
            }
        }
        // ping
        Task {
            await PingAll.shared.run()
        }
    }

    @objc func onSleepNote(note: NSNotification) {
        NSLog("onSleepNote")
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        print("applicationShouldTerminate")

        // 停止所有快捷键监听


        // 停止 V2ray
        V2rayLaunch.stopTun2Socks()
        V2rayLaunch.Stop()

        // 关闭系统代理
        V2rayLaunch.setSystemProxy(mode: .off)

        // 终止 V2ray 进程
        killSelfV2ray()

        print("applicationShouldTerminate end")
        return .terminateNow
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        print("Application will terminate.")
        AppLogStream.stopLogging()
        V2rayLogStream.stopLogging()
    }
}
