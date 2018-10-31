//
//  v2rayOutbound.swift
//  V2rayU
//
//  Created by yanue on 2018/10/26.
//  Copyright © 2018 yanue. All rights reserved.
//

import Foundation

// protocol
enum v2rayProtocolOutbound: String, Codable {
    case blackhole
    case freedom
    case mtproto
    case shadowsocks
    case socks
    case vmess
}

struct v2rayOutbound: Codable {
    var sendThrough: String?
    var `protocol`: v2rayProtocolOutbound = .freedom
    var tag: String? = outboundDetourTag
//    var streamSettings: streamSettings?
    var proxySettings: proxySettings?
    var mux: v2rayOutboundMux?

    var settingBlackhole: v2rayOutboundBlackhole?
    var settingFreedom: v2rayOutboundFreedom?
    var settingShadowsocks: v2rayOutboundShadowsocks?
    var settingSocks: v2rayOutboundSocks?
    var settingVMess: v2rayOutboundVMess?

    enum CodingKeys: String, CodingKey {
        case sendThrough
        case `protocol`
        case tag
        case streamSettings
        case proxySettings
        case mux
        case settings // auto switch by protocol
    }
}

extension v2rayOutbound {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        `protocol` = try container.decode(v2rayProtocolOutbound.self, forKey: CodingKeys.`protocol`)
        tag = try container.decode(String.self, forKey: CodingKeys.tag)

        // ignore nil
//        if !(try container.decodeNil(forKey: .streamSettings)) {
//            streamSettings = try container.decode(streamSettings.self, forKey: CodingKeys.streamSettings)
//        }

        // decode settings depends on `protocol`
        switch `protocol` {
        case .blackhole:
            settingBlackhole = try container.decode(v2rayOutboundBlackhole.self, forKey: CodingKeys.settings)
            break
        case .freedom:
            settingFreedom = try container.decode(v2rayOutboundFreedom.self, forKey: CodingKeys.settings)
            break
        case .shadowsocks:
            settingShadowsocks = try container.decode(v2rayOutboundShadowsocks.self, forKey: CodingKeys.settings)
            break
        case .socks:
            settingSocks = try container.decode(v2rayOutboundSocks.self, forKey: CodingKeys.settings)
            break
        case .mtproto:
            break
        case .vmess:
            settingVMess = try container.decode(v2rayOutboundVMess.self, forKey: CodingKeys.settings)
            break
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(`protocol`, forKey: .`protocol`)
        try container.encode(tag, forKey: .tag)

        // ignore nil
//        if streamSettings != nil {
//            try container.encode(streamSettings, forKey: .streamSettings)
//        }

        // encode settings depends on `protocol`
        switch `protocol` {
        case .shadowsocks:
            try container.encode(self.settingShadowsocks, forKey: .settings)
            break
        case .socks:
            try container.encode(self.settingSocks, forKey: .settings)
            break
        case .vmess:
            try container.encode(self.settingVMess, forKey: .settings)
            break
        case .blackhole:
            try container.encode(self.settingBlackhole, forKey: .settings)
            break
        case .freedom:
            try container.encode(self.settingFreedom, forKey: .settings)
            break
        case .mtproto:
            break
        }
    }
}

struct v2rayOutboundDetour: Codable {
    var sendThrough: String?
    var `protocol`: v2rayProtocolOutbound = .freedom
    var tag: String? = outboundDetourTag
    var streamSettings: streamSettings?
    var proxySettings: proxySettings?
    var Mux: v2rayOutboundMux?
}

struct v2rayOutboundMux: Codable {
    var enabled: Bool = false
    var concurrency: Int = 8
}

// protocol
// Blackhole
struct v2rayOutboundBlackhole: Codable {
    var response: v2rayOutboundBlackholeResponse?
}

struct v2rayOutboundBlackholeResponse: Codable {
    enum type: String, Codable {
        case none
        case http
    }

    var type: type = .none
}

struct v2rayOutboundFreedom: Codable {
    // Freedom
    var domainStrategy: String = "AsIs"// UseIP | AsIs
    var redirect: String?
    var userLevel: Int = 0
}

struct v2rayOutboundShadowsocks: Codable {
    var servers: [v2rayOutboundShadowsockServer]?
}

struct v2rayOutboundShadowsockServer: Codable {
    var email: String?
    var address: String?
    var port: Int?
    var method: String?
    var password: String?
    var ota: Bool? = false
    var level: Int = 0
}

struct v2rayOutboundSocks: Codable {
    var address: String?
    var port: String?
    var users: [v2rayOutboundSockUser]?
}

struct v2rayOutboundSockUser: Codable {
    var user: String?
    var pass: String?
    var level: Int = 0
}

struct v2rayOutboundVMess: Codable {
    var vnext: [v2rayOutboundVMessItem]
}

struct v2rayOutboundVMessItem: Codable {
    var address: String?
    var port: String?
    var users: [v2rayOutboundVMessUser]?
}

struct v2rayOutboundVMessUser: Codable {
    var id: String?
    var alterId: Int? // 0-65535
    var level: Int?
    var security: String? // aes-128-gcm/chacha20-poly1305/auto/none
}