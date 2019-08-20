//
// Created by yanue on 2018/12/13.
// Copyright (c) 2018 yanue. All rights reserved.
// copy from shadowsocksX-NG
//

import Cocoa
import Cocoa

class UserRulesWindowController: NSWindowController {

    @IBOutlet var userRulesView: NSTextView!

    override var windowNibName: String? {
        return "UserRulesWindow" // no extension .xib here
    }

    override func windowDidLoad() {
        super.windowDidLoad()

        // read userRules from UserDefaults
        let txt = UserDefaults.get(forKey: .userRules)
        if txt != nil {
            userRulesView.string = txt!
        } else {
            let str = try? String(contentsOfFile: PACUserRuleFilePath, encoding: String.Encoding.utf8)
            userRulesView.string = str!
        }
    }

    @IBAction func didCancel(_ sender: AnyObject) {
        window?.performClose(self)
    }

    @IBAction func didOK(_ sender: AnyObject) {
        if let str = userRulesView?.string {
            do {
                // save user rules into UserDefaults
                UserDefaults.set(forKey: .userRules, value: str)

                try str.data(using: String.Encoding.utf8)?.write(to: URL(fileURLWithPath: PACUserRuleFilePath), options: .atomic)

                if GeneratePACFile() {
                    // Popup a user notification
                    let notification = NSUserNotification()
                    notification.title = "PAC has been updated by User Rules."
                    NSUserNotificationCenter.default.deliver(notification)
                } else {
                    let notification = NSUserNotification()
                    notification.title = "It's failed to update PAC by User Rules."
                    NSUserNotificationCenter.default.deliver(notification)
                }
            } catch {
            }
        }
        window?.performClose(self)
    }
}
