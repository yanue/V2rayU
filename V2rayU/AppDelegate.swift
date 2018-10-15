//
//  AppDelegate.swift
//  V2rayU
//
//  Created by yanue on 2018/10/9.
//  Copyright © 2018 yanue. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    // bar menu
    @IBOutlet weak var stateMenu: NSMenu!
    // server list items
    @IBOutlet weak var serverItems: NSMenuItem!
    
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    let configWindow = ConfigWindowController()
    let aboutWindow = AboutWindow()

    @IBAction func quitClicked(_ sender: NSMenuItem) {
        NSApplication.shared.terminate(self)
    }
    
    @IBAction func openHelp(_ sender: NSMenuItem) {
        if let url = URL(string: "https://www.google.com"),NSWorkspace.shared.open(url) {
        }
    }
    
    // switch server
    @IBAction func switchServer(_ sender: NSMenuItem) {
        print("switchServer")
        if let obj = sender.representedObject {
            print(obj)
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
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
        
        // v2ray-core check version
        V2rayCore().checkVersion()

        // load server list
        V2rayServer.loadConfig()
        let list  = V2rayServer.list()
        self.showServers(list:list)
        
        if let button = statusItem.button {
            button.image = NSImage(named:NSImage.Name("TrayIcon"))
        }
        
        statusItem.menu = stateMenu
    }
    
    func showServers(list:[v2rayItem]) {
        // reomve old items
        serverItems.submenu?.removeAllItems()
        
        // add new
        for item in list {
            let menuItem : NSMenuItem = NSMenuItem()
            menuItem.title = item.remark
            menuItem.action = #selector(AppDelegate.switchServer(_:))
            menuItem.target = nil
            menuItem.representedObject = item.remark
            menuItem.target = self
            menuItem.isEnabled = true
            serverItems.submenu?.addItem(menuItem)
        }
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
}


