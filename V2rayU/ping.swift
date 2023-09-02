//
//  ping.swift
//  V2rayU
//
//  Created by Erick on 2019/10/30.
//  Copyright © 2019 yanue. All rights reserved.
//

import Alamofire
import SwiftyJSON

// ping and choose fastest v2ray
var inPing = false
var fastV2rayName = ""
var fastV2raySpeed = 5
let pingJsonFileName = "ping.json"
let pingJsonFilePath = AppHomePath + "/" + pingJsonFileName
var task: Process?


class PingSpeed: NSObject, URLSessionDataDelegate {
    var pingServers: [V2rayItem] = []
    var serverLen: Int = 0

    func pingAll() {
        NSLog("ping start")
        if inPing {
            NSLog("ping inPing")
            return
        }
        fastV2rayName = ""
        pingServers = []
        let itemList = V2rayServer.list()
        if itemList.count == 0 {
            return
        }
        let langStr = Locale.current.languageCode
        var pingTip: String = ""
        if UserDefaults.getBool(forKey: .autoSelectFastestServer) {
            if langStr == "en" {
                pingTip = "Ping Speed - In Testing(Choose fastest server)"
            } else {
                pingTip = "Ping Speed - 测试中(选择最快服务器)"
            }
        } else {
            if langStr == "en" {
                pingTip = "Ping Speed - In Testing "
            } else {
                pingTip = "Ping Speed - 测试中"
            }
        }
        menuController.statusMenu.item(withTag: 1)?.title = pingTip
        // in ping
        inPing = true
        serverLen = itemList.count
        for item in itemList {
            pingEachServer(item: item)
        }
        NSLog("ping done")
    }

    func pingEachServer(item: V2rayItem) {
        NSLog("ping \(item.name) - \(item.remark)")

        if !item.isValid {
            pingServers.append(item)
            return
        }
        let bindPort = findFreePort()
        print("bindPort", bindPort)
        createJsonFileForPing(item: item, bindPort: 1087)
        doPing(item: item, bindPort: bindPort)
        // print("finished",message)
        pingServers.append(item)
        refreshStatusMenu()
    }

    func refreshStatusMenu() {
        if pingServers.count == serverLen {
            inPing = false
            menuController.statusMenu.item(withTag: 1)?.title = "Ping Speed..."
            menuController.showServers()
            // reload config
            if menuController.configWindow != nil {
                menuController.configWindow.serversTableView.reloadData()
            }
        }
    }

    func createJsonFileForPing(item: V2rayItem, bindPort: UInt16) {
        var jsonText = item.json
        NSLog("bindPort: \(item.name)-\(item.remark) - \(bindPort)")
        // parse old
        let vCfg = V2rayConfig()
        vCfg.parseJson(jsonText: item.json)
        vCfg.socksPort = String(bindPort)
        vCfg.httpPort = String(bindPort)
        // combine new default config
        jsonText = vCfg.combineManual()

        do {
            let jsonFilePath = URL(fileURLWithPath: PingConfigFilePath)

            // delete before config
            if FileManager.default.fileExists(atPath: PingConfigFilePath) {
                try? FileManager.default.removeItem(at: jsonFilePath)
            }

            try jsonText.write(to: jsonFilePath, atomically: true, encoding: String.Encoding.utf8)
        } catch let error {
            // failed to write file – bad permissions, bad filename, missing permissions, or more likely it can't be converted to the encoding
            NSLog("save json file fail: \(error)")
        }
    }

    func doPing(item: V2rayItem, bindPort: UInt16) {
        NSLog("doPing: \(item.name)-\(item.remark) - \(bindPort)")
        let _shell = v2rayCorePath + " -config " + PingConfigFilePath
        print("_shell", _shell)

        self.checkProxySpent(item: item, bindPort: 1087)
//        self.checkProxySpent(item: item, bindPort: bindPort)
    }
    
    func checkProxySpent(item: V2rayItem, bindPort: UInt16) {
        // set URLSessionDataDelegate
        let metric = PingMetrics()
        metric.ping = item
        
        let proxyHost = "127.0.0.1"
        let proxyPort = bindPort

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
        configuration.timeoutIntervalForRequest = 2 // Set your desired timeout interval in seconds
        
        let session = URLSession(configuration: configuration, delegate: metric, delegateQueue: nil)
        let url = URL(string: "http://www.google.com/generate_204")!
        let task = session.dataTask(with: URLRequest(url: url))
        task.resume()
    }
}

class PingMetrics: NSObject, URLSessionDataDelegate {
    var ping: V2rayItem?

    // MARK: - URLSessionDataDelegate
    func urlSession(_ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
        if let transactionMetrics = metrics.transactionMetrics.first {
            let request = transactionMetrics.request
            let response = transactionMetrics.response
            let fetchStartDate = transactionMetrics.fetchStartDate
            let responseEndDate = transactionMetrics.responseEndDate
            // check
            if self.ping != nil && responseEndDate != nil && fetchStartDate != nil  {
                let requestDuration = responseEndDate!.timeIntervalSince(fetchStartDate!)
                let pingTs = Int(requestDuration*100)
                print("fetchStartDate=\(fetchStartDate) responseEndDate=\(responseEndDate) requestDuration=\(requestDuration) pingTs=\(pingTs)")
                // update ping speed
                self.ping!.speed = String(format: "%d", pingTs) + "ms"
                self.ping!.store()
            }
        }
    }
}
