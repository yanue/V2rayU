//
//  AppDelegate.swift
//  V2rayU
//
//  Created by yanue on 2018/10/9.
//  Copyright © 2018 yanue. All rights reserved.
//

import Cocoa
import ServiceManagement

let launcherAppIdentifier = "net.yanue.V2rayU.Launcher"

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    // bar menu
    @IBOutlet weak var statusMenu: NSMenu!


    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application        
        let startedAtLogin = NSWorkspace.shared.runningApplications.contains {
            $0.bundleIdentifier == launcherAppIdentifier
        }

        if startedAtLogin {
            DistributedNotificationCenter.default().post(name: Notification.Name("terminateV2rayU"), object: Bundle.main.bundleIdentifier!)
        }

        self.checkDefault()

        // check v2ray core
        V2rayCore().check()
        // generate plist
        V2rayLaunch.generateLauchAgentPlist()
        // auto check updates
        if UserDefaults.getBool(forKey: .autoCheckVersion) {
            // check version
            V2rayUpdater.checkForUpdatesInBackground()
        }
    }

    func checkDefault() {
        if UserDefaults.get(forKey: .v2rayCoreVersion) == nil {
            UserDefaults.set(forKey: .v2rayCoreVersion, value: V2rayCore.version)
        }
        if UserDefaults.get(forKey: .autoCheckVersion) == nil {
            UserDefaults.setBool(forKey: .v2rayCoreVersion, value: true)
        }
        if UserDefaults.get(forKey: .autoLaunch) == nil {
            SMLoginItemSetEnabled(launcherAppIdentifier as CFString, true)
            UserDefaults.setBool(forKey: .v2rayCoreVersion, value: true)
        }
        if V2rayServer.count() == 0 {
            // add default
            V2rayServer.add(remark: "default", json: "", isValid: false)
        }
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
        V2rayLaunch.Stop()
    }
}
