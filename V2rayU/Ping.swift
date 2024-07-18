//
//  ping.swift
//  V2rayU
//
//  Created by Erick on 2019/10/30.
//  Copyright © 2019 yanue. All rights reserved.
//

import Foundation

// ping and choose fastest v2ray
var inPing = false
var inPingCurrent = false

var ping = PingSpeed()
let second: Double = 1000000
let pingURL = URL(string: "http://www.gstatic.com/generate_204")!

func getRandomPort() -> UInt16 {
    return UInt16.random(in: 49152...65535)
}

class PingSpeed: NSObject {
    let maxConcurrentTasks = 30

    func pingAll() {
        NSLog("ping start")
        guard !inPing else {
            NSLog("ping inPing")
            return
        }

        V2rayLaunch.checkV2rayCore()

        inPing = true
        killAllPing()

        let itemList = V2rayServer.all()
        guard !itemList.isEmpty else {
            NSLog("no items")
            inPing = false
            return
        }

        let pingTip = isMainland ? "Ping Speed - In Testing" : "Ping Speed - 测试中"
        menuController.setStatusMenuTip(pingTip: pingTip)

        Task {
            do {
                try await pingTaskGroup(items: itemList)
            } catch {
                NSLog("pingTaskGroup error: \(error)")
            }
        }
        NSLog("pingAll")
    }

    func pingTaskGroup(items: [V2rayItem]) async throws {
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
                    }
                }
                try await group.waitForAll()
            }
            NSLog("pingTaskGroup-end-\(i)")
        }
        NSLog("pingTaskGroup-end")
        pingEnd()
    }

    func pingEachServer(item: V2rayItem) async throws {
        NSLog("pingEachServer: \(item.name) - \(item.remark)")
        guard item.isValid else { return }

        let t = PingServer(item: item)
        try await t.doPing()
    }

    func pingEnd() {
        inPing = false
        let pingTip = "Ping"
        NSLog("pingEnd: \(pingTip)")
        menuController.setStatusMenuTip(pingTip: pingTip)
        menuController.showServers()
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
        super.init()
    }

    func doPing() async throws {
        bindPort = getRandomPort()
        let _json_file = ".\(item.name).json"
        jsonFile = AppHomePath + "/" + _json_file

        createV2rayJsonFileForPing()

        let pingCmd = "cd \(AppHomePath) && ./v2ray-core/v2ray run -config \(_json_file)"
        NSLog("pingCmd: \(pingCmd)")

        process.launchPath = "/bin/bash"
        process.arguments = ["-c", pingCmd]
        process.terminationHandler = { _process in
            if _process.terminationStatus != EXIT_SUCCESS {
                NSLog("process is not kill \(self.bindPort) - \(_process.description) -  \(_process.processIdentifier) - \(_process.terminationStatus)")
                _process.terminate()
                _process.waitUntilExit()
            }
        }

        process.launch()
        usleep(useconds_t(2 * second))

        let session = URLSession(configuration: getProxyUrlSessionConfigure(httpProxyPort: bindPort), delegate: self, delegateQueue: nil)
        do {
            _ = try await session.data(for: URLRequest(url: pingURL))
        } catch {
            NSLog("session request fail: \(error)")
        }
    }

    func createV2rayJsonFileForPing() {
        var jsonText = item.json
        let vCfg = V2rayConfig()
        vCfg.enableSocks = false
        vCfg.parseJson(jsonText: item.json)
        vCfg.httpHost = "127.0.0.1"
        vCfg.socksHost = "127.0.0.1"
        vCfg.httpPort = String(bindPort)
        vCfg.socksPort = String(bindPort + 1)
        jsonText = vCfg.combineManual()

        do {
            let jsonFilePath = URL(fileURLWithPath: jsonFile)
            if FileManager.default.fileExists(atPath: jsonFile) {
                try FileManager.default.removeItem(at: jsonFilePath)
            }
            try jsonText.write(to: jsonFilePath, atomically: true, encoding: .utf8)
        } catch {
            NSLog("save json file fail: \(error)")
        }
    }

    // MARK: - URLSessionDataDelegate

    func urlSession(_ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
        item.speed = "-1ms"
        if let transactionMetrics = metrics.transactionMetrics.first {
            let fetchStartDate = transactionMetrics.fetchStartDate
            let responseEndDate = transactionMetrics.responseEndDate
            if let fetchStartDate = fetchStartDate, let responseEndDate = responseEndDate {
                let requestDuration = responseEndDate.timeIntervalSince(fetchStartDate)
                let pingTs = Int(requestDuration * 100)
                NSLog("PingResult: fetchStartDate=\(fetchStartDate), responseEndDate=\(responseEndDate), requestDuration=\(requestDuration), pingTs=\(pingTs)")
                item.speed = String(format: "%dms", pingTs)
            }
        }
        item.store()
        pingEnd()
    }

    func pingEnd() {
        NSLog("ping end: \(item.remark) - \(item.speed)")
        do {
            if process.isRunning {
                process.interrupt()
                process.terminate()
                process.waitUntilExit()
            }
            try FileManager.default.removeItem(at: URL(fileURLWithPath: jsonFile))
        } catch {
            NSLog("remove ping config error: \(error)")
        }
    }
}

class PingCurrent: NSObject, URLSessionDataDelegate {
    static let shared = PingCurrent()

    var item: V2rayItem?
    var tryPing = 0
    var inPingProcess = false

    private override init() {
        super.init()
    }

    func startPing(with item: V2rayItem) {
        guard !inPingProcess else {
            return
        }
        self.item = item
        tryPing = 0
        doPing()
    }

    private func doPing() {
        guard let item = item else { return }

        inPingProcess = true
        Task {
            do {
                try await _doPing()
                pingCurrentEnd()
            } catch {
                NSLog("doPing error: \(error)")
                inPingProcess = false
            }
        }
    }
    
    private func _doPing() async throws {
        usleep(useconds_t(1 * second)) // 1 second
        guard let item = item else { return }
        NSLog("PingCurrent start: try=\(tryPing), item=\(item.remark)")
        
        let config = getProxyUrlSessionConfigure()
        config.timeoutIntervalForRequest = 3
        
        let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        tryPing += 1
        
        do {
            let (_, _) = try await session.data(for: URLRequest(url: pingURL))
        } catch {
            NSLog("save json file fail: \(error)")
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
        guard let item = item else { return }

        item.speed = "-1ms"
        if let transactionMetrics = metrics.transactionMetrics.first,
           let fetchStartDate = transactionMetrics.fetchStartDate,
           let responseEndDate = transactionMetrics.responseEndDate {
            let requestDuration = responseEndDate.timeIntervalSince(fetchStartDate)
            let pingTs = Int(requestDuration * 100)
            print("PingCurrent: fetchStartDate=\(fetchStartDate), responseEndDate=\(responseEndDate), requestDuration=\(requestDuration), pingTs=\(pingTs)")
            item.speed = "\(pingTs)ms"
        }
        item.store()
    }

    private func pingCurrentEnd() {
        guard let item = item else { return }

        NSLog("PingCurrent end: try=\(tryPing), item=\(item.remark)")
        if item.speed == "-1ms" {
            if tryPing < 3 {
                inPingProcess = false
                DispatchQueue.global().asyncAfter(deadline: .now() + 3) {
                    self.doPing()
                }
            } else {
                chooseNewServer()
            }
        } else {
            inPingProcess = false
            menuController.showServers()
        }
    }

    private func chooseNewServer() {
        guard let item = item else {
            inPingProcess = false
            return
        }

        guard UserDefaults.getBool(forKey: .autoSelectFastestServer) else {
            NSLog(" - choose new server: disabled")
            inPingProcess = false
            return
        }
        
        let serverList = V2rayServer.all()
        guard serverList.count > 1 else {
            inPingProcess = false
            return
        }

        var pingedSvrs = [String: Int]()
        var allSvrs = [String]()
        
        for svr in serverList where svr.name != item.name {
            allSvrs.append(svr.name)
            if svr.isValid && svr.speed != "-1ms" {
                let speed = svr.speed.replacingOccurrences(of: "ms", with: "")
                if let speedInt = Int(speed) {
                    pingedSvrs[svr.name] = speedInt
                }
            }
        }

        let newSvrName: String
        if let fastestSvr = pingedSvrs.sorted(by: { $0.value < $1.value }).first {
            newSvrName = fastestSvr.key
        } else if let randomSvr = allSvrs.randomElement() {
            newSvrName = randomSvr
        } else {
            inPingProcess = false
            return
        }

        NSLog(" - choose new server: \(newSvrName)")
        UserDefaults.set(forKey: .v2rayCurrentServerName, value: newSvrName)
        V2rayLaunch.restartV2ray()
        inPingProcess = false
    }
}
