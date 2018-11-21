//
//  Menu.swift
//  V2rayU
//
//  Created by yanue on 2018/10/16.
//  Copyright © 2018 yanue. All rights reserved.
//

import Foundation
import Cocoa
import ServiceManagement
import Preferences
import SystemConfiguration

// menu controller
class MenuController: NSObject, NSMenuDelegate {
    var authRef: AuthorizationRef?
    var configWindow: ConfigWindowController!

    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    var statusItemClicked: (() -> Void)?

    let preferencesWindowController = PreferencesWindowController(
            viewControllers: [
                PreferenceGeneralViewController(),
            ]
    )

    @IBOutlet weak var v2rayRulesMode: NSMenuItem!
    @IBOutlet weak var globalMode: NSMenuItem!
    @IBOutlet weak var statusMenu: NSMenu!
    @IBOutlet weak var toggleV2rayItem: NSMenuItem!
    @IBOutlet weak var v2rayStatusItem: NSMenuItem!
    @IBOutlet weak var serverItems: NSMenuItem!

    // when menu.xib loaded
    override func awakeFromNib() {
        // Do any additional setup after loading the view.
        // initial auth ref
        let error = AuthorizationCreate(nil, nil, [], &authRef)
        assert(error == errAuthorizationSuccess)

        if UserDefaults.getBool(forKey: .globalMode) {
            self.globalMode.state = .on
            self.v2rayRulesMode.state = .off
        } else {
            self.globalMode.state = .off
            self.v2rayRulesMode.state = .on
        }

        statusMenu.delegate = self
        NSLog("start menu")
        // load server list
        V2rayServer.loadConfig()
        // show server list
        self.showServers()

        statusItem.menu = statusMenu

        configWindow = ConfigWindowController()
        if UserDefaults.getBool(forKey: .v2rayTurnOn) {
            // start
            // on status
            self.startV2rayCore()
        } else {
            // show off status
            self.setStatusOff()
        }
    }

    @IBAction func openLogs(_ sender: NSMenuItem) {
        V2rayLaunch.OpenLogs()
    }

    func setStatusOff() {
        v2rayStatusItem.title = "V2ray-Core: Off"
        toggleV2rayItem.title = "Turn V2ray-Core On"

        if let button = statusItem.button {
            button.image = NSImage(named: NSImage.Name("IconOff"))
        }

        // set off
        UserDefaults.setBool(forKey: .v2rayTurnOn, value: false)
    }

    func setStatusOn() {
        v2rayStatusItem.title = "V2ray-Core: On"
        toggleV2rayItem.title = "Turn V2ray-Core Off"

        if let button = statusItem.button {
            button.image = NSImage(named: NSImage.Name("IconOn"))
        }

        // set on
        UserDefaults.setBool(forKey: .v2rayTurnOn, value: true)
    }

    func stopV2rayCore() {
        // set status
        self.setStatusOff()
        // stop launch
        V2rayLaunch.Stop()
        // if enable system proxy
        if UserDefaults.getBool(forKey: .globalMode) {
            // close system proxy
            self.setSystemProxy(enabled: false)
        }
    }

    // start v2ray core
    func startV2rayCore() {
        NSLog("start v2ray-core begin")

        guard let v2ray = V2rayServer.loadSelectedItem() else {
            NSLog("v2ray config not fould")
            return
        }

        if !v2ray.isValid {
            NSLog("invid v2ray config")
            return
        }

        // create json file
        V2rayConfig.createJsonFile(item: v2ray)

        // set status
        setStatusOn()

        // launch
        V2rayLaunch.Start()
        NSLog("start v2ray-core end.")

        // if enable system proxy
        if UserDefaults.getBool(forKey: .globalMode) {
            // reset system proxy
            self.enableSystemProxy()
        }
    }

    @IBAction func start(_ sender: NSMenuItem) {
        // turn off
        if UserDefaults.getBool(forKey: .v2rayTurnOn) {
            self.stopV2rayCore()
            return
        }

        // start
        self.startV2rayCore()
    }

    @IBAction func quitClicked(_ sender: NSMenuItem) {
        NSApplication.shared.terminate(self)
    }

    @IBAction func generateQRCode(_ sender: NSMenuItem) {
        NSLog("GenerateQRCode")
    }

    @IBAction func scanQRCode(_ sender: NSMenuItem) {
        NSLog("ScanQRCode")
    }

    @IBAction func openPreference(_ sender: NSMenuItem) {
        self.preferencesWindowController.showWindow()
    }

    // switch server
    @IBAction func switchServer(_ sender: NSMenuItem) {
        guard let obj = sender.representedObject as? V2rayItem else {
            NSLog("switchServer err")
            return
        }

        if !obj.isValid {
            NSLog("current server is invaid", obj.remark)
            return
        }
        // set current
        UserDefaults.set(forKey: .v2rayCurrentServerName, value: obj.name)
        // stop first
        V2rayLaunch.Stop()
        // start
        startV2rayCore()
        // reload menu
        self.showServers()
    }

    // open config window
    @IBAction func openConfig(_ sender: NSMenuItem) {
        if configWindow != nil {
            // close by window `x` button
            if configWindow.closedByWindowButton {
                configWindow.close()
                // need renew
                configWindow = ConfigWindowController()
            }
        } else {
            configWindow = ConfigWindowController()
        }

        configWindow.showWindow(self)
        // bring to front
        NSApp.activate(ignoringOtherApps: true)
        // show dock icon
//        NSApp.setActivationPolicy(.regular)
    }

    @IBAction func goHelp(_ sender: NSMenuItem) {
        guard let url = URL(string: "https://github.com/yanue/v2rayu/wiki") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    func showServers() {
        // reomve old items
        serverItems.submenu?.removeAllItems()
        let curSer = UserDefaults.get(forKey: .v2rayCurrentServerName)

//        // servers preferences...
//        let menuItem: NSMenuItem = NSMenuItem()
//        menuItem.title = "servers preferences..."
//        menuItem.action = #selector(self.openConfig(_:))
//        menuItem.target = self
//        menuItem.isEnabled = true
//        serverItems.submenu?.addItem(menuItem)
//
//        // separator
//        serverItems.submenu?.addItem(NSMenuItem.separator())

        // add new
        var validCount = 0
        for item in V2rayServer.list() {
            if !item.isValid {
                continue
            }

            let menuItem: NSMenuItem = NSMenuItem()
            menuItem.title = item.remark
            menuItem.action = #selector(self.switchServer(_:))
            menuItem.representedObject = item
            menuItem.target = self
            menuItem.isEnabled = true

            if curSer == item.name || V2rayServer.count() == 1 {
                menuItem.state = NSControl.StateValue.on
            }

            serverItems.submenu?.addItem(menuItem)
            validCount += 1
        }

        if validCount == 0 {
            let menuItem: NSMenuItem = NSMenuItem()
            menuItem.title = "no available servers."
            menuItem.isEnabled = false
            serverItems.submenu?.addItem(menuItem)
        }
    }

    @IBAction func disableGlobalProxy(_ sender: NSMenuItem) {
        // state
        self.globalMode.state = .off
        self.v2rayRulesMode.state = .on
        // save
        UserDefaults.setBool(forKey: .globalMode, value: false)
        // disable
        self.setSystemProxy(enabled: false)
    }

    // MARK: - actions
    @IBAction func enableGlobalProxy(_ sender: NSMenuItem) {
        enableSystemProxy()
    }

    func enableSystemProxy() {
        // save
        UserDefaults.setBool(forKey: .globalMode, value: true)
        // state
        self.globalMode.state = .on
        self.v2rayRulesMode.state = .off

        // enable
        var sockPort = ""
        var httpPort = ""

        let v2ray = V2rayServer.loadSelectedItem()

        if v2ray != nil && v2ray!.isValid {
            let cfg = V2rayConfig()
            cfg.parseJson(jsonText: v2ray!.json)
            sockPort = cfg.socksPort
            httpPort = cfg.httpPort
        }

        print("httpPort", httpPort, sockPort)
        self.setSystemProxy(enabled: true, httpPort: httpPort, sockPort: sockPort)
    }

    func setSystemProxy(enabled: Bool, httpPort: String = "", sockPort: String = "") {
        Swift.print("Socks proxy set: \(enabled)")

        // setup policy database db
        CommonAuthorization.shared.setupAuthorizationRights(authRef: self.authRef!)

        // copy rights
        let rightName: String = CommonAuthorization.systemProxyAuthRightName
        var authItem = AuthorizationItem(name: (rightName as NSString).utf8String!, valueLength: 0, value: UnsafeMutableRawPointer(bitPattern: 0), flags: 0)
        var authRight: AuthorizationRights = AuthorizationRights(count: 1, items: &authItem)

        let copyRightStatus = AuthorizationCopyRights(self.authRef!, &authRight, nil, [.extendRights, .interactionAllowed, .preAuthorize, .partialRights], nil)

        Swift.print("AuthorizationCopyRights result: \(copyRightStatus), right name: \(rightName)")
        assert(copyRightStatus == errAuthorizationSuccess)

        // set system proxy
        let prefRef = SCPreferencesCreateWithAuthorization(kCFAllocatorDefault, "systemProxySet" as CFString, nil, self.authRef)!
        let sets = SCPreferencesGetValue(prefRef, kSCPrefNetworkServices)!

        var proxies = [NSObject: AnyObject]()

        // proxy enabled set
        if enabled {
            // socks
            if sockPort != "" && Int(sockPort) ?? 0 > 1024 {
                proxies[kCFNetworkProxiesSOCKSEnable] = 1 as NSNumber
                proxies[kCFNetworkProxiesSOCKSProxy] = "127.0.0.1" as AnyObject?
                proxies[kCFNetworkProxiesSOCKSPort] = Int(sockPort)! as NSNumber
                proxies[kCFNetworkProxiesExcludeSimpleHostnames] = 1 as NSNumber
            }

            // check http port
            if httpPort != "" && Int(httpPort) ?? 0 > 1024 {
                // http
                proxies[kCFNetworkProxiesHTTPEnable] = 1 as NSNumber
                proxies[kCFNetworkProxiesHTTPProxy] = "127.0.0.1" as AnyObject?
                proxies[kCFNetworkProxiesHTTPPort] = Int(httpPort)! as NSNumber
                proxies[kCFNetworkProxiesExcludeSimpleHostnames] = 1 as NSNumber

                // https
                proxies[kCFNetworkProxiesHTTPSEnable] = 1 as NSNumber
                proxies[kCFNetworkProxiesHTTPSProxy] = "127.0.0.1" as AnyObject?
                proxies[kCFNetworkProxiesHTTPSPort] = Int(httpPort)! as NSNumber
                proxies[kCFNetworkProxiesExcludeSimpleHostnames] = 1 as NSNumber
            }
        } else {
            // set enable 0
            proxies[kCFNetworkProxiesSOCKSEnable] = 0 as NSNumber
            proxies[kCFNetworkProxiesHTTPEnable] = 0 as NSNumber
            proxies[kCFNetworkProxiesHTTPSEnable] = 0 as NSNumber
        }

        sets.allKeys!.forEach { (key) in
            let dict = sets.object(forKey: key)!
            let hardware = (dict as AnyObject).value(forKeyPath: "Interface.Hardware")

            if hardware != nil && ["AirPort", "Wi-Fi", "Ethernet"].contains(hardware as! String) {
                SCPreferencesPathSetValue(prefRef, "/\(kSCPrefNetworkServices)/\(key)/\(kSCEntNetProxies)" as CFString, proxies as CFDictionary)
            }
        }

        // commit to system preferences.
        let commitRet = SCPreferencesCommitChanges(prefRef)
        let applyRet = SCPreferencesApplyChanges(prefRef)
        SCPreferencesSynchronize(prefRef)

        Swift.print("after SCPreferencesCommitChanges: commitRet = \(commitRet), applyRet = \(applyRet)")
    }
}
