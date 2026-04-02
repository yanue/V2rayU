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
    var experimental: ExperimentalConfig? = nil   // 新增字段

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

// 顶层 experimental 改成 clash_api
struct ExperimentalConfig: Codable {
    var clash_api: ClashAPIConfig
}

// Clash API 配置
struct ClashAPIConfig: Codable {
    var external_controller: String   // API监听地址，例如 "127.0.0.1:9090"
    var secret: String?              // 可选，访问API的密钥
}

// 日志配置
struct LogConfig: Codable {
    var disabled: Bool? = nil
    var level: String
    var output: String?
    var timestamp: Bool? = true

    init(
        disabled: Bool? = nil,
        level: String,
        output: String? = nil,
        timestamp: Bool? = true
    ) {
        self.disabled = disabled
        self.level = level
        self.output = output
        self.timestamp = timestamp
    }
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
    var stack: String?  // 对 tun 需要: system
    var sniff: Bool? // 对 tun 需要
    var sniff_override_destination: Bool? // 对 tun 需要, 很重要, 不然需要手动在设置界面上设置dns
}

// Outbound
struct SingboxOutbound: Codable {
    var type: String
    var tag: String?
    var server: String?
    var server_port: Int?
    var password: String? // trojan
    var method: String? // 仅ss
    var uuid: String? // vmess|vless
    var security: String? // vmess
    var alter_id: Int? // vmess
    var global_padding: Bool? // vmess
    var authenticated_length: Bool? // vmess
    var flow: String? // 新增支持 vless flow
    var domain_resolver: String?
    var multiplex: SingboxMultiplexConfig?
    var tls: TLSConfig?
    var transport: TransportConfig?

    init(
        type: String,
        tag: String? = nil,
        server: String? = nil,
        server_port: Int? = nil,
        password: String? = nil,
        method: String? = nil,
        uuid: String? = nil,
        security: String? = nil,
        alter_id: Int? = nil,
        global_padding: Bool? = nil,
        authenticated_length: Bool? = nil,
        flow: String? = nil,
        domain_resolver: String? = nil,
        multiplex: SingboxMultiplexConfig? = nil,
        tls: TLSConfig? = nil,
        transport: TransportConfig? = nil
    ) {
        self.type = type
        self.tag = tag
        self.server = server
        self.server_port = server_port
        self.password = password
        self.method = method
        self.uuid = uuid
        self.security = security
        self.alter_id = alter_id
        self.global_padding = global_padding
        self.authenticated_length = authenticated_length
        self.flow = flow
        self.domain_resolver = domain_resolver
        self.multiplex = multiplex
        self.tls = tls
        self.transport = transport
    }
}

struct SingboxMultiplexConfig: Codable {
    var enabled: Bool
    var `protocol`: String?
    var max_connections: Int?
    var min_streams: Int?
    var max_streams: Int?
    var padding: Bool?

    init(
        enabled: Bool,
        protocol: String? = nil,
        max_connections: Int? = nil,
        min_streams: Int? = nil,
        max_streams: Int? = nil,
        padding: Bool? = nil
    ) {
        self.enabled = enabled
        self.`protocol` = `protocol`
        self.max_connections = max_connections
        self.min_streams = min_streams
        self.max_streams = max_streams
        self.padding = padding
    }
}

// Transport 配置
struct TransportConfig: Codable {
    var type: String?              // "tcp", "ws", "grpc"
    var path: String?              // ws 路径
    var headers: [String:String]?  // ws 头部
    var service_name: String?      // grpc service_name
}

// TLS
struct TLSConfig: Codable {
    var enabled: Bool
    var server_name: String?
    var insecure: Bool?
    var alpn: [String]?
    var utls: UTLSConfig?
    var reality: RealityConfig?   // 新增
}

struct RealityConfig: Codable {
    var enabled: Bool
    var public_key: String
    var short_id: String?
    var spider_x: String?
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
    var process_name: [String]?
}
