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
    @IBOutlet weak var stateMenu: NSMenu!
    
    class MyClass : NSObject {
        var id: Int = 0
        var name: String = ""
        
        override init() {
            super.init()
        }
        
        init(id: Int, name: String) {
            self.id = id
            self.name = name
        }
    }
    
    var myArray: Array<MyClass>!
    
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    
    let configWindow = ConfigWindow()
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
        if let obj = sender.representedObject {
            if obj is MyClass {
                let myItem = obj as! MyClass
                NSLog("id: \(myItem.id), name: \(myItem.name)")
            }
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
    
    // server list items
    @IBOutlet weak var serverItems: NSMenuItem!
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
        
        if let button = statusItem.button {
            button.image = NSImage(named:NSImage.Name("TrayIcon"))
        }
        
        // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
        self.myArray = Array<MyClass>()
        self.myArray.append(MyClass(id: 1, name: "a"))
        self.myArray.append(MyClass(id: 2, name: "b"))
        self.myArray.append(MyClass(id: 3, name: "c"))

        for myItem in self.myArray {
            let menuItem : NSMenuItem = NSMenuItem()
            menuItem.title = myItem.name
            menuItem.action = #selector(AppDelegate.switchServer(_:))
            menuItem.target = nil
            menuItem.representedObject = myItem
            menuItem.target = self
            menuItem.isEnabled = true
            serverItems.submenu?.addItem(menuItem)
        }
        
        statusItem.menu = stateMenu
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
}


