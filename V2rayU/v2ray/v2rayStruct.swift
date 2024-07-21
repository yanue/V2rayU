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
    var stats: V2rayStats?
    var routing: V2rayRouting = V2rayRouting()
    var policy: V2rayPolicy?
    var inbounds: [V2rayInbound]? // > 4.0
    var outbounds: [V2rayOutbound]? // > 4.0
    var transport: V2rayTransport?
}

// protocol
enum V2rayProtocolInbound: String, CaseIterable, Codable {
    case http
    case shadowsocks
    case socks
    case vmess
    case vless
    case trojan
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

}

struct V2rayDns: Codable {
    var servers: [String]?
}

struct V2rayStats: Codable {

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
    var domainMatcher: domainMatcher? = .hybrid
    var rules: [V2rayRoutingRule] = []
    var balancers: [V2rayRoutingBalancer]? = []
}

struct V2rayRoutingRule: Codable {
    var domainMatcher: String? = "hybrid"
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
    var balancerTag: String? = "balancer"
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
}
