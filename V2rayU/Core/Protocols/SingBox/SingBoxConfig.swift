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
    var clash_api: ClashAPIConfig? = nil
    var cache_file: CacheFileConfig? = nil
}

struct CacheFileConfig: Codable {
    var enabled: Bool
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
    var password: String? // trojan, hysteria2
    var method: String? // 仅ss
    var uuid: String? // vmess|vless
    var security: String? // vmess
    var alter_id: Int? // vmess
    var global_padding: Bool? // vmess
    var authenticated_length: Bool? // vmess
    var flow: String? // 新增支持 vless flow
    var username: String? // socks5|http
    var domain_resolver: String?
    var multiplex: SingboxMultiplexConfig?
    var tls: TLSConfig?
    var transport: TransportConfig?
    // hysteria2
    var up_mbps: Int?
    var down_mbps: Int?
    var obfs: Hysteria2ObfsConfig?
    var hop_interval: Int?
    var outbounds: [String]?
    var `default`: String?

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
        username: String? = nil,
        domain_resolver: String? = nil,
        multiplex: SingboxMultiplexConfig? = nil,
        tls: TLSConfig? = nil,
        transport: TransportConfig? = nil,
        up_mbps: Int? = nil,
        down_mbps: Int? = nil,
        obfs: Hysteria2ObfsConfig? = nil,
        hop_interval: Int? = nil,
        outbounds: [String]? = nil,
        default: String? = nil
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
        self.username = username
        self.domain_resolver = domain_resolver
        self.multiplex = multiplex
        self.tls = tls
        self.transport = transport
        self.up_mbps = up_mbps
        self.down_mbps = down_mbps
        self.obfs = obfs
        self.hop_interval = hop_interval
        self.outbounds = outbounds
        self.`default` = `default`
    }
}

struct Hysteria2ObfsConfig: Codable {
    var type: String
    var password: String?
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
    var final: String?
    var independent_cache: Bool?

    init(servers: [DNSServer] = [], rules: [DNSRule] = [], final: String? = nil, independent_cache: Bool? = nil) {
        self.servers = servers
        self.rules = rules
        self.final = final
        self.independent_cache = independent_cache
    }
}

struct DNSRule: Codable {
    var server: String?
    var domain: [String]?
    var rule_set: [String]?
    var disable_cache: Bool?
    var action: String?
    var rcode: String?
    var query_type: [Int]?
    var ip_accept_any: Bool?
    var geosite: [String]?
    var geoip: [String]?
    var clash_mode: String?

    init(
        server: String? = nil,
        domain: [String]? = nil,
        rule_set: [String]? = nil,
        disable_cache: Bool? = nil,
        action: String? = nil,
        rcode: String? = nil,
        query_type: [Int]? = nil,
        ip_accept_any: Bool? = nil,
        geosite: [String]? = nil,
        geoip: [String]? = nil,
        clash_mode: String? = nil
    ) {
        self.server = server
        self.domain = domain
        self.rule_set = rule_set
        self.disable_cache = disable_cache
        self.action = action
        self.rcode = rcode
        self.query_type = query_type
        self.ip_accept_any = ip_accept_any
        self.geosite = geosite
        self.geoip = geoip
        self.clash_mode = clash_mode
    }
}

struct DNSServer: Codable {
    var type: String
    var tag: String?
    var server: String?
    var domain_resolver: String?
    var path: String?
    var detour: String?
    var predefined: [String: [String]]?
    var inet4_range: String?
    var inet6_range: String?

    init(
        type: String,
        tag: String? = nil,
        server: String? = nil,
        domain_resolver: String? = nil,
        path: String? = nil,
        detour: String? = nil,
        predefined: [String: [String]]? = nil,
        inet4_range: String? = nil,
        inet6_range: String? = nil
    ) {
        self.type = type
        self.tag = tag
        self.server = server
        self.domain_resolver = domain_resolver
        self.path = path
        self.detour = detour
        self.predefined = predefined
        self.inet4_range = inet4_range
        self.inet6_range = inet6_range
    }
}

// TUN stack type
enum TunStack: String, Codable, CaseIterable {
    case system
    case gvisor
    case mixed
}

// Route
struct RouteConfig: Codable {
    var auto_detect_interface: Bool = true
    var default_domain_resolver: String = "direct-dns"
    var rules: [RouteRule] = []
    var rule_set: [RuleSetConfig]? = nil
}

struct RuleSetConfig: Codable {
    var type: String
    var tag: String
    var format: String
    var path: String
}

struct RouteRule: Codable {
    var outbound: String?
    var action: String?
    var domain: [String]?
    var geosite: [String]?
    var geoip: [String]?
    var ip_cidr: [String]?
    var ip_is_private: Bool?
    var rule_set: [String]?
    var invert: Bool?
    var process_name: [String]?
    var inbound: [String]?
    var network: [String]?
    var port: [Int]?
    var `protocol`: [String]?
    var clash_mode: String?

    init(
        outbound: String? = nil,
        action: String? = nil,
        domain: [String]? = nil,
        geosite: [String]? = nil,
        geoip: [String]? = nil,
        ip_cidr: [String]? = nil,
        ip_is_private: Bool? = nil,
        rule_set: [String]? = nil,
        invert: Bool? = nil,
        process_name: [String]? = nil,
        inbound: [String]? = nil,
        network: [String]? = nil,
        port: [Int]? = nil,
        `protocol`: [String]? = nil,
        clash_mode: String? = nil
    ) {
        self.outbound = outbound
        self.action = action
        self.domain = domain
        self.geosite = geosite
        self.geoip = geoip
        self.ip_cidr = ip_cidr
        self.ip_is_private = ip_is_private
        self.rule_set = rule_set
        self.invert = invert
        self.process_name = process_name
        self.inbound = inbound
        self.network = network
        self.port = port
        self.`protocol` = `protocol`
        self.clash_mode = clash_mode
    }
}


enum SingboxBundledRuleSet {
    private static let geositeTags: [String: String] = [
        "category-ads-all": "geosite-category-ads-all",
        "cn": "geosite-cn",
        "geolocation-!cn": "geosite-geolocation-!cn",
    ]

    private static let geoipTags: [String: String] = [
        "cn": "geoip-cn",
    ]

    static func normalize(routeRules rules: [RouteRule], forceAll: Bool = false) -> (rules: [RouteRule], ruleSets: [RuleSetConfig]) {
        var usedTags: Set<String> = []
        let normalized = rules.map { rule in
            normalize(routeRule: rule, forceAll: forceAll, usedTags: &usedTags)
        }
        return (normalized, ruleSets(for: usedTags))
    }

    static func normalize(dnsRules rules: [DNSRule], forceAll: Bool = false) -> (rules: [DNSRule], ruleSets: [RuleSetConfig]) {
        var usedTags: Set<String> = []
        let normalized = rules.map { rule in
            normalize(dnsRule: rule, forceAll: forceAll, usedTags: &usedTags)
        }
        return (normalized, ruleSets(for: usedTags))
    }

    static func mergeRuleSets(_ groups: [RuleSetConfig]...) -> [RuleSetConfig]? {
        var seen: Set<String> = []
        var merged: [RuleSetConfig] = []
        for group in groups {
            for item in group where !seen.contains(item.tag) {
                seen.insert(item.tag)
                merged.append(item)
            }
        }
        return merged.isEmpty ? nil : merged
    }

    private static func normalize(routeRule rule: RouteRule, forceAll: Bool, usedTags: inout Set<String>) -> RouteRule {
        var rule = rule
        let geositeResult = consume(values: rule.geosite, table: geositeTags, defaultPrefix: "geosite", forceAll: forceAll, usedTags: &usedTags)
        let geoipResult = consume(values: rule.geoip, table: geoipTags, defaultPrefix: "geoip", forceAll: forceAll, usedTags: &usedTags)
        let ruleSet = (rule.rule_set ?? []) + geositeResult.tags + geoipResult.tags

        rule.geosite = geositeResult.remaining.isEmpty ? nil : geositeResult.remaining
        rule.geoip = geoipResult.remaining.isEmpty ? nil : geoipResult.remaining
        rule.rule_set = ruleSet.isEmpty ? nil : ruleSet
        return rule
    }

    private static func normalize(dnsRule rule: DNSRule, forceAll: Bool, usedTags: inout Set<String>) -> DNSRule {
        var rule = rule
        let geositeResult = consume(values: rule.geosite, table: geositeTags, defaultPrefix: "geosite", forceAll: forceAll, usedTags: &usedTags)
        let geoipResult = consume(values: rule.geoip, table: geoipTags, defaultPrefix: "geoip", forceAll: forceAll, usedTags: &usedTags)
        let ruleSet = (rule.rule_set ?? []) + geositeResult.tags + geoipResult.tags

        rule.geosite = geositeResult.remaining.isEmpty ? nil : geositeResult.remaining
        rule.geoip = geoipResult.remaining.isEmpty ? nil : geoipResult.remaining
        rule.rule_set = ruleSet.isEmpty ? nil : ruleSet
        return rule
    }

    private static func consume(values: [String]?, table: [String: String], defaultPrefix: String, forceAll: Bool, usedTags: inout Set<String>) -> (tags: [String], remaining: [String]) {
        guard let values else { return ([], []) }
        var tags: [String] = []
        var remaining: [String] = []
        for value in values {
            if let tag = table[value] {
                tags.append(tag)
                usedTags.insert(tag)
            } else if !forceAll {
                // keep unrecognized geosite/geoip for older sing-box versions
                remaining.append(value)
            }
            // forceAll: unrecognized values are dropped entirely
            // (no geosite/geoip support + no .srs file to back rule_set)
        }
        return (tags, remaining)
    }

    private static func ruleSets(for tags: Set<String>) -> [RuleSetConfig] {
        tags.sorted().map { tag in
            RuleSetConfig(
                type: "local",
                tag: tag,
                format: "binary",
                path: "\(singboxRuleSetPath)/\(tag).srs"
            )
        }
    }
}
