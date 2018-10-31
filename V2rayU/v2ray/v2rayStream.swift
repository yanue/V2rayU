//
//  v2rayStream.swift
//  V2rayU
//
//  Created by yanue on 2018/10/26.
//  Copyright © 2018 yanue. All rights reserved.
//

import Foundation

struct StreamSettings: Codable {
    var tcpSettings: TcpSettings?
    var kcpSettings: KcpSettings?
    var wsSettings: WsSettings?
    var httpSettings: HttpSettings?
    var dsSettings: DsSettings?
}

struct TlsSettings: Codable {
    var serverName: String?
    var alpn: String = "http/1.1"
    var allowInsecure: Bool // 是否允许不安全连接（用于客户端）。当值为 true 时，V2Ray 不会检查远端主机所提供的 TLS 证书的有效性。
    var allowInsecureCiphers: Bool
    var certificates: TlsCertificates?
}

struct TlsCertificates: Codable {
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

struct TcpSettings: Codable {

}

struct KcpSettings: Codable {
    var mtu, tti, uplinkCapacity, downlinkCapacity: Int
    var congestion: Bool
    var readBufferSize, writeBufferSize: Int
    var header: KcpSettingsHeader
}

struct KcpSettingsHeader: Codable {
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

struct WsSettings: Codable {
    var path: String
    var headers: WsSettingsHeader
}

struct WsSettingsHeader: Codable {
    var host: String
}

struct HttpSettings: Codable {
    var host: [String]
    var path: String
}

struct DsSettings: Codable {
    var path: String
}

struct Sockopt: Codable {
    enum tproxy:String,Codable {
        case redirect
        case tproxy
        case off
    }

    var mark: Int?
    var tcpFastOpen: Bool? // 是否启用 TCP Fast Open。
    var tproxy: tproxy = .off // 是否开启透明代理 (仅适用于 Linux)。
}