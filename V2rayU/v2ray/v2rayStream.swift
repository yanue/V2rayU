//
//  v2rayStream.swift
//  V2rayU
//
//  Created by yanue on 2018/10/26.
//  Copyright © 2018 yanue. All rights reserved.
//

import Foundation

struct streamSettings: Codable {
    var tcpSettings: tcpSettings?
    var kcpSettings: kcpSettings?
    var wsSettings: wsSettings?
    var httpSettings: httpSettings?
    var dsSettings: dsSettings?
}

struct tlsSettings: Codable {
    var serverName: String?
    var alpn: String = "http/1.1"
    var allowInsecure: Bool // 是否允许不安全连接（用于客户端）。当值为 true 时，V2Ray 不会检查远端主机所提供的 TLS 证书的有效性。
    var allowInsecureCiphers: Bool
    var certificates: tlsCertificates?
}

struct tlsCertificates: Codable {
    enum usage: String, Codable {
        case encipherment
        case verify
        case issue
    }

    var usage: usage = .encipherment
    var certificateFile: String
    var keyFile: String
    var certificate: String
    var key: String
}

struct tcpSettings: Codable {

}

struct kcpSettings: Codable {
    var mtu, tti, uplinkCapacity, downlinkCapacity: Int
    var congestion: Bool
    var readBufferSize, writeBufferSize: Int
    var header: kcpSettingsHeader
}

struct kcpSettingsHeader: Codable {
    enum type: String, Codable {
        case none
        case srtp
        case utp
//        case `wechat-video`
        case dtls
        case wireguard
    }

    var type: type
}

struct wsSettings: Codable {
    var path: String
    var headers: wsSettingsHeader
}

struct wsSettingsHeader: Codable {
    var host: String
}

struct httpSettings: Codable {
    var host: [String]
    var path: String
}

struct dsSettings: Codable {
    var path: String
}

struct sockopt: Codable {
    enum tproxy:String,Codable {
        case redirect
        case tproxy
        case off
    }

    var mark: Int?
    var tcpFastOpen: Bool? // 是否启用 TCP Fast Open。
    var tproxy: tproxy = .off // 是否开启透明代理 (仅适用于 Linux)。
}