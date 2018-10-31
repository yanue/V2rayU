//
//  v2rayStruct.swift
//  V2rayU
//
//  Created by yanue on 2018/10/26.
//  Copyright © 2018 yanue. All rights reserved.
//

import Foundation

let outboundDetourTag = "direct"

struct v2rayStruct: Codable {
    var log: v2rayLog? = v2rayLog()
    var api: v2rayApi?
    var dns: v2rayDns? = v2rayDns()
    var stats: v2rayStats?
    var routing: v2rayRouting? = v2rayRouting()
    var policy: v2rayPolicy?
    var inbound: v2rayInbound?
    var inboundDetour: [v2rayInboundDetour]?
    var outbound: v2rayOutboundVMess?
    var outboundDetour: [v2rayOutboundDetour]?
    var transport: v2rayTransport?
}

// protocol
enum v2rayProtocol: String, Codable {
    case blackhole
    case dokodemoDoor
    case freedom
    case http
    case mtproto
    case shadowsocks
    case socks
    case vmess

    enum CodingKeys: String, CodingKey {
        case dokodemoDoor = "dokodemo-door"
    }
}

// log
struct v2rayLog: Codable {
    enum logLevel: String, Codable {
        case debug
        case info
        case warning
        case error
        case none
    }

    var loglevel: logLevel? = .info
    var error: String? = ""
    var access: String? = ""
}

struct v2rayApi: Codable {

}

struct v2rayDns: Codable {
    var servers: [String]? = ["1.1.1.1", "8.8.8.8", "8.8.4.4", "119.29.29.29", "114.114.114.114", "223.5.5.5", "223.6.6.6"]
}

struct v2rayStats: Codable {

}

struct v2rayRouting: Codable {
    var strategy: String = "rules"
    var settings: v2rayRoutingSetting = v2rayRoutingSetting()
}

struct v2rayRoutingSetting: Codable {
    enum domainStrategy: String, Codable {
        case AsIs
        case IPIfNonMatch
        case IPOnDemand
    }

    var domainStrategy: domainStrategy = .IPIfNonMatch
    var rules: [v2rayRoutingSettingRule] = [v2rayRoutingSettingRule()]
}

struct v2rayRoutingSettingRule: Codable {
    var type: String? = "field"
    var domain: [String]? = ["geosite:cn", "geosite:speedtest"]
    var ip: [String]? = ["geoip:cn", "geoip:private"]
    var port: String?
    var network: String?
    var source: [String]?
    var user: [String]?
    var inboundTag: [String]?
    var `protocol`: [String]? // ["http", "tls", "bittorrent"]
    var outboundTag: String? = outboundDetourTag
}

struct v2rayPolicy: Codable {
}

struct v2rayTransport: Codable {
    var tlsSettings: tlsSettings?
    var tcpSettings: tcpSettings?
    var kcpSettings: kcpSettings?
    var wsSettings: wsSettings?
    var httpSettings: httpSettings?
    var dsSettings: dsSettings?
}
