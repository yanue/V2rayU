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
//    var strategy: String = "rules"
    var settings: V2rayRoutingSetting = V2rayRoutingSetting()
}

struct V2rayRoutingSetting: Codable {
    enum domainStrategy: String, Codable {
        case AsIs
        case IPIfNonMatch
        case IPOnDemand
    }

    var domainStrategy: domainStrategy = .AsIs
    var rules: [V2rayRoutingSettingRule] = []
}

struct V2rayRoutingSettingRule: Codable {
    var type: String = "field"
    var domain: [String]? = []
    var ip: [String]? = []
    var port: String?
    var network: String?
    var source: [String]?
    var user: [String]?
    var inboundTag: [String]?
    var `protocol`: [String]? // ["http", "tls", "bittorrent"]
    var outboundTag: String? = "direct"
}

struct V2rayPolicy: Codable {
}
