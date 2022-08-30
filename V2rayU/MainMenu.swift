//
//  MainMenu.swift
//  V2rayU
//
//  Created by yanue on 2022/8/26.

import Cocoa
import SwiftUI

// This is our custom menu that will appear when users
// click on the menu bar icon
class MainMenu: NSObject {
    // A new menu instance ready to add items to
    let menu = NSMenu()
    // These are the available links shown in the menu
    // These are fetched from the Info.plist file
    let menuItems = Bundle.main.object(forInfoDictionaryKey: "Links") as! [String: String]
    
    // function called by V2rayUApp to create the menu
    func build() -> NSMenu {
        // todo custom view
        
        // Adding a seperator
        menu.addItem(NSMenuItem.separator())
        
        // We add an About pane.
        let aboutMenuItem = NSMenuItem(
            title: "About V2rayU",
            action: #selector(about),
            keyEquivalent: ""
        )
        // This is important so that our #selector
        // targets the `about` func in this file
        aboutMenuItem.target = self
        
        // This is where we actually add our about item to the menu
        menu.addItem(aboutMenuItem)
        
        // Adding a seperator
        menu.addItem(NSMenuItem.separator())
        
        // Loop though our sorted link list and create a new menu item for
        // each, and then add it to the menu
        for (title, link) in menuItems.sorted( by: { $0.0 < $1.0 }) {
            let menuItem = NSMenuItem(
                title: title,
                action: #selector(goLink),
                keyEquivalent: ""
            )
            menuItem.target = self
            menuItem.representedObject = link
            
            menu.addItem(menuItem)
        }
        
        // Adding a seperator
        menu.addItem(NSMenuItem.separator())
        
        // Adding a quit menu item
        let quitMenuItem = NSMenuItem(
            title: "Quit V2rayU",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitMenuItem.target = self
        menu.addItem(quitMenuItem)
        
        
        // Adding a quit menu item
        let cfgMenuItem = NSMenuItem(
            title: "configure...",
            action: #selector(show),
            keyEquivalent: "c"
        )
        cfgMenuItem.target = self
        menu.addItem(cfgMenuItem)
        
        return menu
    }
    
    // The selector that takes a link and opens it
    // in your default browser
    @objc func goLink(sender: NSMenuItem) {
        let link = sender.representedObject as! String
        guard let url = URL(string: link) else { return }
        NSWorkspace.shared.open(url)
    }
    
    @objc func about(sender: NSMenuItem) {
        NSApplication.shared.orderFrontStandardAboutPanel( options: [
            NSApplication.AboutPanelOptionKey.applicationIcon:  NSImage(named: NSImage.Name("V2rayU")) as Any,
            NSApplication.AboutPanelOptionKey.credits: NSAttributedString(
                string: "https://github.com/yanue/V2rayU.git",
                attributes: [
                    NSAttributedString.Key.font: NSFont.boldSystemFont(
                        ofSize: NSFont.smallSystemFontSize)
                ]
            ),
            NSApplication.AboutPanelOptionKey(
                rawValue: "Copyright"
            ): "Copyright 2022 © YANUE. all right reserved"
        ])
    }
        
    // The selector that quits the app
    @objc func quit(sender: NSMenuItem) {
        NSApp.terminate(self)
    }
    
    
    @objc func show(sender: NSMenuItem) {
        WinHelper.mainView.open()
    }
    
}
