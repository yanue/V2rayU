//
//  ping.swift
//  V2rayU
//
//  Created by Erick on 2019/10/30.
//  Copyright © 2019 yanue. All rights reserved.
//

import SwiftyJSON

// ping and choose fastest v2ray
var inPing = false
var inPingCurrent = false

var ping = PingSpeed()
let second: Double = 1000000
let pingURL = URL(string: "http://www.gstatic.com/generate_204")!

class PingSpeed: NSObject {
    let maxConcurrentTasks = 30

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
        
        let itemList = V2rayServer.all()
        if itemList.count == 0 {
            NSLog("no items")
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
        Task {
            do {
                try await pingTaskGroup(items: itemList)
            } catch let error {
                NSLog("pingTaskGroup error: \(error)")
            }
        }
    }
    
    func pingTaskGroup(items: [V2rayItem]) async throws  {
        let taskChunks = stride(from: 0, to: items.count, by: maxConcurrentTasks).map {
            Array(items[$0..<min($0 + maxConcurrentTasks, items.count)])
        }
        NSLog("pingTaskGroup-start: taskChunks=\(taskChunks.count)")
        for (i, chunk) in taskChunks.enumerated() {
            NSLog("pingTaskGroup-start-\(i): count=\(chunk.count)")
            try await withThrowingTaskGroup(of: Void.self) { group in
                for item in chunk {
                    group.addTask {
                        do {
                            try await self.pingEachServer(item: item)
                        } catch {
                            NSLog("pingEachServer error: \(error)")
                        }
                        return
                    }
                }
                
                // 等待当前批次所有任务完成
                try await group.waitForAll()
            }
            NSLog("pingTaskGroup-end-\(i)")
        }
        NSLog("pingTaskGroup-end")
        self.pingEnd()
    }

    func pingEachServer(item: V2rayItem) async throws {
        NSLog("pingEachServer: \(item.name) - \(item.remark)")
        if !item.isValid {
            return
        }
        // ping
        let t = PingServer(item: item)
        try await t.doPing()
    }

    func pingEnd() {
        inPing = false
        let langStr = Locale.current.languageCode
        var pingTip: String = ""
        if langStr == "en" {
            pingTip = "Ping Speed"
        } else {
            pingTip = "Ping"
        }
        print("pingEnd", pingTip)
        menuController.setStatusMenuTip(pingTip: pingTip)
        menuController.showServers()
        // kill
        killAllPing()
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

    func doPing() async throws {
        let (_, _bindPort) = getUsablePort(port: uint16(Int.random(in: 9000 ... 36500)))

        NSLog("doPing: \(item.name)-\(item.remark) - \(_bindPort)")
        bindPort = _bindPort
        
        let _json_file = ".\(item.name).json"
        jsonFile = AppHomePath + "/" + _json_file

        // create v2ray config file
        createV2rayJsonFileForPing()
        // 创建管道
        let processPipe = Pipe()
        // Create a Process instance with async launch
        // use `/bin/bash -c cmd ...` and need kill subprocess
        let pingCmd = "cd \(AppHomePath) && ./v2ray-core/v2ray run -config \(_json_file)"
        NSLog("pingCmd: \(pingCmd)")
        process.launchPath = "/bin/bash"
        process.arguments = ["-c", pingCmd]
        process.standardError = processPipe
        process.standardOutput = processPipe
        process.terminationHandler = { _process in
            // 结束子进程
            if _process.terminationStatus != EXIT_SUCCESS {
                NSLog("process is not kill \(_bindPort) - \(_process.description) -  \(_process.processIdentifier) - \(_process.terminationStatus)")
                _process.terminate()
                _process.waitUntilExit()
            }
        }
        // async launch and can't waitUntilExit
        process.launch()

        // sleep for wait v2ray process instanse
        usleep(useconds_t(2 * second))

        let session = URLSession(configuration: getProxyUrlSessionConfigure(httpProxyPort: bindPort), delegate: self, delegateQueue: nil)
        do {
            let (_,_) = try await session.data(for: URLRequest(url: pingURL))
        } catch let error {
            // failed to write file – bad permissions, bad filename, missing permissions, or more likely it can't be converted to the encoding
            NSLog("session request fail: \(error)")
        }
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
    }
}

class PingCurrent: NSObject, URLSessionDataDelegate {
    var item: V2rayItem
    var tryPing = 0

    init(item: V2rayItem) {
        self.item = item
        super.init() // can actually be omitted in this example because will happen automatically.
    }

    func doPing()  {
        Task {
            do {
                try await _doPing()
                pingCurrentEnd()
            } catch let error {
                NSLog("doPing error: \(error)")
            }
        }
    }
    
    func _doPing() async throws {
        inPingCurrent = true
        usleep(useconds_t(1 * second))
        NSLog("PingCurrent start: try=\(tryPing),item=\(item.remark)")
        // set URLSessionDataDelegate
        let config = getProxyUrlSessionConfigure()
        config.timeoutIntervalForRequest = 3
        // url request
        let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        tryPing += 1
        do {
            let (_,_) = try await session.data(for: URLRequest(url: pingURL))
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
                print("PingCurrent: fetchStartDate=\(fetchStartDate!),responseEndDate=\(responseEndDate!),requestDuration=\(requestDuration),pingTs=\(pingTs)")
                // update ping speed
                item.speed = String(format: "%d", pingTs) + "ms"
            }
        }
        // save
        item.store()
    }

    func pingCurrentEnd() {
        NSLog("PingCurrent end: try=\(tryPing),item=\(item.remark)")
        // ping current fail
        if item.speed == "-1ms" {
            if tryPing < 3 {
                usleep(useconds_t(3 * second))
                doPing()
            } else {
                // choose next server
                chooseNewServer()
            }
        } else {
            inPingCurrent = false
            menuController.showServers()
        }
    }

    func chooseNewServer() {
        if !UserDefaults.getBool(forKey: .autoSelectFastestServer) {
            NSLog(" - choose new server: disabled")
            return
        }
        do {
            let serverList = V2rayServer.all()
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
                    // 修复越界问题
                    let idx = Int.random(in: 0 ... allSvrs.count-1)
                    newSvrName = allSvrs[idx]
                }
                NSLog(" - choose new server: \(newSvrName)")
                // set current
                UserDefaults.set(forKey: .v2rayCurrentServerName, value: newSvrName)
                // restart
                V2rayLaunch.restartV2ray()
            }
            inPingCurrent = false
        }
    }
}
