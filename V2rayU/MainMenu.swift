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
    // when menu.xib loaded
    override func awakeFromNib() {
        // load server list
        V2rayServer.loadConfig()
        self.showServers()
        statusMenu.delegate = self
        
        if let button = statusItem.button {
            button.image = NSImage(named:NSImage.Name("TrayIcon"))
        }
        
        statusItem.menu = statusMenu
        configWindow = ConfigWindowController()
    }
    
    let preferencesWindowController = PreferencesWindowController(
        viewControllers: [
            PreferenceGeneralViewController(),
        ]
    )
    
    var v2rayStatus = false
    
    var configWindow: ConfigWindowController!
    
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    var statusItemClicked: (() -> Void)?
    
    @IBOutlet weak var toggleV2rayItem: NSMenuItem!
    @IBOutlet weak var v2rayStatusItem: NSMenuItem!
    
    // bar menu
    @IBOutlet weak var statusMenu: NSMenu!
    // server list items
    @IBOutlet weak var serverItems: NSMenuItem!
    
    @IBAction func openLogs(_ sender: NSMenuItem) {
        V2rayU.OpenLogs()
    }

    @IBAction func start(_ sender: NSMenuItem) {
        // turn off
        if v2rayStatus {
            v2rayStatusItem.title = "V2ray-Core: Off"
            toggleV2rayItem.title = "Turn V2ray-Core On"
            return
        }
        
        // turn on
        v2rayStatusItem.title = "V2ray-Core: On"
        toggleV2rayItem.title = "Turn V2ray-Core Off"
        
        guard let v2ray = V2rayServer.loadSelectedItem() else {
            NSLog("v2ray config not fould")
            return
        }
        
        if !v2ray.usable {
            NSLog("invid v2ray config")
            return
        }
        
        StartV2rayCore()
        // has turned on
        v2rayStatus = true
    }
    
    @IBAction func quitClicked(_ sender: NSMenuItem) {
        NSApplication.shared.terminate(self)
    }
    
    @IBAction func generateQRCode(_ sender: NSMenuItem) {
        print("GenerateQRCode")
    }
    
    @IBAction func scanQRCode(_ sender: NSMenuItem) {
        print("ScanQRCode")
    }
    
    @IBAction func openPreference(_ sender: NSMenuItem) {
        print("openPreference ")
//        let app = NSApplication.shared.delegate as! AppDelegate

        self.preferencesWindowController.showWindow()
    }
    
    // switch server
    @IBAction func switchServer(_ sender: NSMenuItem) {
        if let obj = sender.representedObject as? v2rayItem {

            // path: /Application/V2rayU.app/Contents/Resources/config.json
            guard let jsonFile = V2rayServer.getJsonFile() else {
                print("unable get config file path")
                return
            }
            let jsonText = obj.json
            do {
                try jsonText.write(to: URL.init(fileURLWithPath: jsonFile), atomically: true, encoding: String.Encoding.utf8)
            } catch {
                // failed to write file – bad permissions, bad filename, missing permissions, or more likely it can't be converted to the encoding
                return
            }
            
            UserDefaults.set(forKey: .v2rayCurrentServerName,value: obj.name)
        }
    }
    
    // open config window
    @IBAction func openConfig(_ sender: NSMenuItem) {
        configWindow.showWindow (nil)
        // bring to front
        NSApp.activate(ignoringOtherApps: true)
        // show dock icon
        NSApp.setActivationPolicy(.regular)
    }
    
    @IBAction func goHelp(_ sender: NSMenuItem) {
        guard let url = URL(string: "https://github.com/yanue/v2rayu/wiki") else { return }
        NSWorkspace.shared.open(url)
    }
    
    func showServers() {
        // reomve old items
        serverItems.submenu?.removeAllItems()
        let curSer = UserDefaults.get(forKey: .v2rayCurrentServerName)
        
        let menuItem : NSMenuItem = NSMenuItem()
        menuItem.title = "servers preferences..."
        menuItem.action = #selector(self.openConfig(_:))
        menuItem.target = self
        menuItem.isEnabled = true
        serverItems.submenu?.addItem(menuItem)

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
            
            if curSer == item.name {
                menuItem.state = NSControl.StateValue.on
            }
            
            serverItems.submenu?.addItem(menuItem)
        }
    }
}
