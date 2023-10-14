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
var inPingCurrent = false
var fastV2rayName = ""
var fastV2raySpeed = 5
var ping = PingSpeed()
let second: Double = 1000000
let pingURL = URL(string: "http://www.gstatic.com/generate_204")!

class PingSpeed: NSObject {
    var unpingServers: Dictionary = [String: Bool]()
    let lock = NSLock()
    let semaphore = DispatchSemaphore(value: 20) // work pool

    func pingAll() {
        NSLog("ping start")
        if inPing {
            NSLog("ping inPing")
            return
        }
        // make sure core file
        V2rayLaunch.checkV2rayCore()
        // in ping
        inPing = true
        
        killAllPing()

        fastV2rayName = ""
        unpingServers = [String: Bool]()
        let itemList = V2rayServer.list()
        if itemList.count == 0 {
            inPing = false
            return
        }
        let langStr = Locale.current.languageCode
        var pingTip: String = ""
        if langStr == "en" {
            pingTip = "Ping Speed - In Testing "
        } else {
            pingTip = "Ping Speed - 测试中"
        }
        menuController.setStatusMenuTip(pingTip: pingTip)
        let pingQueue = DispatchQueue(label: "pingQueue", qos: .background, attributes: .concurrent)
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

        semaphore.signal()

        unpingServers.removeValue(forKey: item.name)
        let remainCount  = unpingServers.count
        
        lock.unlock()
        
        if remainCount == 0 {
            inPing = false
            usleep(useconds_t(1 * second))
            do {
                DispatchQueue.main.async {
                    menuController.setStatusMenuTip(pingTip: "Ping Speed...")
                    menuController.showServers()
                }
            }
            // kill after ping
            killAllPing()
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
        jsonFile = AppHomePath + "/.\(item.name).json"

        // create v2ray config file
        createV2rayJsonFileForPing()

        // Create a Process instance with async launch
        // can't use `/bin/bash -c cmd...` otherwize v2ray process will become a ghost process
        process.launchPath = v2rayCoreFile
        process.arguments = ["-config", jsonFile]
//        process.standardError = nil
//        process.standardOutput = nil
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
                try FileManager.default.removeItem(at: jsonFilePath)
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

        // delete config
        do {
            // exit process
            if process.isRunning {
                // terminate v2ray process
                process.interrupt()
                process.terminate()
                process.waitUntilExit()
            }
            // close port
            print("remove ping config:", jsonFile)
            try FileManager.default.removeItem(at: URL(fileURLWithPath: jsonFile))
        } catch let error {
            print("remove ping config error: \(error)")
        }

        // refresh servers
        ping.refreshStatusMenu(item: item)
    }
}

class PingCurrent: NSObject, URLSessionDataDelegate {
    var item: V2rayItem
    var tryPing = 0

    init(item: V2rayItem) {
        self.item = item
        super.init() // can actually be omitted in this example because will happen automatically.
    }

    func doPing() {
        inPingCurrent = true
        NSLog("PingCurrent start: try=\(tryPing),item=\(item.remark)")
        usleep(useconds_t(1 * second))
        // set URLSessionDataDelegate
        let config = getProxyUrlSessionConfigure()
        config.timeoutIntervalForRequest = 2
        // url request
        let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        let task = session.dataTask(with: URLRequest(url: pingURL))
        task.resume()
        tryPing += 1
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
                print("PingCurrent: fetchStartDate=\(fetchStartDate!),responseEndDate=\(responseEndDate!),requestDuration=\(requestDuration),pingTs=\(pingTs)")
                // update ping speed
                item.speed = String(format: "%d", pingTs) + "ms"
            }
        }
        // save
        item.store()
        pingCurrentEnd()
    }

    func pingCurrentEnd() {
        NSLog("PingCurrent end: try=\(tryPing),item=\(item.remark)")
        // ping current fail
        if item.speed == "-1ms" {
            if tryPing < 3 {
                doPing()
            } else {
                // choose next server
                chooseNewServer()
            }
        } else {
            inPingCurrent = false
            DispatchQueue.main.async {
                menuController.showServers()
            }
        }
    }

    func chooseNewServer() {
        if !UserDefaults.getBool(forKey: .autoSelectFastestServer) {
            NSLog(" - choose new server: disabled")
            return
        }
        do {
            V2rayServer.loadConfig()
            let serverList = V2rayServer.list()
            if serverList.count > 1 {
                var pingedSvrs: Dictionary = [String: Int]()
                var allSvrs = [String]()
                for svr in serverList {
                    if svr.name == item.name {
                        continue
                    }
                    allSvrs.append(svr.name)
                    if svr.isValid && svr.speed != "-1ms" {
                        var speed = svr.speed
                        // suffix substring or not
                        let suffixStr = "ms"
                        if speed.hasSuffix(suffixStr) {
                            // Find the index to stop deleting at
                            let LIndex = speed.index(speed.endIndex, offsetBy: -suffixStr.count)
                            // Removing the suffix substring
                            speed = String(speed[..<LIndex])
                        }
                        pingedSvrs[svr.name] = Int(speed)
                    }
                }
                var newSvrName = ""
                if pingedSvrs.count > 0 {
                    // sort by ping seed
                    let sortPing = pingedSvrs.sorted(by: { $0.value < $1.value })
                    newSvrName = sortPing[0].key
                } else {
                    let idx = Int.random(in: 0 ... allSvrs.count)
                    newSvrName = allSvrs[idx]
                }
                NSLog(" - choose new server: \(newSvrName)")
                // set current
                UserDefaults.set(forKey: .v2rayCurrentServerName, value: newSvrName)
                // stop first
                V2rayLaunch.Stop()
                // start
                V2rayLaunch.startV2rayCore()
                // reload menu
                menuController.showServers()
            }
            inPingCurrent = false
        }
    }
}
