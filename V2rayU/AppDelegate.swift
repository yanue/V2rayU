//
//  AppDelegate.swift
//  V2rayU
//
//  Created by yanue on 2018/10/9.
//  Copyright © 2018 yanue. All rights reserved.
//

import Cocoa
import ServiceManagement
import MASShortcut
import Preferences
import FirebaseCore

let launcherAppIdentifier = "net.yanue.V2rayU.Launcher"
let appVersion = getAppVersion()

let NOTIFY_TOGGLE_RUNNING_SHORTCUT = Notification.Name(rawValue: "NOTIFY_TOGGLE_RUNNING_SHORTCUT")
let NOTIFY_SWITCH_PROXY_MODE_SHORTCUT = Notification.Name(rawValue: "NOTIFY_SWITCH_PROXY_MODE_SHORTCUT")

extension PreferencePane.Identifier {
    static let generalTab = Identifier("generalTab")
    static let advanceTab = Identifier("advanceTab")
    static let subscribeTab = Identifier("subscribeTab")
    static let pacTab = Identifier("pacTab")
    static let routingTab = Identifier("routingTab")
    static let dnsTab = Identifier("dnsTab")
    static let aboutTab = Identifier("aboutTab")
}

let preferencesWindowController = PreferencesWindowController(
        preferencePanes: [
            PreferenceGeneralViewController(),
            PreferenceAdvanceViewController(),
            PreferenceSubscribeViewController(),
            PreferenceRoutingViewController(),
            PreferencePacViewController(),
            PreferenceDnsViewController(),
            PreferenceAboutViewController(),
        ]
)

let langStr = Locale.current.languageCode
let isMainland = langStr == "zh-CN" || langStr == "zh" || langStr == "zh-Hans" || langStr == "zh-Hant"

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    // bar menu
    @IBOutlet weak var statusMenu: NSMenu!

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        print("applicationDidFinishLaunching")
        FirebaseApp.configure()

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

        // wake and sleep
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(onSleepNote(note:)), name: NSWorkspace.willSleepNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(onWakeNote(note:)), name: NSWorkspace.didWakeNotification, object: nil)
        // url scheme
        NSAppleEventManager.shared().setEventHandler(self, andSelector: #selector(self.handleAppleEvent(event:replyEvent:)), forEventClass: AEEventClass(kInternetEventClass), andEventID: AEEventID(kAEGetURL))

        // set global hotkey
        let notifyCenter = NotificationCenter.default
        notifyCenter.addObserver(forName: NOTIFY_TOGGLE_RUNNING_SHORTCUT, object: nil, queue: nil, using: {
            notice in
            V2rayLaunch.ToggleRunning()
        })

        notifyCenter.addObserver(forName: NOTIFY_SWITCH_PROXY_MODE_SHORTCUT, object: nil, queue: nil, using: {
            notice in
            V2rayLaunch.SwitchProxyMode()
        })

        // Register global hotkey
        ShortcutsController.bindShortcuts()

        // run at start
        V2rayLaunch.runAtStart()

        // auto check updates
        if UserDefaults.getBool(forKey: .autoCheckVersion) {
            // 初始化更新控制器
            V2rayUpdater.checkForUpdates()
        }
    }

    func checkDefault() {
        if UserDefaults.get(forKey: .autoUpdateServers) == nil {
            UserDefaults.setBool(forKey: .autoUpdateServers, value: true)
        }
        if UserDefaults.get(forKey: .autoSelectFastestServer) == nil {
            UserDefaults.setBool(forKey: .autoSelectFastestServer, value: true)
        }
        if UserDefaults.get(forKey: .autoLaunch) == nil {
            SMLoginItemSetEnabled(launcherAppIdentifier as CFString, true)
            UserDefaults.setBool(forKey: .autoLaunch, value: true)
        }
        if UserDefaults.get(forKey: .runMode) == nil {
            UserDefaults.set(forKey: .runMode, value: RunMode.global.rawValue)
        }
        V2rayServer.loadConfig()
        V2rayRoutings.loadConfig()
        V2raySubscription.loadConfig()
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
            V2rayLaunch.restartV2ray()
        }
        // auto check updates
        if UserDefaults.getBool(forKey: .autoCheckVersion) {
            // check version
            V2rayUpdater.checkForUpdates()
        }
        // auto update subscribe servers
        if UserDefaults.getBool(forKey: .autoUpdateServers) {
            V2raySubSync.shared.sync()
        }
        // ping
        ping.pingAll()
    }

    @objc func onSleepNote(note: NSNotification) {
        NSLog("onSleepNote")
    }

    func applicationShouldTerminate (_ sender: NSApplication) -> NSApplication.TerminateReply {
        print("applicationShouldTerminate")
        // unregister All shortcut
        MASShortcutMonitor.shared().unregisterAllShortcuts()
        // Insert code here to tear down your application
        V2rayLaunch.Stop()
        // off system proxy
        V2rayLaunch.setSystemProxy(mode: .off)
        // kill v2ray
        killSelfV2ray()
        // webServer stop
        webServer.stop()
        // code
        print("applicationShouldTerminate end")
        return NSApplication.TerminateReply.terminateNow
    }

    func applicationWillTerminate(_ aNotification: Notification) {
    }
}
