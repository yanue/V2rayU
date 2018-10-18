//
//  AppDelegate.swift
//  V2rayU
//
//  Created by yanue on 2018/10/9.
//  Copyright © 2018 yanue. All rights reserved.
//

import Cocoa
import ServiceManagement

let launcherAppIdentifier = "yanue.V2rayU.Launcher"

extension Notification.Name {
    static let killLauncher = Notification.Name("killLauncher")
}

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    // bar menu
    @IBOutlet weak var statusMenu: NSMenu!
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
        
        let runningApps = NSWorkspace.shared.runningApplications
        let isRunning = !runningApps.filter { $0.bundleIdentifier == launcherAppIdentifier }.isEmpty
        
        // run at login 
        SMLoginItemSetEnabled(launcherAppIdentifier as CFString, true)
        
        if isRunning {
            DistributedNotificationCenter.default().post(name: .killLauncher, object: Bundle.main.bundleIdentifier!)
        }

        UserDefaults.standard.register(defaults: ["NSApplicationCrashOnExceptions": true])
        
        print("startedAtLogin", isRunning)
        
        // v2ray-core check version
        V2rayCore().check()
        generateSSLocalLauchAgentPlist()
        StartV2rayCore()
    }
   
    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
        print("Terminate")
        StopV2rayCore()
    }
}


