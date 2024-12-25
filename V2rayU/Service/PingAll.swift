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

        let itemList = ProfileViewModel.all()
        guard !itemList.isEmpty else {
            NSLog("no items")
            inPing = false
            return
        }

        let pingTip = isMainland ? "Ping Speed - In Testing" : "Ping Speed - 测试中"
//        menuController.setStatusMenuTip(pingTip: pingTip)

        Task {
            do {
                try await pingTaskGroup(items: itemList)
            } catch {
                NSLog("pingTaskGroup error: \(error)")
            }
        }
        NSLog("pingAll")
    }

    func pingTaskGroup(items: [ProfileModel]) async throws {
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

    func pingEachServer(item: ProfileModel) async throws {
        NSLog("pingEachServer: \(item.uuid) - \(item.remark)")
        guard item.isValid else { return }

        let t = PingServer(item: item)
        try await t.doPing()
    }

    func pingEnd() {
        inPing = false
        let pingTip = "Ping"
        NSLog("pingEnd: \(pingTip)")
//        menuController.setStatusMenuTip(pingTip: pingTip)
//        menuController.showServers()
        killAllPing()
    }
}

class PingServer: NSObject, URLSessionDataDelegate {
    var item: ProfileModel
    var bindPort: UInt16 = 0
    var jsonFile: String = ""
    var process: Process = Process()

    init(item: ProfileModel) {
        self.item = item
        super.init()
    }

    func doPing() async throws {
        bindPort = getRandomPort()
        let _json_file = ".\(item.uuid).json"
        jsonFile = AppHomePath + "/" + _json_file

        self.createV2rayJsonFileForPing()

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
        let vCfg = V2rayConfigHandler()
        let jsonText = vCfg.toJSON(enableSocks: false, httpPort: Int(bindPort), outbound: item.outbound)
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
