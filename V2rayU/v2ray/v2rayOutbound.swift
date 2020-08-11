//
//  V2rayOutbound.swift
//  V2rayU
//
//  Created by yanue on 2018/10/26.
//  Copyright © 2018 yanue. All rights reserved.
//

import Cocoa

// protocol
enum V2rayProtocolOutbound: String, Codable {
    case blackhole
    case freedom
    case shadowsocks
    case socks
    case vmess
    case dns
    case http
}

struct V2rayOutbound: Codable {
    var sendThrough: String?
    var `protocol`: V2rayProtocolOutbound = .freedom
    var tag: String? = ""
    var streamSettings: V2rayStreamSettings?
    var proxySettings: ProxySettings?
    var mux: V2rayOutboundMux?

    var settingBlackhole: V2rayOutboundBlackhole?
    var settingFreedom: V2rayOutboundFreedom?
    var settingShadowsocks: V2rayOutboundShadowsocks?
    var settingSocks: V2rayOutboundSocks?
    var settingVMess: V2rayOutboundVMess?
    var settingDns: V2rayOutboundDns?
    var settingHttp: V2rayOutboundHttp?

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

extension V2rayOutbound {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        `protocol` = try container.decode(V2rayProtocolOutbound.self, forKey: CodingKeys.`protocol`)
        tag = try container.decode(String.self, forKey: CodingKeys.tag)

        // ignore nil
        if !(try container.decodeNil(forKey: .sendThrough)) {
            sendThrough = try container.decode(String.self, forKey: CodingKeys.sendThrough)
        }

        // ignore nil
        if !(try container.decodeNil(forKey: .proxySettings)) {
            proxySettings = try container.decode(ProxySettings.self, forKey: CodingKeys.proxySettings)
        }

        // ignore nil
        if !(try container.decodeNil(forKey: .streamSettings)) {
            streamSettings = try container.decode(V2rayStreamSettings.self, forKey: CodingKeys.streamSettings)
        }

        // ignore nil
        if !(try container.decodeNil(forKey: .mux)) {
            mux = try container.decode(V2rayOutboundMux.self, forKey: CodingKeys.mux)
        }

        // decode settings depends on `protocol`
        switch `protocol` {
        case .blackhole:
            settingBlackhole = try container.decode(V2rayOutboundBlackhole.self, forKey: CodingKeys.settings)
            break
        case .freedom:
            settingFreedom = try container.decode(V2rayOutboundFreedom.self, forKey: CodingKeys.settings)
            break
        case .shadowsocks:
            settingShadowsocks = try container.decode(V2rayOutboundShadowsocks.self, forKey: CodingKeys.settings)
            break
        case .socks:
            settingSocks = try container.decode(V2rayOutboundSocks.self, forKey: CodingKeys.settings)
            break
        case .vmess:
            settingVMess = try container.decode(V2rayOutboundVMess.self, forKey: CodingKeys.settings)
            break
        case .dns:
            settingDns = try container.decode(V2rayOutboundDns.self, forKey: CodingKeys.settings)
            break
        case .http:
            settingHttp = try container.decode(V2rayOutboundHttp.self, forKey: CodingKeys.settings)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(`protocol`, forKey: .`protocol`)
        try container.encode(tag, forKey: .tag)

        // ignore nil
        if streamSettings != nil {
            try container.encode(streamSettings, forKey: .streamSettings)
        }

        // ignore nil
        if sendThrough != nil && sendThrough!.count > 0 {
            try container.encode(sendThrough, forKey: .sendThrough)
        }

        // ignore nil
        if proxySettings != nil {
            try container.encode(proxySettings, forKey: .proxySettings)
        }

        // ignore nil
        if mux != nil {
            try container.encode(mux, forKey: .mux)
        }

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
        case .dns:
            try container.encode(self.settingDns, forKey: .settings)
            break
        case .http:
            try container.encode(self.settingHttp, forKey: .settings)
            break
        }
    }
}

struct V2rayOutboundMux: Codable {
    var enabled: Bool = false
    var concurrency: Int = 8
}

// protocol
// Blackhole
struct V2rayOutboundBlackhole: Codable {
    var response: V2rayOutboundBlackholeResponse = V2rayOutboundBlackholeResponse()
}

struct V2rayOutboundBlackholeResponse: Codable {
    var type: String? = "none" // none | http
}

struct V2rayOutboundFreedom: Codable {
    // Freedom
    var domainStrategy: String = "UseIP"// UseIP | AsIs
    var redirect: String?
    var userLevel: Int = 0
}

struct V2rayOutboundShadowsocks: Codable {
    var servers: [V2rayOutboundShadowsockServer] = [V2rayOutboundShadowsockServer()]
}

let V2rayOutboundShadowsockMethod = ["rc4-md5", "aes-128-cfb", "aes-192-cfb", "aes-256-cfb", "aes-128-ctr", "aes-192-ctr", "aes-256-ctr", "aes-128-gcm", "aes-192-gcm", "aes-256-gcm", "camellia-128-cfb", "camellia-192-cfb", "camellia-256-cfb", "bf-cfb", "salsa20", "chacha20", "chacha20-ietf", "chacha20-ietf-poly1305"]

struct V2rayOutboundShadowsockServer: Codable {
    var email: String = ""
    var address: String = ""
    var port: Int = 0
    // V2rayOutboundShadowsockMethod
    var method: String = "aes-256-cfb"
    var password: String = ""
    var ota: Bool = false
    var level: Int = 0
}

struct V2rayOutboundSocks: Codable {
    var servers: [V2rayOutboundSockServer] = [V2rayOutboundSockServer()]
}

struct V2rayOutboundSockServer: Codable {
    var address: String = ""
    var port: Int = 0
    var users: [V2rayOutboundSockUser]?
}

struct V2rayOutboundSockUser: Codable {
    var user: String = ""
    var pass: String = ""
    var level: Int = 0
}

struct V2rayOutboundVMess: Codable {
    var vnext: [V2rayOutboundVMessItem] = [V2rayOutboundVMessItem()]
}

struct V2rayOutboundVMessItem: Codable {
    var address: String = ""
    var port: Int = 443
    var users: [V2rayOutboundVMessUser] = [V2rayOutboundVMessUser()]
}

let V2rayOutboundVMessSecurity = ["aes-128-gcm", "chacha20-poly1305", "auto", "none"]

struct V2rayOutboundVMessUser: Codable {
    var id: String = ""
    var alterId: Int = 64// 0-65535
    var level: Int = 0
    // V2rayOutboundVMessSecurity
    var security: String = "auto" // aes-128-gcm/chacha20-poly1305/auto/none
}

struct V2rayOutboundDns: Codable {
    var network: String = "" // "tcp" | "udp" | ""
    var address: String = ""
    var port: Int?
}

struct V2rayOutboundHttp: Codable {
    var servers: [V2rayOutboundHttpServer] = [V2rayOutboundHttpServer()]
}

struct V2rayOutboundHttpServer: Codable {
    var address: String = ""
    var port: Int = 0
    var users: [V2rayOutboundHttpUser] = [V2rayOutboundHttpUser()]
}

struct V2rayOutboundHttpUser: Codable {
    var user: String = ""
    var pass: String = ""
}
