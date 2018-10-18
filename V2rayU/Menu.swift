//
//  Menu.swift
//  V2rayU
//
//  Created by yanue on 2018/10/16.
//  Copyright © 2018 yanue. All rights reserved.
//

import Foundation
import Cocoa
import SwiftLog
import ServiceManagement

// menu controller
class MenuController:NSObject,NSMenuDelegate {
    var configWindow: ConfigWindowController!
    var aboutWindow: AboutWindow!
    
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    var statusItemClicked: (() -> Void)?
    // bar menu
    @IBOutlet weak var statusMenu: NSMenu!
    // server list items
    @IBOutlet weak var serverItems: NSMenuItem!
    
    @IBAction func openLogs(_ sender: NSMenuItem) {
        V2rayU.OpenLogs()
    }
    
    @IBAction func toggleStartAtLogin(_ sender: NSMenuItem) {
        print("toggle",sender.state)

        if sender.state.rawValue == 1 {
            sender.state = .off
            // off
            SMLoginItemSetEnabled(launcherAppIdentifier as CFString, false)
        } else {
            sender.state = .on
            // on
            SMLoginItemSetEnabled(launcherAppIdentifier as CFString, false)
        }
    }
    @IBAction func start(_ sender: NSMenuItem) {
        guard let v2ray = V2rayServer.loadSelectedItem() else {
            logw("v2ray config not fould")
            return
        }
        
        if !v2ray.usable {
            logw("invid v2ray config")
            return
        }
        
        StartV2rayCore()
    }
    
    @IBAction func quitClicked(_ sender: NSMenuItem) {
        NSApplication.shared.terminate(self)
    }
    
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
        aboutWindow = AboutWindow()
    }
    
    @IBAction func openHelp(_ sender: NSMenuItem) {
        if let url = URL(string: "https://www.google.com"),NSWorkspace.shared.open(url) {
        }
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
    
    // open about window
    @IBAction func openAbout(_ sender: NSMenuItem) {
        aboutWindow.showWindow (nil)
        // bring to front
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func showServers() {
        // reomve old items
        serverItems.submenu?.removeAllItems()
        let curSer = UserDefaults.get(forKey: .v2rayCurrentServerName)
        // add new
        for item in V2rayServer.list() {
            if !item.usable {
                continue
            }
            
            let menuItem : NSMenuItem = NSMenuItem()
            menuItem.title = item.remark
            menuItem.action = #selector(self.switchServer(_:))
            menuItem.target = nil
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
