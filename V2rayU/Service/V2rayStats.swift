//
//  TrafficStats.swift
//  V2rayU
//
//  Created by yanue on 2025/1/3.
//


import Foundation

actor V2rayTrafficStats {
    static let shared = V2rayTrafficStats()
    private var timer: Timer?
    
    private init() {}
    
    func startPeriodicFetch() {
        // 确保在主线程创建和调度 Timer
        DispatchQueue.main.async {
            let timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
                // 创建新的 Task 来执行异步操作
                Task {
                    await self?.fetchV2RayStats()
                }
            }
            // 将 timer 添加到当前 RunLoop
            RunLoop.current.add(timer, forMode: .common)
        }
    }
    
    func initialize() {
        NSLog("TrafficStats initialize")
        // 确保在主线程调用
        startPeriodicFetch()
    }
    
    // 将 fetchV2RayStats 改为异步函数
    func fetchV2RayStats() async {
        guard let url = URL(string: "http://127.0.0.1:11111/debug/vars") else {
            NSLog("Invalid URL")
            return
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: URLRequest(url: url))
            
            guard let httpResponse = response as? HTTPURLResponse else {
                NSLog("Invalid response")
                return
            }
            
            if httpResponse.statusCode == 200 {
                await parseV2RayStats(jsonData: data)
            } else {
                NSLog("Failed with status code: \(httpResponse.statusCode)")
            }
        } catch {
            NSLog("Request failed: \(error.localizedDescription)")
        }
    }
    
    func parseV2RayStats(jsonData: Data) async {
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601 // 解析日期
            // try decode data
            let stats: V2rayMetricsVars = try decoder.decode(V2rayMetricsVars.self, from: jsonData)
            NSLog("Parsed V2Ray Stats: \(stats)")
        } catch {
            NSLog("Failed to parse JSON: \(error.localizedDescription)")
        }
    }
}

