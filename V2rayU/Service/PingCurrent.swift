//
//  PingCurrent.swift
//  V2rayU
//
//  Created by Erick on 2019/10/30.
//  Copyright © 2019 yanue. All rights reserved.
//

import Foundation

class PingCurrent: NSObject, URLSessionDataDelegate {
    static let shared = PingCurrent()

    var item: ProfileModel?
    var tryPing = 0
    var inPingProcess = false

    private override init() {
        super.init()
    }

    func startPing(with item: ProfileModel) {
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

        let serverList = ProfileViewModel.all()
        guard serverList.count > 1 else {
            inPingProcess = false
            return
        }

        var pingedSvrs = [String: Int]()
        var allSvrs = [String]()

        for svr in serverList where svr.uuid != item.uuid {
            allSvrs.append(svr.uuid)
            if svr.isValid && svr.speed != "-1ms" {
                let speed = svr.speed.replacingOccurrences(of: "ms", with: "")
                if let speedInt = Int(speed) {
                    pingedSvrs[svr.uuid] = speedInt
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
