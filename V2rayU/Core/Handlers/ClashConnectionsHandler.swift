//
//  ClashConnectionsHandler.swift
//  V2rayU
//
//  sing-box clash_api 的连接列表: GET /connections 取快照, DELETE /connections[/{id}] 关闭
//

import Foundation

struct ClashConnectionMetadata: Codable, Equatable {
    var network: String = ""
    var type: String = ""
    var sourceIP: String = ""
    var destinationIP: String = ""
    var sourcePort: String = ""
    var destinationPort: String = ""
    var host: String = ""
    var dnsMode: String? = nil
    var processPath: String? = nil
}

struct ClashConnection: Codable, Equatable, Identifiable {
    var id: String
    var metadata: ClashConnectionMetadata
    var upload: Int = 0
    var download: Int = 0
    var start: String = ""
    var chains: [String] = []
    var rule: String = ""
    var rulePayload: String = ""

    /// 目标: 域名优先, 没有域名用 IP, 都带端口
    var target: String {
        let host = metadata.host.isEmpty ? metadata.destinationIP : metadata.host
        return metadata.destinationPort.isEmpty ? host : "\(host):\(metadata.destinationPort)"
    }

    var source: String {
        metadata.sourcePort.isEmpty ? metadata.sourceIP : "\(metadata.sourceIP):\(metadata.sourcePort)"
    }

    /// 最终出站: sing-box 的 chains 是从出站往入站排, 第一个是实际出站
    var outbound: String { chains.first ?? "" }

    /// 完整链路, 入站侧在前
    var chainText: String { chains.reversed().joined(separator: " → ") }

    var processName: String {
        guard let path = metadata.processPath, !path.isEmpty else { return "" }
        return (path as NSString).lastPathComponent
    }

    var ruleText: String {
        rulePayload.isEmpty ? rule : "\(rule) (\(rulePayload))"
    }

    var startDate: Date? { ClashConnection.parseStart(start) }

    /// Go 的 time.Time 输出带 9 位小数和时区偏移, ISO8601DateFormatter 不认超过 3 位的小数, 先去掉小数再解析
    static func parseStart(_ text: String) -> Date? {
        guard !text.isEmpty else { return nil }
        let stripped = text.replacingOccurrences(of: #"\.\d+"#, with: "", options: .regularExpression)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: stripped)
    }

    /// 搜索匹配: 目标、进程、出站、规则、来源
    func matches(_ keyword: String) -> Bool {
        let k = keyword.lowercased()
        return target.lowercased().contains(k)
            || processName.lowercased().contains(k)
            || chainText.lowercased().contains(k)
            || ruleText.lowercased().contains(k)
            || source.lowercased().contains(k)
            || metadata.network.lowercased().contains(k)
    }
}

struct ClashConnectionsSnapshot: Codable, Equatable {
    var downloadTotal: Int = 0
    var uploadTotal: Int = 0
    var connections: [ClashConnection]? = []

    var list: [ClashConnection] { connections ?? [] }

    static func parse(_ data: Data) throws -> ClashConnectionsSnapshot {
        try JSONDecoder().decode(ClashConnectionsSnapshot.self, from: data)
    }
}

/// 格式化连接持续时间: 59s / 3m05s / 1h02m
func formatConnectionDuration(_ seconds: TimeInterval) -> String {
    let s = max(0, Int(seconds))
    if s < 60 { return "\(s)s" }
    if s < 3600 { return String(format: "%dm%02ds", s / 60, s % 60) }
    return String(format: "%dh%02dm", s / 3600, (s % 3600) / 60)
}

actor ClashConnectionsHandler {
    static let shared = ClashConnectionsHandler()

    private let session: URLSession

    init(baseUrl: String = coreApiBaseUrl) {
        self.baseUrl = baseUrl
        let config = URLSessionConfiguration.ephemeral
        // 不走系统代理, 避免被自己的 http-in 代理拦截
        config.connectionProxyDictionary = [:]
        config.timeoutIntervalForRequest = 3
        session = URLSession(configuration: config)
    }

    private let baseUrl: String

    func fetch() async throws -> ClashConnectionsSnapshot {
        guard let url = URL(string: "\(baseUrl)/connections") else {
            throw URLError(.badURL)
        }
        let (data, response) = try await session.data(for: URLRequest(url: url))
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }
        return try ClashConnectionsSnapshot.parse(data)
    }

    func close(id: String) async {
        await delete(path: "/connections/\(id)")
    }

    func closeAll() async {
        await delete(path: "/connections")
    }

    private func delete(path: String) async {
        guard let url = URL(string: baseUrl + path) else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        do {
            _ = try await session.data(for: request)
        } catch {
            logger.info("close connection failed: \(path) \(error.localizedDescription)")
        }
    }
}
