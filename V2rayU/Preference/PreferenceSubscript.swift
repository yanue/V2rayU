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
//    let toolbarItemIcon = NSImage(named: NSImage.multipleDocumentsName)!
    let toolbarItemIcon = NSImage(named: NSImage.userAccountsName)!

    override var nibName: NSNib.Name? {
        return "PreferenceSubscript"
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // fix: https://github.com/sindresorhus/Preferences/issues/31
        self.preferredContentSize = NSMakeSize(self.view.frame.size.width, self.view.frame.size.height);
    }
}
