//
//  AppDelegate.swift
//  V2rayU
//
//  Created by yanue on 2018/10/9.
//  Copyright © 2018 yanue. All rights reserved.
//

import Cocoa
import ServiceManagement
import os.log

let launcherAppIdentifier = "net.yanue.V2rayU.Launcher"

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    // bar menu
    @IBOutlet weak var statusMenu: NSMenu!
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
        os_log("v2rayu init.")
//        showAccessibilityDeniedAlert()

        let startedAtLogin = NSWorkspace.shared.runningApplications.contains {
            $0.bundleIdentifier == launcherAppIdentifier
        }
        
        print("startedAtLogin",startedAtLogin)
        os_log("startedAtLogin", startedAtLogin)
        if startedAtLogin {
            DistributedNotificationCenter.default().post(name: Notification.Name("terminateV2rayU"), object: Bundle.main.bundleIdentifier!)
        }
        
        // 定义NSUserNotification
        let userNotification = NSUserNotification()
        userNotification.title = "消息Title"
        userNotification.subtitle = "消息SubTitle"
        userNotification.informativeText = "消息InformativeText"
        // 使用NSUserNotificationCenter发送NSUserNotification
        let userNotificationCenter = NSUserNotificationCenter.default
        userNotificationCenter.scheduleNotification(userNotification)
       
        //
//        UserDefaults.standard.register(defaults: ["NSApplicationCrashOnExceptions": true])
//
//        print("startedAtLogin", isRunning)
//
//        // v2ray-core check version
//        V2rayCore().check()
//        generateSSLocalLauchAgentPlist()
//        StartV2rayCore()
    }
  
    func showAccessibilityDeniedAlert() {
        NSApplication.shared.activate(ignoringOtherApps: true)
        
        let alert: NSAlert = NSAlert()
        alert.messageText = NSLocalizedString("alert.accessibility_disabled_message", comment: "Accessibility permissions for Shifty have been disabled")
        alert.informativeText = NSLocalizedString("alert.accessibility_disabled_informative", comment: "Accessibility must be allowed to enable website shifting. Grant access to Shifty in Security & Privacy preferences, located in System Preferences.")
        alert.alertStyle = NSAlert.Style.warning
        alert.addButton(withTitle: NSLocalizedString("alert.open_preferences", comment: "Open System Preferences"))
        alert.addButton(withTitle: NSLocalizedString("alert.not_now", comment: "Not now"))
        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
            NSLog("Open System Preferences button clicked")
        } else {
            NSLog("Not now button clicked")
        }
    }
    
    
    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
        print("Terminate")
        StopV2rayCore()
    }
}


