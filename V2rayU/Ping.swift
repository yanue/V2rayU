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
        // use thread
        let thread = Thread {
            // ping
            self.serverLen = itemList.count
            for item in itemList {
                // run ping by sync queue
                self.pingEachServer(item: item)
            }
            // refresh menu
            self.refreshStatusMenu()
            NSLog("ping done")
        }
        thread.name = "pingThread"
        thread.threadPriority = 1 /// 优先级
        thread.start()
    }

    func pingEachServer(item: V2rayItem) {
        NSLog("ping \(item.name) - \(item.remark)")

        if !item.isValid {
            pingServers.append(item)
            return
        }
        // ping
        doPing(item: item)
        // print("finished",message)
        pingServers.append(item)
        // refresh menu
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

    func doPing(item: V2rayItem) {
        let (_, bindPort) = getUsablePort(port: 11081)

        NSLog("doPing: \(item.name)-\(item.remark) - \(bindPort)")
        let jsonFile = AppHomePath + "/config_ping.json"

        // create v2ray config file
        createV2rayJsonFileForPing(item: item, bindPort: bindPort, jsonFile: jsonFile)

        // Create a Process instance with async launch
        let process = Process()
        // can't use `/bin/bash -c cmd...` otherwize v2ray process will become a ghost process
        process.launchPath = v2rayCoreFile
        process.arguments = ["-config", jsonFile]
        process.terminationHandler = { _process in
            if _process.terminationStatus != EXIT_SUCCESS {
                NSLog("process is not kill \(_process.description) -  \(_process.processIdentifier) - \(_process.terminationStatus)")
            }
        }
        // async launch and can't waitUntilExit
        process.launch()
        
        // sleep for wait v2ray process instanse
        let second: Double = 1000000
        usleep(useconds_t(0.25 * second))

        // sync process
        checkProxySpent(item: item, bindPort: bindPort)

        // exit process
        if process.isRunning {
            // terminate v2ray process
            process.terminate()
            process.waitUntilExit()
        }
        
        // close port
        closePort(port: bindPort)
        
        // delete config
        try? FileManager.default.removeItem(at: URL(fileURLWithPath: jsonFile))
    }

    func createV2rayJsonFileForPing(item: V2rayItem, bindPort: UInt16, jsonFile: String) {
        var jsonText = item.json
        NSLog("bindPort: \(item.name)-\(item.remark) - \(bindPort)")
        // parse old
        let vCfg = V2rayConfig()
        vCfg.enableSocks = false // just can use one tcp port
        vCfg.parseJson(jsonText: item.json)
        vCfg.httpHost = "127.0.0.1"
        vCfg.socksHost = "127.0.0.1"
        vCfg.httpPort = String(bindPort)
        vCfg.socksPort = String(bindPort + 1) // can't same with http port
        // combine new default config
        jsonText = vCfg.combineManual()

        do {
            let jsonFilePath = URL(fileURLWithPath: jsonFile)

            // delete before config
            if FileManager.default.fileExists(atPath: jsonFile) {
                try? FileManager.default.removeItem(at: jsonFilePath)
            }

            try jsonText.write(to: jsonFilePath, atomically: true, encoding: String.Encoding.utf8)
        } catch let error {
            // failed to write file – bad permissions, bad filename, missing permissions, or more likely it can't be converted to the encoding
            NSLog("save json file fail: \(error)")
        }
    }

    func checkProxySpent(item: V2rayItem, bindPort: UInt16) {
        let group = DispatchGroup()
        group.enter()

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

        // replace item ping to default
        item.speed = "-1ms"
        
        // set URLSessionDataDelegate
        let metric = PingMetrics()
        metric.ping = item
        metric.group = group

        // url request by DispatchGroup wait
        let session = URLSession(configuration: configuration, delegate: metric, delegateQueue: nil)
        let url = URL(string: "http://www.google.com/generate_204")!
        let task = session.dataTask(with: URLRequest(url: url))
        task.resume()
        // wait
        group.wait()
    }
}

class PingMetrics: NSObject, URLSessionDataDelegate {
    var ping: V2rayItem?
    var group: DispatchGroup = DispatchGroup()

    // MARK: - URLSessionDataDelegate

    func urlSession(_ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
        if let transactionMetrics = metrics.transactionMetrics.first {
            let fetchStartDate = transactionMetrics.fetchStartDate
            let responseEndDate = transactionMetrics.responseEndDate
            // check
            if ping != nil && responseEndDate != nil && fetchStartDate != nil {
                let requestDuration = responseEndDate!.timeIntervalSince(fetchStartDate!)
                let pingTs = Int(requestDuration * 100)
                print("PingResult: fetchStartDate=\(fetchStartDate!),responseEndDate=\(responseEndDate!),requestDuration=\(requestDuration),pingTs=\(pingTs)")
                // update ping speed
                ping!.speed = String(format: "%d", pingTs) + "ms"
            }
        }
        // save
        ping!.store()
        // done
        group.leave()
    }
}
