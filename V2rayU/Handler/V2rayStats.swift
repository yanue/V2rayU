//
//  TrafficStats.swift
//  V2rayU
//
//  Created by yanue on 2025/1/3.
//

import SwiftUI
import Foundation


actor V2rayTraffics {
    static let shared = V2rayTraffics()
    
    private var directUpLink = 0
    private var directDownLink = 0
    private var proxyUpLink = 0
    private var proxyDownLink = 0

    var lastUpdate = Date()
    
    init() {}
    
    func resetData() {
        self.directDownLink = 0
        self.directUpLink = 0
        self.proxyDownLink = 0
        self.proxyUpLink = 0
    }
    
    func setSpeed(latency: Double, directUpLink: Int, directDownLink: Int, proxyUpLink: Int, proxyDownLink: Int) {
        let now = Date()
        let timeInterval = now.timeIntervalSince(lastUpdate)
        lastUpdate = now
        if timeInterval < 1 {
            return
        }
        // 计算速度
        let directUpSpeed = (Double(directUpLink - self.directUpLink) / 1024  / timeInterval)
        let directDownSpeed = (Double(directDownLink - self.directDownLink) / 1024 / timeInterval)
        let proxyUpSpeed = (Double(proxyUpLink - self.proxyUpLink) / 1024 /  timeInterval)
        let proxyDownSpeed = (Double(proxyDownLink - self.proxyDownLink) / 1024 / timeInterval)
        // 替换
        self.directUpLink = directUpLink
        self.directDownLink = directDownLink
        self.proxyUpLink = proxyUpLink
        self.proxyDownLink = proxyDownLink
        // 计算流量(代理流量=代理上行+代理下行)
        let up = directUpLink + proxyUpLink
        let down = directDownLink + proxyDownLink
        Task {
            // 更新到 UI
            await AppState.shared.setSpeed(latency: latency, directUpSpeed: directUpSpeed, directDownSpeed: directDownSpeed, proxyUpSpeed: proxyUpSpeed, proxyDownSpeed: proxyDownSpeed)
            let uuid = await AppState.shared.runningProfile
//             logger.info("setSpeed:\(now) - \(uuid) - \(up) - \(down) - \(latency) - \(timeInterval)")
            // 更新到数据库
            try ProfileDTO.update_stat(uuid: uuid, up: up, down: down,lastUpdate: now)
        }
    }
}

actor V2rayTrafficStats {
    static let shared = V2rayTrafficStats()
    private var timer: Timer?
    
    private init() {}

    func initTask() {
        logger.info("TrafficStats initialize")
        // 确保在主线程调用
        // 确保在主线程创建和调度 Timer
        DispatchQueue.main.async {
            let timer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
                // 创建新的 Task 来执行异步操作
                Task {
                    await self?.fetchV2RayStats()
                }
            }
            // 将 timer 添加到当前 RunLoop
            RunLoop.current.add(timer, forMode: .common)
        }
    }
    
    // 将 fetchV2RayStats 改为异步函数
    func fetchV2RayStats() async {
        guard let url = URL(string: "http://127.0.0.1:11111/debug/vars") else {
            logger.info("Invalid URL")
            return
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: URLRequest(url: url))
            
            guard let httpResponse = response as? HTTPURLResponse else {
                logger.info("Invalid response")
                return
            }
            
            if httpResponse.statusCode == 200 {
                await parseV2RayStats(jsonData: data)
            } else {
                logger.info("Failed with status code: \(httpResponse.statusCode)")
            }
        } catch {
            logger.info("Request failed: \(error.localizedDescription)")
        }
    }
    
    func parseV2RayStats(jsonData: Data) async {
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601 // 解析日期
            // try decode data
            let vars: V2rayMetricsVars = try decoder.decode(V2rayMetricsVars.self, from: jsonData)
            var latency = 0.0
            var directUpLink = 0
            var directDownLink = 0
            var proxyUpLink = 0
            var proxyDownLink = 0
            guard let stats = vars.stats else {
                logger.info("Invalid V2Ray Stats")
                return
            }
            if let latencyValue = vars.observatory?["proxy"] {
                latency = latencyValue.delay
            }
            if let directUpLinkValue = stats.outbound["direct"] {
                directUpLink = directUpLinkValue.uplink
                directDownLink = directUpLinkValue.downlink
            }
            if let proxyUpLinkValue = stats.outbound["proxy"] {
                proxyUpLink = proxyUpLinkValue.uplink
                proxyDownLink = proxyUpLinkValue.downlink
            }
            await V2rayTraffics.shared.setSpeed(latency: latency, directUpLink: directUpLink, directDownLink: directDownLink, proxyUpLink: proxyUpLink, proxyDownLink: proxyDownLink)
//            logger.info("Parsed V2Ray Stats: \(stats)")
        } catch {
            logger.info("Failed to parse JSON: \(error.localizedDescription)")
        }
    }
}

