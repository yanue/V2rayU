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

func SignalHandler(signal: Int32) -> Void {
    var mstr = String()
    mstr += "Stack:\n"
//    mstr = mstr.appendingFormat("slideAdress:0x%0x\r\n", calculate())
    for symbol in Thread.callStackSymbols {
        mstr = mstr.appendingFormat("%@\r\n", symbol)
    }
}

func exceptionHandler(exception: NSException) {
    print(exception)
    print(exception.callStackSymbols)
    let stack = exception.callStackReturnAddresses
    print("Stack trace: \(stack)")
    print("Error Handling: ", exception)
    print("Error Handling callStackSymbols: ", exception.callStackSymbols)

    UserDefaults.setArray(forKey: .Exception, value: exception.callStackSymbols)
}

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    // bar menu
    @IBOutlet weak var statusMenu: NSMenu!

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // ERROR ExceptionHandler
        if let exception = UserDefaults.getArray(forKey: .Exception) as? [String] {
            print("Error was occured on previous session! \n", exception, "\n\n-------------------------")
            var exceptions = ""
            for e in exception {
                exceptions = exceptions + e + "\n"
            }
            makeToast(message: exceptions)
            UserDefaults.delArray(forKey: .Exception)
        }
        NSSetUncaughtExceptionHandler(exceptionHandler);

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

        // check v2ray core
        V2rayCore().check()

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
        if UserDefaults.get(forKey: .xRayCoreVersion) == nil {
            UserDefaults.set(forKey: .xRayCoreVersion, value: V2rayCore.version)
        }
        if UserDefaults.get(forKey: .autoCheckVersion) == nil {
            UserDefaults.setBool(forKey: .autoCheckVersion, value: true)
        }
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
        if UserDefaults.get(forKey: .gfwPacFileContent) == nil {
            let gfwlist = try? String(contentsOfFile: GFWListFilePath, encoding: String.Encoding.utf8)
            UserDefaults.set(forKey: .gfwPacFileContent, value: gfwlist ?? "")
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
        // reconnect
        if UserDefaults.getBool(forKey: .v2rayTurnOn) {
            V2rayLaunch.Stop()
            V2rayLaunch.Start()
        }
        // check v2ray core
        V2rayCore().check()
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
//        PingSpeed().pingAll()
    }

    @objc func onSleepNote(note: NSNotification) {
        print("onSleepNote")
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
