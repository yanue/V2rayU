//
//  Preferences.swift
//  V2rayU
//
//  Created by yanue on 2018/10/19.
//  Copyright © 2018 yanue. All rights reserved.
//

import Cocoa
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
    @IBOutlet weak var autoClearLog: NSButtonCell!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // fix: https://github.com/sindresorhus/Preferences/issues/31
        self.preferredContentSize = NSMakeSize(self.view.frame.size.width, self.view.frame.size.height);

        let autoLaunchState = UserDefaults.getBool(forKey: .autoLaunch)
        let autoCheckVersionState = UserDefaults.getBool(forKey: .autoCheckVersion)
        let autoClearLogState = UserDefaults.getBool(forKey: .autoClearLog)
        if autoLaunchState {
            autoLaunch.state = .on
        }
        if autoCheckVersionState {
            autoCheckVersion.state = .on
        }
        if autoClearLogState {
            autoClearLog.state = .on
        }
    }

    @IBAction func SetAutoLogin(_ sender: NSButtonCell) {
        SMLoginItemSetEnabled(launcherAppIdentifier as CFString, sender.state == .on)
        UserDefaults.setBool(forKey: .autoLaunch, value: sender.state == .on)
    }

    @IBAction func SetAutoCheckVersion(_ sender: NSButtonCell) {
        UserDefaults.setBool(forKey: .autoCheckVersion, value: sender.state == .on)
    }

    @IBAction func SetAutoClearLogs(_ sender: NSButtonCell) {
        UserDefaults.setBool(forKey: .autoClearLog, value: sender.state == .on)
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
    
    @IBAction func openLogs(_ sender: NSButton) {
        V2rayLaunch.OpenLogs()
    }
    
    @IBAction func clearLogs(_ sender: NSButton) {
        V2rayLaunch.ClearLogs()
    }
}
