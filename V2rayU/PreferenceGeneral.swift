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

final class PreferenceGeneralViewController: NSViewController, Preferenceable {
    let toolbarItemTitle = "General"
    let toolbarItemIcon = NSImage(named: NSImage.preferencesGeneralName)!
    
    @IBOutlet weak var CopyrightLabel: NSTextField!
   
    @IBOutlet weak var VersionLabel: NSTextField!
    
    @IBOutlet weak var V2rayCoreVersion: NSTextField!
    
    override var nibName: NSNib.Name? {
        return "PreferenceGeneral"
    }

    @IBOutlet weak var autoLaunch: NSButtonCell!
    @IBOutlet weak var autoCheckVersion: NSButtonCell!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"]  {
            self.VersionLabel.stringValue = "version "+(version as? String ?? "1.0")
        }

        if let v2rayCoreVersion = UserDefaults.get(forKey: .v2rayCoreVersion)  {
            self.V2rayCoreVersion.stringValue = "based on v2ray-core "+v2rayCoreVersion
        }

        let autoLaunchState = UserDefaults.getBool(forKey: .autoLaunch)
        let autoCheckVersionState = UserDefaults.getBool(forKey: .autoCheckVersion)
        if autoLaunchState {
            autoLaunch.state = .on
        }
        if autoCheckVersionState {
            autoCheckVersion.state = .on
        }
        
        // Setup stuff here
    }
    
    @IBAction func SetAutoLogin(_ sender: NSButtonCell) {
        print("SetAutoLogin")

        SMLoginItemSetEnabled(launcherAppIdentifier as CFString, sender.state == .on)
        UserDefaults.setBool(forKey: .autoLaunch, value: sender.state == .on)
    }
    
    @IBAction func SetAutoCheckVersion(_ sender: NSButtonCell) {
        print("SetAutoCheckVersion")
        UserDefaults.setBool(forKey: .autoCheckVersion, value: sender.state == .on)
    }
    
    @IBAction func goWebsite(_ sender: NSButton) {
        print("goWebsite")
        guard let url = URL(string: "https://yanue.github.io/V2rayU/") else { return }
        NSWorkspace.shared.open(url)
    }
    
    @IBAction func goV2ray(_ sender: NSButton) {
        print("goV2ray")

        guard let url = URL(string: "https://github.com/v2ray/v2ray-core") else { return }
        NSWorkspace.shared.open(url)
    }
    
    @IBAction func goFeedback(_ sender: NSButton) {
        guard let url = URL(string: "https://github.com/yanue/v2rayu/issues") else { return }
        NSWorkspace.shared.open(url)
    }
    
    @IBAction func checkVersion(_ sender: NSButton) {
        print("checkVersion")
    }
}

class LinkButton: NSButton {
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override func resetCursorRects() {
        addCursorRect(self.bounds, cursor: .pointingHand)
    }
}
