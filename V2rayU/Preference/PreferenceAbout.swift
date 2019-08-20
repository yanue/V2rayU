//
//  Preferences.swift
//  V2rayU
//
//  Created by yanue on 2018/10/19.
//  Copyright © 2018 yanue. All rights reserved.
//

import Cocoa
import Preferences

final class PreferenceAboutViewController: NSViewController, PreferencePane {
    let preferencePaneIdentifier = PreferencePane.Identifier.aboutTab
    let preferencePaneTitle = "About"
    let toolbarItemIcon = NSImage(named: NSImage.infoName)!
    
    @IBOutlet weak var VersionLabel: NSTextField!
    @IBOutlet weak var V2rayCoreVersion: NSTextField!
    
    override var nibName: NSNib.Name? {
        return "PreferenceAbout"
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // fix: https://github.com/sindresorhus/Preferences/issues/31
        self.preferredContentSize = NSMakeSize(self.view.frame.size.width, self.view.frame.size.height);
        
        self.VersionLabel.stringValue = "Version " + appVersion

        if let v2rayCoreVersion = UserDefaults.get(forKey: .v2rayCoreVersion) {
            self.V2rayCoreVersion.stringValue = "based on v2ray-core " + v2rayCoreVersion
        }
    }
}
