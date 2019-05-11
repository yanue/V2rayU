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

final class PreferenceGeneralViewController: NSViewController, PreferencePane {
    let preferencePaneIdentifier = PreferencePane.Identifier.generalTab
    let preferencePaneTitle = "General"
    let toolbarItemIcon = NSImage(named: NSImage.preferencesGeneralName)!

    override var nibName: NSNib.Name? {
        return "PreferenceGeneral"
    }

    @IBOutlet weak var autoLaunch: NSButtonCell!
    @IBOutlet weak var autoCheckVersion: NSButtonCell!

    override func viewDidLoad() {
        super.viewDidLoad()
        // fix: https://github.com/sindresorhus/Preferences/issues/31
        self.preferredContentSize = NSMakeSize(self.view.frame.size.width, self.view.frame.size.height);

        let autoLaunchState = UserDefaults.getBool(forKey: .autoLaunch)
        let autoCheckVersionState = UserDefaults.getBool(forKey: .autoCheckVersion)
        if autoLaunchState {
            autoLaunch.state = .on
        }
        if autoCheckVersionState {
            autoCheckVersion.state = .on
        }
    }

    @IBAction func SetAutoLogin(_ sender: NSButtonCell) {
        SMLoginItemSetEnabled(launcherAppIdentifier as CFString, sender.state == .on)
        UserDefaults.setBool(forKey: .autoLaunch, value: sender.state == .on)
    }

    @IBAction func SetAutoCheckVersion(_ sender: NSButtonCell) {
        UserDefaults.setBool(forKey: .autoCheckVersion, value: sender.state == .on)
    }

    @IBAction func goWebsite(_ sender: NSButton) {
        guard let url = URL(string: "https://yanue.github.io/V2rayU/") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    @IBAction func goV2ray(_ sender: NSButton) {
        guard let url = URL(string: "https://github.com/v2ray/v2ray-core") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    @IBAction func goFeedback(_ sender: NSButton) {
        guard let url = URL(string: "https://github.com/yanue/v2rayu/issues") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    @IBAction func checkVersion(_ sender: NSButton) {
        // need set SUFeedURL into plist
        V2rayUpdater.checkForUpdates(sender)
    }
}
