//
//  Preferences.swift
//  V2rayU
//
//  Created by yanue on 2018/10/19.
//  Copyright © 2018 yanue. All rights reserved.
//

import Cocoa
import Preferences
import JavaScriptCore


final class PreferenceDnsViewController: NSViewController, PreferencePane {
    let preferencePaneIdentifier = PreferencePane.Identifier.dnsTab
    let preferencePaneTitle = "Dns"
    let toolbarItemIcon = NSImage(named: NSImage.multipleDocumentsName)!

    @IBOutlet weak var tips: NSTextField!
    @IBOutlet weak var saveBtn: NSButtonCell!

    override var nibName: NSNib.Name? {
        return "PreferenceDns"
    }

    @IBOutlet var dnsJson: NSTextView!

    override func viewDidLoad() {
        super.viewDidLoad()
        // fix: https://github.com/sindresorhus/Preferences/issues/31
        self.preferredContentSize = NSMakeSize(self.view.frame.size.width, self.view.frame.size.height);
        self.tips.stringValue = ""
        self.dnsJson.string = UserDefaults.get(forKey: .v2rayDnsJson) ?? "{}"
        self.saveBtn.state = .on
    }

    @IBAction func save(_ sender: Any) {
        self.tips.stringValue = "save success"
        self.saveBtn.state = .on

        if var str = dnsJson?.string {
            if let context = JSContext() {
                context.evaluateScript(jsSourceFormatConfig)
                // call js func
                if let formatFunction = context.objectForKeyedSubscript("JsonBeautyFormat") {
                    if let result = formatFunction.call(withArguments: [str.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) as Any]) {
                        // error occurred with prefix "error:"
                        if let reStr = result.toString(), reStr.count > 0 {
                            if !reStr.hasPrefix("error:") {
                                str = reStr

                                // save user rules into UserDefaults
                                UserDefaults.set(forKey: .v2rayDnsJson, value: str)

                                // replace
                                v2rayConfig.dnsJson = str

                                // set current server item and reload v2ray-core
                                regenerateAllConfig()

                                self.dnsJson.string = reStr
                            } else {
                                self.tips.stringValue = reStr
                            }
                        }
                    }
                }
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                // your code here
                self.tips.stringValue = ""
            }
        }
    }

    @IBAction func goHelp(_ sender: Any) {
        guard let url = URL(string: "https://guide.v2fly.org/basics/dns.html") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    @IBAction func goViewConfig(_ sender: Any) {
        let confUrl = PACUrl.replacingOccurrences(of: "pac/proxy.js", with: "config.json")
        guard let url = URL(string: confUrl) else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}
