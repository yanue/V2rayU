//
//  Preferences.swift
//  V2rayU
//
//  Created by yanue on 2018/10/19.
//  Copyright © 2018 yanue. All rights reserved.
//

import Foundation
import Preferences

final class AboutPreferenceViewController: NSViewController, Preferenceable {
//    let toolbarItemIcon = NSImage(named: NSImage.preferencesGeneralName)!

    let toolbarItemTitle = "About"
    var toolbarItemIcon : NSImage {
        get { return #imageLiteral(resourceName: "vx64") }
    }
    
    override var nibName: NSNib.Name? {
        return "PreferenceAbout"
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Setup stuff here
    }
}
