//
//  Preferences.swift
//  V2rayU
//
//  Created by yanue on 2018/10/19.
//  Copyright © 2018 yanue. All rights reserved.
//

import Foundation
import Preferences
import ServiceManagement
import Sparkle

final class PreferenceSubscriptViewController: NSViewController, PreferencePane {
    let preferencePaneIdentifier = PreferencePane.Identifier.subscriptTab
    let preferencePaneTitle = "Subscript"
    let toolbarItemIcon = NSImage(named: NSImage.advancedName)!

    override var nibName: NSNib.Name? {
        return "PreferenceSubscript"
    }

    override func viewDidLoad() {
        super.viewDidLoad()
    }
}
