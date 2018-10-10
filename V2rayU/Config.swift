//
//  ConfigWindowController.swift
//  V2rayU
//
//  Created by yanue on 2018/10/9.
//  Copyright © 2018 yanue. All rights reserved.
//

import Cocoa

class ConfigWindow: NSWindowController,NSWindowDelegate {
    override var windowNibName: String? {
        return "Config" // no extension .xib here
    }

    override func windowDidLoad() {
        super.windowDidLoad()
    }
    
    func windowWillClose(_ notification: Notification) {
        // hide dock icon and close all opened windows
        NSApp.setActivationPolicy(.accessory)
    }
}
