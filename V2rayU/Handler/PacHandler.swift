//
//  PacHandler.swift
//  V2rayU
//
//  Created by yanue on 2025/7/21.
//

import Foundation

let PACRulesDirPath = AppHomePath + "/pac/"
let PACUserRuleFilePath = PACRulesDirPath + "user-rule.txt"
let PACFilePath = AppHomePath + "/proxy.js"
let PACAbpFile = PACRulesDirPath + "abp.js"
let GFWListFilePath = PACRulesDirPath + "gfwlist.txt"
let GFWListURL = "https://raw.githubusercontent.com/gfwlist/gfwlist/master/gfwlist.txt"


func getPacUrl() -> String {
    let pacUrl = "http://127.0.0.1:" + String(getPacPort()) + "/proxy.js"
    return pacUrl
}

func getConfigUrl() -> String {
    let configUrl = "http://127.0.0.1:" + String(getPacPort()) + "/config.json"
    return configUrl
}

// Because of LocalSocks5.ListenPort may be changed
func GeneratePACFile(rewrite: Bool) -> Bool {
    let socksPort = String(getPacPort())
    let pacAddress = getPacAddress()
    
    // permission
    _ = shell(launchPath: "/bin/bash", arguments: ["-c", "cd " + AppHomePath + " && /bin/chmod -R 755 ./pac"])

    // if PACFilePath exist and not need rewrite
    if !(rewrite || !FileManager.default.fileExists(atPath: PACFilePath)) {
        return true
    }

    logger.info("GeneratePACFile rewrite", pacAddress, socksPort)
    let userRules = getPacUserRules()
    var gfwlist = getPacGFWList()
    do {
        if let data = Data(base64Encoded: gfwlist, options: .ignoreUnknownCharacters) {
            if let str = String(data: data, encoding: .utf8) {
                logger.info("base64Encoded")
                gfwlist = str
            }
            let userRuleLines = userRules.components(separatedBy: CharacterSet.newlines)
            var lines = gfwlist.components(separatedBy: CharacterSet.newlines)

            // 应先 userRules 后 gfwlist(匹配到就退出,短路逻辑)
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
                guard let rulesJsonStr = String(data: rulesJsonData, encoding: String.Encoding.utf8) else {
                    logger.info("Failed to Get rulesJsonData")
                    return false
                }

                // Get raw pac js
                guard let jsData = try? Data(contentsOf: URL(fileURLWithPath: PACAbpFile)) else {
                    logger.info("Failed to Get raw pac js")
                    return false
                }
                guard var jsStr = String(data: jsData, encoding: String.Encoding.utf8) else {
                    logger.info("Failed to Get js str")
                    return false
                }

                // Replace rules placeholder in pac js
                jsStr = jsStr.replacingOccurrences(of: "__RULES__", with: rulesJsonStr)
                // Replace __SOCKS5PORT__ palcholder in pac js
                jsStr = jsStr.replacingOccurrences(of: "__SOCKS5PORT__", with: "\(socksPort)")
                // Replace __SOCKS5ADDR__ palcholder in pac js
                var sin6 = sockaddr_in6()
                if pacAddress.withCString({ cstring in inet_pton(AF_INET6, cstring, &sin6.sin6_addr) }) == 1 {
                    jsStr = jsStr.replacingOccurrences(of: "__SOCKS5ADDR__", with: "[\(pacAddress)]")
                } else {
                    jsStr = jsStr.replacingOccurrences(of: "__SOCKS5ADDR__", with: pacAddress)
                }
                logger.info("PACFilePath", PACFilePath)

                // Write the pac js to file.
                try jsStr.data(using: String.Encoding.utf8)?.write(to: URL(fileURLWithPath: PACFilePath), options: .atomic)
                return true
            } catch {
                logger.info("write pac fail \(error)")
            }
        } else {
            logger.info("base64Encoded not decode")
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
    ||chatgpt.com
    """
    do {
        let url = URL(fileURLWithPath: PACUserRuleFilePath)
        if let str = try? String(contentsOf: url, encoding: .utf8) {
            logger.info("getPacUserRules: \(PACUserRuleFilePath) \(str.count)")
            if str.count > 0 {
                userRuleTxt = str
            }
        }
    } catch {
        logger.info("getPacUserRules err \(error)")
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
    if !userRuleTxt.contains("openai.com") {
        userRuleTxt.append("\n||openai.com")
    }
    if !userRuleTxt.contains("chat.openai.com") {
        userRuleTxt.append("\n||chat.openai.com")
    }
    if !userRuleTxt.contains("chatgpt.com") {
        userRuleTxt.append("\n||chatgpt.com")
    }
    return userRuleTxt
}

func getPacGFWList() -> String {
    var gfwList = ""
    do {
        let url = URL(fileURLWithPath: GFWListFilePath)
        if let str = try? String(contentsOf: url, encoding: String.Encoding.utf8) {
            logger.info("getPacGFWList: \(GFWListFilePath) \(str.count)")
            if str.count > 0 {
                gfwList = str
            }
        }
    } catch {
        logger.info("getPacGFWList err \(error)")
    }
    return gfwList
}
