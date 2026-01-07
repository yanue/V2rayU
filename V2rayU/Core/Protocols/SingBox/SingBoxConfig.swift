//
//  SingBox.swift
//  V2rayU
//
//  Created by yanue on 2026/1/7.
//

import Foundation

// 顶层 sing-box 配置结构
struct SingboxStruct: Codable {
    var log: LogConfig = LogConfig(level: "info")
    var inbounds: [SingboxInbound] = []
    var outbounds: [SingboxOutbound] = []
    var dns: DNSConfig = DNSConfig()
    var route: RouteConfig = RouteConfig()

    func toJSON() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        guard let jsonData = try? encoder.encode(self),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return "{}"
        }
        return jsonString
    }
}

// 日志配置
struct LogConfig: Codable {
    var level: String
}

// Inbound
struct SingboxInbound: Codable {
    var type: String
    var tag: String?
    var listen: String?
    var listen_port: Int?
    var address: [String]?
    var auto_route: Bool?
    var strict_route: Bool?
    var mtu: Int?
    var stack: String?
    var sniff: Bool?
}

// Outbound
struct SingboxOutbound: Codable {
    var type: String
    var tag: String?
    var server: String?
    var server_port: Int?
    var password: String?
    var tls: TLSConfig?
    var domain_resolver: String?
}

// TLS
struct TLSConfig: Codable {
    var enabled: Bool
    var server_name: String?
    var insecure: Bool?
    var alpn: [String]?
    var utls: UTLSConfig?
}

struct UTLSConfig: Codable {
    var enabled: Bool
    var fingerprint: String?
}

// DNS
struct DNSConfig: Codable {
    var servers: [DNSServer] = []
    var rules: [DNSRule] = []
}

struct DNSServer: Codable {
    var type: String
    var tag: String?
    var server: String?
    var inet4_range: String?
    var inet6_range: String?
}

struct DNSRule: Codable {
    var server: String
    var domain: [String]?
}

// Route
struct RouteConfig: Codable {
    var auto_detect_interface: Bool = true
    var default_domain_resolver: String = "default-dns"
    var rules: [RouteRule] = []
}

struct RouteRule: Codable {
    var outbound: String
    var domain: [String]?
}
