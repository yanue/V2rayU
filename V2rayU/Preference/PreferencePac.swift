//
//  Preferences.swift
//  V2rayU
//
//  Created by yanue on 2018/10/19.
//  Copyright © 2018 yanue. All rights reserved.
//

import Alamofire
import Cocoa
import Preferences

let PACRulesDirPath = AppHomePath + "/pac/"
let PACUserRuleFilePath = PACRulesDirPath + "user-rule.txt"
let PACFilePath = AppHomePath + "/proxy.js"
let PACAbpFile = PACRulesDirPath + "abp.js"
let GFWListFilePath = PACRulesDirPath + "gfwlist.txt"
let GFWListURL = "https://raw.githubusercontent.com/gfwlist/gfwlist/master/gfwlist.txt"

final class PreferencePacViewController: NSViewController, PreferencePane {
    let preferencePaneIdentifier = PreferencePane.Identifier.pacTab
    let preferencePaneTitle = "Pac"
    let toolbarItemIcon = NSImage(named: NSImage.bookmarksTemplateName)!

    @IBOutlet var tips: NSTextField!

    override var nibName: NSNib.Name? {
        return "PreferencePac"
    }

    @IBOutlet var gfwPacListUrl: NSTextField!
    @IBOutlet var userRulesView: NSTextView!

    override func viewDidLoad() {
        super.viewDidLoad()
        // fix: https://github.com/sindresorhus/Preferences/issues/31
        preferredContentSize = NSMakeSize(view.frame.size.width, view.frame.size.height)
        tips.stringValue = ""

        let gfwUrl = UserDefaults.get(forKey: .gfwPacListUrl)
        if gfwUrl != nil {
            gfwPacListUrl.stringValue = gfwUrl!
        } else {
            gfwPacListUrl.stringValue = GFWListURL
        }
        userRulesView.string = getPacUserRules()
    }

    @IBAction func viewPacFile(_ sender: Any) {
        var pacUrl = getPacUrl()
        print("viewPacFile PACUrl", pacUrl)
        guard let url = URL(string: pacUrl) else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    @IBAction func updatePac(_ sender: Any) {
        tips.stringValue = "Updating Pac Rules ..."

        if let str = userRulesView?.string {
            do {
                // save user rules into file
                print("user-rules", str)
                try str.write(toFile: PACUserRuleFilePath, atomically: true, encoding: .utf8)

                UpdatePACFromGFWList(gfwPacListUrl: gfwPacListUrl.stringValue)

                if GeneratePACFile(rewrite: true) {
                    // Popup a user notification
                    tips.stringValue = "PAC has been updated by User Rules."
                } else {
                    tips.stringValue = "It's failed to update PAC by User Rules."
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    // your code here
                    self.tips.stringValue = ""
                }
            } catch {
                NSLog("updatePac error \(error)")
            }
        }
    }

    func UpdatePACFromGFWList(gfwPacListUrl: String) {
        // Make the dir if rulesDirPath is not exesited.
        if !FileManager.default.fileExists(atPath: PACRulesDirPath) {
            do {
                try FileManager.default.createDirectory(atPath: PACRulesDirPath, withIntermediateDirectories: true, attributes: nil)
            } catch {
            }
        }

        let proxyHost = "127.0.0.1"
        let proxyPort = UserDefaults.get(forKey: .localHttpPort) ?? "1087"

        // Create a URLSessionConfiguration with proxy settings
        let configuration = URLSessionConfiguration.default
        configuration.connectionProxyDictionary = [
            kCFNetworkProxiesHTTPEnable as AnyHashable: true,
            kCFNetworkProxiesHTTPProxy as AnyHashable: proxyHost,
            kCFNetworkProxiesHTTPPort as AnyHashable: proxyPort,
            kCFNetworkProxiesHTTPSEnable as AnyHashable: true,
            kCFNetworkProxiesHTTPSProxy as AnyHashable: proxyHost,
            kCFNetworkProxiesHTTPSPort as AnyHashable: proxyPort,
        ]
        configuration.timeoutIntervalForRequest = 30 // Set your desired timeout interval in seconds

        // url request by DispatchGroup wait
//        let session = URLSession(configuration: configuration)
//        let task = session.dataTask(with: URLRequest(url: url)) { data, _, error in
//            if let error = error {
//                // Handle HTTP request error
//                print("error", error)
//
//            } else if let data = data {
//                // Handle HTTP request response
//                print("data", data)
//            } else {
//                // Handle unexpected error
//                print("unexpected \(error)")
//            }
//        }
        print("configuration \(configuration.description)")
        let session = Alamofire.SessionManager(configuration: configuration)
        session.request(gfwPacListUrl).responseString { response in
            if response.result.isSuccess {
                if let v = response.result.value {
                    do {
                        try v.write(toFile: GFWListFilePath, atomically: true, encoding: String.Encoding.utf8)
                        
                        self.tips.stringValue = "gfwList has been updated"
                        NSLog("\(self.tips.stringValue)")

                        // save to UserDefaults
                        UserDefaults.set(forKey: .gfwPacListUrl, value: gfwPacListUrl)

                        if GeneratePACFile(rewrite: true) {
                            // Popup a user notification
                            self.tips.stringValue = "PAC has been updated by latest GFW List."
                            NSLog("\(self.tips.stringValue)")
                        }
                    } catch {
                        // Popup a user notification
                        self.tips.stringValue = "Failed to Write latest GFW List."
                        NSLog("\(self.tips.stringValue)")
                    }
                }
            } else {
                // Popup a user notification
                self.tips.stringValue = "Failed to download latest GFW List."
                
                let sockPort = UserDefaults.get(forKey: .localSockPort) ?? "1080"
                let curlCmd = "cd " + PACRulesDirPath + " && /usr/bin/curl -o gfwlist.txt \(gfwPacListUrl) -x socks5://127.0.0.1:\(sockPort)"
                NSLog("curlCmd: \(curlCmd)")
                let msg = shell(launchPath: "/bin/bash", arguments: ["-c", curlCmd])
                NSLog("curl result: \(msg)")
                if GeneratePACFile(rewrite: true) {
                    // Popup a user notification
                    self.tips.stringValue = "PAC has been updated by latest GFW List."
                }
            }
        }
    }
}

// Because of LocalSocks5.ListenPort may be changed
func GeneratePACFile(rewrite: Bool) -> Bool {
    let socks5Address = "127.0.0.1"

    let sockPort = UserDefaults.get(forKey: .localSockPort) ?? "1080"

    // permission
    _ = shell(launchPath: "/bin/bash", arguments: ["-c", "cd " + AppHomePath + " && /bin/chmod -R 755 ./pac"])

    // if PACFilePath exist and not need rewrite
    if !(rewrite || !FileManager.default.fileExists(atPath: PACFilePath)) {
        return true
    }

    print("GeneratePACFile rewrite", sockPort)
    var userRules = getPacUserRules()
    var gfwlist = getPacGFWList()
    do {
        if let data = Data(base64Encoded: gfwlist, options: .ignoreUnknownCharacters) {
            if let str = String(data: data, encoding: .utf8) {
                NSLog("base64Encoded")
                gfwlist = str
            }
            let userRuleLines = userRules.components(separatedBy: CharacterSet.newlines)
            var lines = gfwlist.components(separatedBy: CharacterSet.newlines)
            lines = userRuleLines + lines

            // Filter empty and comment lines
            lines = lines.filter({ (s: String) -> Bool in
                if s.isEmpty {
                    return false
                }
                let c = s[s.startIndex]
                if c == "!" || c == "[" {
                    return false
                }
                return true
            })

            do {
                // rule lines to json array
                let rulesJsonData: Data = try JSONSerialization.data(withJSONObject: lines, options: .prettyPrinted)
                let rulesJsonStr = String(data: rulesJsonData, encoding: String.Encoding.utf8)

                // Get raw pac js
                guard let jsData = try? Data(contentsOf: URL(fileURLWithPath: PACAbpFile)) else {
                    NSLog("Failed to Get raw pac js")
                    return false
                }
                var jsStr = String(data: jsData, encoding: String.Encoding.utf8)

                // Replace rules placeholder in pac js
                jsStr = jsStr!.replacingOccurrences(of: "__RULES__", with: rulesJsonStr!)
                // Replace __SOCKS5PORT__ palcholder in pac js
                jsStr = jsStr!.replacingOccurrences(of: "__SOCKS5PORT__", with: "\(sockPort)")
                // Replace __SOCKS5ADDR__ palcholder in pac js
                var sin6 = sockaddr_in6()
                if socks5Address.withCString({ cstring in inet_pton(AF_INET6, cstring, &sin6.sin6_addr) }) == 1 {
                    jsStr = jsStr!.replacingOccurrences(of: "__SOCKS5ADDR__", with: "[\(socks5Address)]")
                } else {
                    jsStr = jsStr!.replacingOccurrences(of: "__SOCKS5ADDR__", with: socks5Address)
                }
                print("PACFilePath", PACFilePath)

                // Write the pac js to file.
                try jsStr!.data(using: String.Encoding.utf8)?.write(to: URL(fileURLWithPath: PACFilePath), options: .atomic)
                return true
            } catch {
                print("write pac fail \(error)")
            }
        } else {
            NSLog("base64Encoded not decode")
        }
    }

    return false
}

func getPacUserRules() -> String {
    var userRuleTxt = """
    ! Put user rules line by line in this file.
    ! See https://adblockplus.org/en/filter-cheatsheet
    ||api.github.com
    ||githubusercontent.com
    ||github.io
    ||github.com
    ||chat.openai.com
    ||openai.com
    """
    do {
        let url = URL(fileURLWithPath: PACUserRuleFilePath)
        if let str = try? String(contentsOf: url, encoding: .utf8) {
            NSLog("getPacUserRules: \(PACUserRuleFilePath) \(str.count)")
            if str.count > 0 {
                userRuleTxt = str
            }
        }
    } catch {
        NSLog("getPacUserRules err \(error)")
    }
    // auto include githubusercontent.com api.github.com
    if !userRuleTxt.contains("githubusercontent.com") {
        userRuleTxt.append("\n||githubusercontent.com")
    }
    if !userRuleTxt.contains("github.io") {
        userRuleTxt.append("\n||github.io")
    }
    if !userRuleTxt.contains("api.github.com") {
        userRuleTxt.append("\n||api.github.com")
    }
    if !userRuleTxt.contains("api.github.com") {
        userRuleTxt.append("\n||api.github.com")
    }
    if !userRuleTxt.contains("openai.com") {
        userRuleTxt.append("\n||openai.com")
    }
    if !userRuleTxt.contains("chat.openai.com") {
        userRuleTxt.append("\n||chat.openai.com")
    }
    return userRuleTxt
}

func getPacGFWList() -> String {
    var gfwList = ""
    do {
        let url = URL(fileURLWithPath: GFWListFilePath)
        if let str = try? String(contentsOf: url, encoding: String.Encoding.utf8) {
            NSLog("getPacGFWList: \(GFWListFilePath) \(str.count)")
            if str.count > 0 {
                gfwList = str
            }
        }
    } catch {
        NSLog("getPacGFWList err \(error)")
    }
    return gfwList
}
