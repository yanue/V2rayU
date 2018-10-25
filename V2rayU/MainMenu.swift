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

// menu controller
class MenuController:NSObject,NSMenuDelegate {

    var configWindow: ConfigWindowController!
    
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    var statusItemClicked: (() -> Void)?
    
    let preferencesWindowController = PreferencesWindowController(
        viewControllers: [
            PreferenceGeneralViewController(),
        ]
    )
    
    @IBOutlet weak var statusMenu: NSMenu!
    @IBOutlet weak var toggleV2rayItem: NSMenuItem!
    @IBOutlet weak var v2rayStatusItem: NSMenuItem!
    @IBOutlet weak var serverItems: NSMenuItem!
    
    // when menu.xib loaded
    override func awakeFromNib() {
        statusMenu.delegate = self
        NSLog("start menu")
        // load server list
        V2rayServer.loadConfig()
        // show server list
        self.showServers()

        if UserDefaults.getBool(forKey: .v2rayTurnOn) {
            // start
            self.startV2rayCore()
        } else{
            self.setStatusOff()
        }
    
        statusItem.menu = statusMenu
        
        configWindow = ConfigWindowController()
    }
    
    @IBAction func openLogs(_ sender: NSMenuItem) {
        V2rayLaunch.OpenLogs()
    }

    func setStatusOff() {
        v2rayStatusItem.title = "V2ray-Core: Off"
        toggleV2rayItem.title = "Turn V2ray-Core On"
        
        if let button = statusItem.button {
            button.image = NSImage(named:NSImage.Name("IconOff"))
        }
        
        // set off
        UserDefaults.setBool(forKey: .v2rayTurnOn, value: false)
    }
    
    func setStatusOn() {
        v2rayStatusItem.title = "V2ray-Core: On"
        toggleV2rayItem.title = "Turn V2ray-Core Off"
        
        if let button = statusItem.button {
            button.image = NSImage(named:NSImage.Name("IconOn"))
        }
        
        // set on
        UserDefaults.setBool(forKey: .v2rayTurnOn, value: true)
    }
    
    func stopV2rayCore() {
        // set status
        self.setStatusOff()
        // stop launch
        V2rayLaunch.Stop()
    }
    
    // start v2ray core
    func startV2rayCore() {
        NSLog("start v2ray-core begin")

        guard let v2ray = V2rayServer.loadSelectedItem() else {
            NSLog("v2ray config not fould")
            return
        }
        
        if !v2ray.usable {
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
        guard let obj = sender.representedObject as? v2rayItem else {
            NSLog("switchServer err")
            return
        }
        
        if !obj.usable {
            NSLog("current server is invaid",obj.remark)
            return
        }
        // set current
        UserDefaults.set(forKey: .v2rayCurrentServerName,value: obj.name)
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
        guard let url = URL(string: "https://github.com/yanue/v2rayu/wiki") else { return }
        NSWorkspace.shared.open(url)
    }
    
    func showServers() {
        // reomve old items
        serverItems.submenu?.removeAllItems()
        let curSer = UserDefaults.get(forKey: .v2rayCurrentServerName)
        
        // servers preferences...
        let menuItem : NSMenuItem = NSMenuItem()
        menuItem.title = "servers preferences..."
        menuItem.action = #selector(self.openConfig(_:))
        menuItem.target = self
        menuItem.isEnabled = true
        serverItems.submenu?.addItem(menuItem)

        // separator
        serverItems.submenu?.addItem(NSMenuItem.separator())

        // add new
        for item in V2rayServer.list() {
            if !item.usable {
                continue
            }
            
            let menuItem : NSMenuItem = NSMenuItem()
            menuItem.title = item.remark
            menuItem.action = #selector(self.switchServer(_:))
            menuItem.representedObject = item
            menuItem.target = self
            menuItem.isEnabled = true
            
            if curSer == item.name || V2rayServer.count() == 1 {
                menuItem.state = NSControl.StateValue.on
            }
            
            serverItems.submenu?.addItem(menuItem)
        }
    }
}
