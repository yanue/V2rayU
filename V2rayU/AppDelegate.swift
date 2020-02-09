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
let appVersion = getAppVersion()

let NOTIFY_TOGGLE_RUNNING_SHORTCUT = Notification.Name(rawValue: "NOTIFY_TOGGLE_RUNNING_SHORTCUT")
let NOTIFY_SWITCH_PROXY_MODE_SHORTCUT = Notification.Name(rawValue: "NOTIFY_SWITCH_PROXY_MODE_SHORTCUT")

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    // bar menu
    @IBOutlet weak var statusMenu: NSMenu!


    func applicationDidFinishLaunching(_ aNotification: Notification) {

        // auto launch
        if UserDefaults.getBool(forKey: .autoLaunch) {
            // Insert code here to initialize your application
            let startedAtLogin = NSWorkspace.shared.runningApplications.contains {
                $0.bundleIdentifier == launcherAppIdentifier
            }

            if startedAtLogin {
                DistributedNotificationCenter.default().post(name: Notification.Name("terminateV2rayU"), object: Bundle.main.bundleIdentifier!)
            }
        }

        self.checkDefault()

        // auto Clear Logs
        if UserDefaults.getBool(forKey: .autoClearLog) {
            print("ClearLogs")
            V2rayLaunch.ClearLogs()
        }

        // check v2ray core
        V2rayCore().check()
        // generate plist
        V2rayLaunch.generateLaunchAgentPlist()
        // auto check updates
        if UserDefaults.getBool(forKey: .autoCheckVersion) {
            // check version
            V2rayUpdater.checkForUpdatesInBackground()
        }

        // start http server for pac
        V2rayLaunch.startHttpServer()

        // wake and sleep
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(onSleepNote(note:)), name: NSWorkspace.willSleepNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(onWakeNote(note:)), name: NSWorkspace.didWakeNotification, object: nil)
        // url scheme
        NSAppleEventManager.shared().setEventHandler(self, andSelector: #selector(self.handleAppleEvent(event:replyEvent:)), forEventClass: AEEventClass(kInternetEventClass), andEventID: AEEventID(kAEGetURL))

        let path = Bundle.main.bundlePath
        // /Users/yanue/Library/Developer/Xcode/DerivedData/V2rayU-cqwhqdwsnxsplqgolfwfywalmjps/Build/Products/Debug
        // working dir must be: /Applications/V2rayU.app
        NSLog(String.init(format: "working dir:%@", path))

        if !(path.contains("Developer/Xcode") || path.contains("/Applications/V2rayU.app")) {
            makeToast(message: "Please drag 'V2rayU' to '/Applications' directory", displayDuration: 5.0)
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.5) {
                NSApplication.shared.terminate(self)
            }
        }

        // set global hotkey
        let notifyCenter = NotificationCenter.default
        notifyCenter.addObserver(forName: NOTIFY_TOGGLE_RUNNING_SHORTCUT, object: nil, queue: nil, using: {
            notice in
            ToggleRunning()
        })

        notifyCenter.addObserver(forName: NOTIFY_SWITCH_PROXY_MODE_SHORTCUT, object: nil, queue: nil, using: {
            notice in
            SwitchProxyMode()
        })

        // Register global hotkey
        ShortcutsController.bindShortcuts()
    }

    func checkDefault() {
        if UserDefaults.get(forKey: .v2rayCoreVersion) == nil {
            UserDefaults.set(forKey: .v2rayCoreVersion, value: V2rayCore.version)
        }
        if UserDefaults.get(forKey: .autoCheckVersion) == nil {
            UserDefaults.setBool(forKey: .autoCheckVersion, value: true)
        }
        if UserDefaults.get(forKey: .autoLaunch) == nil {
            SMLoginItemSetEnabled(launcherAppIdentifier as CFString, true)
            UserDefaults.setBool(forKey: .autoLaunch, value: true)
        }
        if UserDefaults.get(forKey: .runMode) == nil {
            UserDefaults.set(forKey: .runMode, value: RunMode.manual.rawValue)
        }
        if V2rayServer.count() == 0 {
            // add default
            V2rayServer.add(remark: "default", json: "", isValid: false)
        }
    }

    @objc func handleAppleEvent(event: NSAppleEventDescriptor, replyEvent: NSAppleEventDescriptor) {
        guard let appleEventDescription = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject)) else {
            return
        }

        guard let appleEventURLString = appleEventDescription.stringValue else {
            return
        }

        _ = URL(string: appleEventURLString)
        // todo
    }

    @objc func onWakeNote(note: NSNotification) {
        print("onWakeNote")
        if UserDefaults.getBool(forKey: .v2rayTurnOn) {
            V2rayLaunch.Start()
        }
        // check v2ray core
        V2rayCore().check()
        // auto check updates
        if UserDefaults.getBool(forKey: .autoCheckVersion) {
            // check version
            V2rayUpdater.checkForUpdatesInBackground()
        }
        // auto update subscribe servers
        V2raySubSync().sync()
        // ping
        menuController.pingAtLaunch()
    }

    @objc func onSleepNote(note: NSNotification) {
        V2rayLaunch.Stop()
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // unregister All shortcut
        MASShortcutMonitor.shared().unregisterAllShortcuts()
        // Insert code here to tear down your application
        V2rayLaunch.Stop()
        // restore system proxy
        V2rayLaunch.setSystemProxy(mode: .restore)
    }
}
