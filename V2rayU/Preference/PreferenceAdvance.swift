//
//  Preferences.swift
//  V2rayU
//
//  Created by yanue on 2018/10/19.
//  Copyright © 2018 yanue. All rights reserved.
//

import Cocoa
import Preferences

final class PreferenceAdvanceViewController: NSViewController, PreferencePane {
    let preferencePaneIdentifier = PreferencePane.Identifier.advanceTab
    let preferencePaneTitle = "Advance"
    let toolbarItemIcon = NSImage(named: NSImage.advancedName)!

    @IBOutlet weak var sockPort: NSTextField!
    @IBOutlet weak var httpPort: NSTextField!
    @IBOutlet weak var dnsServers: NSTextField!
    @IBOutlet weak var pacPort: NSTextField!
    @IBOutlet weak var enableUdp: NSButton!
    @IBOutlet weak var enableMux: NSButton!
    @IBOutlet weak var muxConcurrent: NSTextField!
    
    override var nibName: NSNib.Name? {
        return "PreferenceAdvance"
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // fix: https://github.com/sindresorhus/Preferences/issues/31
        self.preferredContentSize = NSMakeSize(self.view.frame.size.width, self.view.frame.size.height);
    }


}
