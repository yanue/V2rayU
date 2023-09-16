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
var ping = PingSpeed()
let second: Double = 1000000


class PingSpeed: NSObject {
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
        let pingQueue = DispatchQueue.init(label: "pingQueue") // 串行队列
        // use thread
        let thread = Thread {
            // ping
            self.serverLen = itemList.count

            for item in itemList {
                pingQueue.async {
                    // run ping by async queue
                    self.pingEachServer(item: item)
                }
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
                // fix: must be used from main thread only
                DispatchQueue.main.async {
                    menuController.configWindow.serversTableView.reloadData()
                }
            }
        }
    }

    func doPing(item: V2rayItem) {
        let randomInt = Int.random(in: 9000...36500)
        let (_, bindPort) = getUsablePort(port: uint16(randomInt))

        NSLog("doPing: \(item.name)-\(item.remark) - \(bindPort)")
        let jsonFile = AppHomePath + "/.config_ping.\(item.name).json"

        // create v2ray config file
        createV2rayJsonFileForPing(item: item, bindPort: bindPort, jsonFile: jsonFile)

        // Create a Process instance with async launch
        let process = Process()
        // can't use `/bin/bash -c cmd...` otherwize v2ray process will become a ghost process
        process.launchPath = v2rayCoreFile
        process.arguments = ["-config", jsonFile]
        process.standardError = nil
        process.standardOutput = nil
        process.terminationHandler = { _process in
            if _process.terminationStatus != EXIT_SUCCESS {
                NSLog("process is not kill \(_process.description) -  \(_process.processIdentifier) - \(_process.terminationStatus)")
            }
        }
        // async launch and can't waitUntilExit
        process.launch()
        
        // sleep for wait v2ray process instanse
        usleep(useconds_t(1 * second))

        // async process
        // set URLSessionDataDelegate
        let metric = PingMetrics()
        metric.ping = item

        // url request
        let session = URLSession(configuration: getProxyUrlSessionConfigure(httpProxyPort: bindPort), delegate: metric, delegateQueue: nil)
        let url = URL(string: "http://www.google.com/generate_204")!
        let task = session.dataTask(with: URLRequest(url: url)){(data: Data?, response: URLResponse?, error: Error?) in
            self.pingEnd(process: process, jsonFile: jsonFile, bindPort: bindPort)
        }
        task.resume()
    }
    
    func pingEnd(process: Process, jsonFile:String, bindPort: UInt16) {
        // exit process
        if process.isRunning {
            // terminate v2ray process
            process.terminate()
            process.waitUntilExit()
        }
        
        // close port
        closePort(port: bindPort)
        
        // delete config
        do {
            let jsonFilePath = URL(fileURLWithPath: jsonFile)
            try? FileManager.default.removeItem(at: jsonFilePath)
        }
        
        // refresh server
        self.refreshStatusMenu()
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
}

class PingMetrics: NSObject, URLSessionDataDelegate {
    var ping: V2rayItem?

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
        if ping != nil {
            ping!.store()
        }
    }
}
