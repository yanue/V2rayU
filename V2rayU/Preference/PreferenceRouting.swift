//
//  Preferences.swift
//  V2rayU
//
//  Created by yanue on 2018/10/19.
//  Copyright © 2018 yanue. All rights reserved.
//

import Cocoa
import Preferences

final class PreferenceRoutingViewController: NSViewController, PreferencePane {

    let preferencePaneIdentifier = PreferencePane.Identifier.routingTab
    let preferencePaneTitle = "Routing"
    let toolbarItemIcon = NSImage(named: NSImage.networkName)!
    
    @IBOutlet weak var domainStrategy: NSPopUpButton!
    @IBOutlet weak var routingRule: NSPopUpButton!
    @IBOutlet var proxyTextView: NSTextView!
    @IBOutlet var directTextView: NSTextView!
    @IBOutlet var blockTextView: NSTextView!

    override var nibName: NSNib.Name? {
        return "PreferenceRouting"
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // fix: https://github.com/sindresorhus/Preferences/issues/31
        self.preferredContentSize = NSMakeSize(self.view.frame.size.width, self.view.frame.size.height);
        
    }
    
    @IBAction func goHelp(_ sender: Any) {
    }
    
    @IBAction func saveRouting(_ sender: Any) {
    }
}
