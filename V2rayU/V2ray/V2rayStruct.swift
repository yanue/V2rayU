//
//  V2rayStruct.swift
//  V2rayU
//
//  Created by yanue on 2018/10/26.
//  Copyright © 2018 yanue. All rights reserved.
//

import Cocoa

// doc: https://www.v2ray.com/chapter_02/01_overview.html

struct V2rayStruct: Codable {
    var log: V2rayLog = V2rayLog()
    var api: V2rayApi?
    var dns: V2rayDns = V2rayDns()
    var stats: V2rayStats = V2rayStats()
    var routing: V2rayRouting = V2rayRouting()
    var policy: V2rayPolicy?
    var inbounds: [V2rayInbound]?
    var outbounds: [V2rayOutbound]?
    var observatory: V2rayObservatory = V2rayObservatory()
}

extension V2rayStruct {
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

// log
struct V2rayLog: Codable {
    enum logLevel: String, Codable {
        case debug
        case info
        case warning
        case error
        case none
    }

    var loglevel: logLevel = .info
    var error: String = ""
    var access: String = ""
}

struct V2rayApi: Codable {
    var tag: String = "api" // 用于标识 API 的标识符,需要在 routing 中设置增加规则: {"inboundTag": ["api"], "outboundTag": "api", "type": "field"}
    var listen: String = "127.0.0.1:1085" // 1.8.12起 这里不设置就需要在 inbounds 中设置
    var services: [String] = ["StatsService"]
}

struct V2rayDns: Codable {
    // 复杂的配置,直接替换整个结构体即可
}

struct V2rayStats: Codable {
    // 没有配置,空结构体{}即可统计,需配合policy使用
}

struct V2rayRouting: Codable {
    enum domainStrategy: String, Codable {
        case AsIs
        case IPIfNonMatch
        case IPOnDemand
    }
    enum domainMatcher: String, Codable {
        case hybrid
        case linear
    }
    
    var domainStrategy: domainStrategy = .AsIs
    var domainMatcher: domainMatcher?
    var rules: [V2rayRoutingRule] = []
    var balancers: [V2rayRoutingBalancer]? = []
}

struct V2rayRoutingRule: Codable {
    var domainMatcher: String?
    var type: String = "field"
    var domain: [String]? = []
    var ip: [String]? = []
    var port: String?
    var sourcePort: String?
    var network: String?
    var source: [String]?
    var user: [String]?
    var inboundTag: [String]?
    var `protocol`: [String]? // ["http", "tls", "bittorrent"]
    var outboundTag: String? = "direct"
    var balancerTag: String?
}

struct V2rayRoutingBalancer: Codable {
    var selector: [String]?
    var strategy: V2rayRoutingBalancerStrategy?
    var tag: String?
    var fallbackTag: String?
}

struct V2rayRoutingBalancerStrategy: Codable {
    var type: String? // type : "random" | "roundRobin" | "leastPing" | "leastLoad"
}

struct V2rayPolicy: Codable {
    var system: SystemPolicy = SystemPolicy()
}

struct SystemPolicy: Codable {
    var statsInboundUplink: Bool = true
    var statsInboundDownlink: Bool = true
    var statsOutboundUplink: Bool = true
    var statsOutboundDownlink: Bool = true
}

struct V2rayObservatory: Codable {
    var subjectSelector: [String] = ["outbound"]
    var probeUrl: String = "https://www.google.com/generate_204"
    var probeInterval: String = "10s"
    var enableConcurrency: Bool = false
}
