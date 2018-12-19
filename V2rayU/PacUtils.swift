//
// Created by yanue on 2018/12/13.
// Copyright (c) 2018 yanue. All rights reserved.
// copy from ShadowsocksX-NG PACUtils.swift
//


import Foundation
import Alamofire


let PACRulesDirPath = AppResourcesPath + "/pac/"
let PACUserRuleFilePath = PACRulesDirPath + "user-rule.txt"
let PACFilePath = PACRulesDirPath + "pac.js"
let PACUrl = "http://127.0.0.1:" + String(httpServerPort) + "/pac/pac.js"
let PACAbpFile = PACRulesDirPath + "abp.js"
let GFWListFilePath = PACRulesDirPath + "gfwlist.txt"
let GFWListURL = "https://raw.githubusercontent.com/gfwlist/gfwlist/master/gfwlist.txt"

// Because of LocalSocks5.ListenPort may be changed
func GeneratePACFile() -> Bool {
    print("GeneratePACFile")
    let socks5Address = "127.0.0.1"

    let v2ray = V2rayServer.loadSelectedItem()
    var sockPort = "1080"
    if v2ray != nil && v2ray!.isValid {
        let cfg = V2rayConfig()
        cfg.parseJson(jsonText: v2ray!.json)
        sockPort = cfg.socksPort
    }

    // permission
    _ = shell(launchPath: "/bin/bash", arguments: ["-c", "cd " + AppResourcesPath + " && /bin/chmod -R 755 ./pac"])

    do {
        let gfwlist = try String(contentsOfFile: GFWListFilePath, encoding: String.Encoding.utf8)
        if let data = Data(base64Encoded: gfwlist, options: .ignoreUnknownCharacters) {
            let str = String(data: data, encoding: String.Encoding.utf8)
            var lines = str!.components(separatedBy: CharacterSet.newlines)

            do {
                let userRuleStr = try String(contentsOfFile: PACUserRuleFilePath, encoding: String.Encoding.utf8)
                let userRuleLines = userRuleStr.components(separatedBy: CharacterSet.newlines)

                lines = userRuleLines + lines
            } catch {
                NSLog("Not found user-rule.txt")
            }

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
                let jsData = try? Data(contentsOf: URL.init(fileURLWithPath: PACAbpFile))
                var jsStr = String(data: jsData!, encoding: String.Encoding.utf8)

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

                // Write the pac js to file.
                try jsStr!.data(using: String.Encoding.utf8)?.write(to: URL(fileURLWithPath: PACFilePath), options: .atomic)
                return true
            } catch {

            }
        }

    } catch {
        NSLog("Not found gfwlist.txt")
    }
    return false
}

func UpdatePACFromGFWList() {
    // Make the dir if rulesDirPath is not exesited.
    if !FileManager.default.fileExists(atPath: PACRulesDirPath) {
        do {
            try FileManager.default.createDirectory(atPath: PACRulesDirPath
                    , withIntermediateDirectories: true, attributes: nil)
        } catch {
        }
    }

    Alamofire.request(GFWListURL).responseString {
        response in
        if response.result.isSuccess {
            if let v = response.result.value {
                do {
                    try v.write(toFile: GFWListFilePath, atomically: true, encoding: String.Encoding.utf8)

                    if GeneratePACFile() {
                        // Popup a user notification
                        let notification = NSUserNotification()
                        notification.title = "PAC has been updated by latest GFW List."
                        NSUserNotificationCenter.default.deliver(notification)
                    }
                } catch {

                }
            }
        } else {
            // Popup a user notification
            let notification = NSUserNotification()
            notification.title = "Failed to download latest GFW List."
            NSUserNotificationCenter.default.deliver(notification)
        }
    }
}
