 //
//  V2rayOutbound.swift
//  V2rayU
//
//  Created by yanue on 2018/10/26.
//  Copyright © 2018 yanue. All rights reserved.
//

import Cocoa

protocol V2rayOutboundSettings: Codable {}

// MARK: - Protocol Definitions
enum V2rayProtocolOutbound: String, Codable, CaseIterable, Identifiable {
    case vmess, vless, trojan, shadowsocks, socks, dns, http, blackhole, freedom
    var id: Self { self }
}

// MARK: - V2rayOutbound Definition
final class V2rayOutbound: Codable {
    var sendThrough: String?
    var `protocol`: V2rayProtocolOutbound = .freedom
    var tag: String?
    var streamSettings: V2rayStreamSettings?
    var proxySettings: ProxySettings?
    var mux: V2rayOutboundMux?
    var settings: V2rayOutboundSettings?

    enum CodingKeys: String, CodingKey {
        case sendThrough, `protocol`, tag, streamSettings, proxySettings, mux, settings
    }
    
    // 空 init 初始化器
    init() {}
    
    // MARK: - Decoding
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        sendThrough = try? container.decode(String.self, forKey: .sendThrough)
        `protocol` = try container.decode(V2rayProtocolOutbound.self, forKey: .`protocol`)
        tag = try? container.decode(String.self, forKey: .tag)
        streamSettings = try? container.decode(V2rayStreamSettings.self, forKey: .streamSettings)
        proxySettings = try? container.decode(ProxySettings.self, forKey: .proxySettings)
        mux = try? container.decode(V2rayOutboundMux.self, forKey: .mux)

        // Dynamically decode settings based on protocol
        switch `protocol` {
        case .blackhole: settings = try? container.decode(V2rayOutboundBlackhole.self, forKey: .settings)
        case .freedom: settings = try? container.decode(V2rayOutboundFreedom.self, forKey: .settings)
        case .shadowsocks: settings = try? container.decode(V2rayOutboundShadowsocks.self, forKey: .settings)
        case .socks: settings = try? container.decode(V2rayOutboundSocks.self, forKey: .settings)
        case .vmess: settings = try? container.decode(V2rayOutboundVMess.self, forKey: .settings)
        case .dns: settings = try? container.decode(V2rayOutboundDns.self, forKey: .settings)
        case .http: settings = try? container.decode(V2rayOutboundHttp.self, forKey: .settings)
        case .vless: settings = try? container.decode(V2rayOutboundVLess.self, forKey: .settings)
        case .trojan: settings = try? container.decode(V2rayOutboundTrojan.self, forKey: .settings)
        }
    }

    // MARK: - Encoding
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encodeIfPresent(sendThrough, forKey: .sendThrough)
        try container.encode(`protocol`, forKey: .`protocol`)
        try container.encodeIfPresent(tag, forKey: .tag)
        try container.encodeIfPresent(streamSettings, forKey: .streamSettings)
        try container.encodeIfPresent(proxySettings, forKey: .proxySettings)
        try container.encodeIfPresent(mux, forKey: .mux)

        // Dynamically encode settings based on protocol
        switch settings {
        case let value as V2rayOutboundBlackhole: try container.encode(value, forKey: .settings)
        case let value as V2rayOutboundFreedom: try container.encode(value, forKey: .settings)
        case let value as V2rayOutboundShadowsocks: try container.encode(value, forKey: .settings)
        case let value as V2rayOutboundSocks: try container.encode(value, forKey: .settings)
        case let value as V2rayOutboundVMess: try container.encode(value, forKey: .settings)
        case let value as V2rayOutboundDns: try container.encode(value, forKey: .settings)
        case let value as V2rayOutboundHttp: try container.encode(value, forKey: .settings)
        case let value as V2rayOutboundVLess: try container.encode(value, forKey: .settings)
        case let value as V2rayOutboundTrojan: try container.encode(value, forKey: .settings)
        default: break
        }
    }
}

extension V2rayOutbound {
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

struct V2rayOutboundMux: Codable {
    var enabled: Bool = false
    var concurrency: Int = 8
    var xudpConcurrency: Int = 16
    var xudpProxyUDP443: Bool = false // 控制 Mux 对于被代理的 UDP/443（QUIC）流量的处理方式: reject-默认,allow-允许,skip-跳过
}

// protocol
// Blackhole
struct V2rayOutboundBlackhole: V2rayOutboundSettings {
    var response: V2rayOutboundBlackholeResponse = V2rayOutboundBlackholeResponse()
}

struct V2rayOutboundBlackholeResponse: Codable {
    var type: String = "http" // none | http - Blackhole 会发回一个简单的 HTTP 403 数据包，然后关闭连接。
}

// Freedom
struct V2rayOutboundFreedom: V2rayOutboundSettings {
    var domainStrategy: String? = "AsIs" // UseIP | AsIs
}

struct V2rayOutboundShadowsocks: V2rayOutboundSettings {
    var servers: [V2rayOutboundShadowsockServer] = [V2rayOutboundShadowsockServer()]
}

let V2rayOutboundShadowsockMethod = ["2022-blake3-aes-128-gcm", "2022-blake3-aes-256-gcm", "2022-blake3-chacha20-poly1305", "chacha20-ietf-poly1305", "chacha20-poly1305", "aes-128-gcm", "aes-256-gcm", "rc4-md5", "aes-128-cfb", "aes-192-cfb", "aes-256-cfb", "aes-128-ctr", "aes-192-ctr", "aes-256-ctr",  "aes-192-gcm", "camellia-128-cfb", "camellia-192-cfb", "camellia-256-cfb", "bf-cfb", "salsa20", "chacha20", "chacha20-ietf"]

struct V2rayOutboundShadowsockServer: Codable {
    var address: String = ""
    var port: Int = 0
    var method: String = "aes-256-gcm"
    var password: String = ""
    var uot: Bool = false // 必填。是否启用udp over tcp。
    var UoTVersion: Int = 2 // UDP over TCP 的实现版本。
    var email: String? // 选填
    var level: Int? // 选填,默认 0
}

struct V2rayOutboundSocks: V2rayOutboundSettings {
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

// VMess 依赖于系统时间，请确保使用 Xray 的系统 UTC 时间误差在 120 秒之内，时区无关。
struct V2rayOutboundVMess: V2rayOutboundSettings {
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
    var security: String = "auto" // aes-128-gcm/chacha20-poly1305/auto/none
}

struct V2rayOutboundDns: V2rayOutboundSettings {
    var network: String? // "tcp" | "udp" | ""
    var address: String? // dns地址如: 1.1.1.1
    var port: Int?
    var nonIPQuery: String? // drop | skip
    var blockTypes: [Int]? // 如 "blockTypes":[65,28] 表示屏蔽type 65(HTTPS) 和 28(AAAA)
}

struct V2rayOutboundHttp: V2rayOutboundSettings {
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

struct V2rayOutboundVLess: V2rayOutboundSettings {
    var vnext: [V2rayOutboundVLessItem] = [V2rayOutboundVLessItem()]
}

struct V2rayOutboundVLessItem: Codable {
    var address: String = ""
    var port: Int = 443
    var users: [V2rayOutboundVLessUser] = [V2rayOutboundVLessUser()]
}

struct V2rayOutboundVLessUser: Codable {
    var id: String = ""
    // 流控模式，用于选择 XTLS 的算法。
    // 目前出站协议中有以下流控模式可选：
    // 无 flow 或者 空字符： 使用普通 TLS 代理
    // xtls-rprx-vision：使用新 XTLS 模式 包含内层握手随机填充 支持 uTLS 模拟客户端指纹
    // xtls-rprx-vision-udp443：同 xtls-rprx-vision, 但是不会拦截目标为 443 端口的 UDP 流量
    // 此外，目前 XTLS 仅支持 TCP+TLS/Reality。
    var flow: String = ""
    var encryption: String = "none" // 必填,不能为空字符串,默认 none, 暂时只支持 none
    var level: Int? // 选填,默认 0
}

struct V2rayOutboundTrojan: V2rayOutboundSettings {
    var servers: [V2rayOutboundTrojanServer] = [V2rayOutboundTrojanServer()]
}

struct V2rayOutboundTrojanServer: Codable {
    var address: String = ""
    var port: Int = 0
    var password: String = ""
    var email: String? // 选填
    var level: Int? // 选填,默认 0
}
