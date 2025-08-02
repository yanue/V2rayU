//
//  PingServer.swift
//  V2rayU
//
//  Created by yanue on 2024/12/27.
//

import Foundation

actor Ping {
    /// 执行 Ping 操作并返回响应时间（单位：毫秒）
    func doPing(bindPort: UInt16) async throws -> Int {
        let session = URLSession(configuration: getProxyUrlSessionConfigure(httpProxyPort: bindPort))

        let (_, response) = try await session.data(for: URLRequest(url: AppSettings.shared.pingURL))
        // 这里可以根据 data 或 response 做更多校验
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        // 使用 metrics 提取 ping 时间
        let metrics = try await session.metrics(for: URLRequest(url: AppSettings.shared.pingURL))
        guard let transactionMetrics = metrics.transactionMetrics.first,
              let fetchStartDate = transactionMetrics.fetchStartDate,
              let responseEndDate = transactionMetrics.responseEndDate else {
            throw URLError(.cannotParseResponse)
        }

        let requestDuration = responseEndDate.timeIntervalSince(fetchStartDate)
        let pingTime = Int(requestDuration * 100) // 转换为毫秒
        print("PingRunning: fetchStartDate=\(fetchStartDate), responseEndDate=\(responseEndDate), requestDuration=\(requestDuration), pingTs=\(pingTime)")

        return pingTime
    }
}

