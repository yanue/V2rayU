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
let pingURL = URL(string: "http://www.google.com/generate_204")!

class PingSpeed: NSObject {
    var unpingServers: Dictionary = [String: Bool]()
    
    let lock = NSLock()
    let semaphore = DispatchSemaphore(value: 10) // work pool 

    func pingAll() {
        NSLog("ping start")
        if inPing {
            NSLog("ping inPing")
            return
        }
        fastV2rayName = ""
        unpingServers = [String: Bool]()
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
        let pingQueue = DispatchQueue(label: "pingQueue", attributes: .concurrent) // 串行队列
        for item in itemList {
            unpingServers[item.name] = true
            pingQueue.async {
                self.semaphore.wait()
                // run ping by async queue
                self.pingEachServer(item: item)
            }
        }
    }

    func pingEachServer(item: V2rayItem) {
        NSLog("ping \(item.name) - \(item.remark)")
        // ping
        PingServer(item: item).doPing()
    }

    func refreshStatusMenu(item: V2rayItem) {
        lock.lock()
        defer { lock.unlock() }
        
        semaphore.signal()
        
        unpingServers.removeValue(forKey: item.name)

        if unpingServers.count == 0 {
            inPing = false
            usleep(useconds_t(1 * second))
            do {
                DispatchQueue.main.async {
                    menuController.statusMenu.item(withTag: 1)?.title = "Ping Speed..."
                    menuController.showServers()
                    // reload config
                    if menuController.configWindow != nil {
                        // fix: must be used from main thread only
                        menuController.configWindow.serversTableView.reloadData()
                    }
                }
            }
        }
    }
}

class PingServer: NSObject, URLSessionDataDelegate {
    var item: V2rayItem

    var bindPort: UInt16 = 0
    var jsonFile: String = ""
    var process: Process = Process()

    init(item: V2rayItem) {
        self.item = item
        super.init() // can actually be omitted in this example because will happen automatically.
    }

    func doPing() {
        if !item.isValid {
            // refresh servers
            ping.refreshStatusMenu(item: item)
            return
        }
        let (_, _bindPort) = getUsablePort(port: uint16(Int.random(in: 9000 ... 36500)))

        NSLog("doPing: \(item.name)-\(item.remark) - \(_bindPort)")
        bindPort = _bindPort
        jsonFile = AppHomePath + "/.config_ping.\(item.name).json"

        // create v2ray config file
        createV2rayJsonFileForPing()

        // Create a Process instance with async launch
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

        // url request
        let session = URLSession(configuration: getProxyUrlSessionConfigure(httpProxyPort: bindPort), delegate: self, delegateQueue: nil)
        let task = session.dataTask(with: URLRequest(url: pingURL))
        task.resume()
    }

    func createV2rayJsonFileForPing() {
        var jsonText = item.json
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
            // write
            try jsonText.write(to: jsonFilePath, atomically: true, encoding: String.Encoding.utf8)
        } catch let error {
            // failed to write file – bad permissions, bad filename, missing permissions, or more likely it can't be converted to the encoding
            NSLog("save json file fail: \(error)")
        }
    }

    // MARK: - URLSessionDataDelegate

    func urlSession(_ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
        item.speed = "-1ms"
        if let transactionMetrics = metrics.transactionMetrics.first {
            let fetchStartDate = transactionMetrics.fetchStartDate
            let responseEndDate = transactionMetrics.responseEndDate
            // check
            if responseEndDate != nil && fetchStartDate != nil {
                let requestDuration = responseEndDate!.timeIntervalSince(fetchStartDate!)
                let pingTs = Int(requestDuration * 100)
                print("PingResult: fetchStartDate=\(fetchStartDate!),responseEndDate=\(responseEndDate!),requestDuration=\(requestDuration),pingTs=\(pingTs)")
                // update ping speed
                item.speed = String(format: "%d", pingTs) + "ms"
            }
        }
        // save
        item.store()
        pingEnd()
    }

    func pingEnd() {
        NSLog("ping end: \(item.remark) - \(item.speed)")

        // refresh servers
        ping.refreshStatusMenu(item: item)

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
