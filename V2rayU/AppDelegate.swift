//
//  AppDelegate.swift
//  V2rayU
//
//  Created by yanue on 2018/10/9.
//  Copyright © 2018 yanue. All rights reserved.
//

import Cocoa
import ServiceManagement
import AppCenter
import AppCenterAnalytics
import AppCenterCrashes
import MASShortcut

let launcherAppIdentifier = "net.yanue.V2rayU.Launcher"
let appVersion = getAppVersion()

let NOTIFY_TOGGLE_RUNNING_SHORTCUT = Notification.Name(rawValue: "NOTIFY_TOGGLE_RUNNING_SHORTCUT")
let NOTIFY_SWITCH_PROXY_MODE_SHORTCUT = Notification.Name(rawValue: "NOTIFY_SWITCH_PROXY_MODE_SHORTCUT")


@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    // bar menu
    @IBOutlet weak var statusMenu: NSMenu!

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        
        // default settings
        self.checkDefault()

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

        AppCenter.start(withAppSecret: "d52dd1a1-7a3a-4143-b159-a30434f87713", services:[
          Analytics.self,
          Crashes.self
        ])

        // auto check updates
        if UserDefaults.getBool(forKey: .autoCheckVersion) {
            menuController.checkV2rayUVersion()
            // check version
            V2rayUpdater.checkForUpdatesInBackground()
        }

        _ = GeneratePACFile(rewrite: true)
        // start http server for pac
        V2rayLaunch.startHttpServer()

        // wake and sleep
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(onSleepNote(note:)), name: NSWorkspace.willSleepNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(onWakeNote(note:)), name: NSWorkspace.didWakeNotification, object: nil)
        // url scheme
        NSAppleEventManager.shared().setEventHandler(self, andSelector: #selector(self.handleAppleEvent(event:replyEvent:)), forEventClass: AEEventClass(kInternetEventClass), andEventID: AEEventID(kAEGetURL))

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
        if UserDefaults.get(forKey: .autoUpdateServers) == nil {
            UserDefaults.setBool(forKey: .autoUpdateServers, value: true)
        }
        if UserDefaults.get(forKey: .autoSelectFastestServer) == nil {
            UserDefaults.setBool(forKey: .autoSelectFastestServer, value: false)
        }
        if UserDefaults.get(forKey: .autoLaunch) == nil {
            SMLoginItemSetEnabled(launcherAppIdentifier as CFString, true)
            UserDefaults.setBool(forKey: .autoLaunch, value: true)
        }
        if UserDefaults.get(forKey: .runMode) == nil {
            UserDefaults.set(forKey: .runMode, value: RunMode.pac.rawValue)
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
        NSLog("onWakeNote")
        // reconnect
        if UserDefaults.getBool(forKey: .v2rayTurnOn) {
            NSLog("V2rayLaunch restart")
            V2rayLaunch.Stop()
            V2rayLaunch.Start()
        }
        // auto check updates
        if UserDefaults.getBool(forKey: .autoCheckVersion) {
            menuController.checkV2rayUVersion()
            // check version
            V2rayUpdater.checkForUpdatesInBackground()
        }
        // auto update subscribe servers
        if UserDefaults.getBool(forKey: .autoUpdateServers) {
            V2raySubSync().sync()
        }
        // ping
        ping.pingAll()
    }

    @objc func onSleepNote(note: NSNotification) {
        NSLog("onSleepNote")
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // unregister All shortcut
        MASShortcutMonitor.shared().unregisterAllShortcuts()
        // Insert code here to tear down your application
        V2rayLaunch.Stop()
        // off system proxy
        V2rayLaunch.setSystemProxy(mode: .off)
    }
}
