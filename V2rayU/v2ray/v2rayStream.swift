//
//  v2rayStream.swift
//  V2rayU
//
//  Created by yanue on 2018/10/26.
//  Copyright © 2018 yanue. All rights reserved.
//

import Foundation

struct V2rayTransport: Codable {
    var tlsSettings: TlsSettings?
    var tcpSettings: TcpSettings?
    var kcpSettings: KcpSettings?
    var wsSettings: WsSettings?
    var httpSettings: HttpSettings?
    var dsSettings: DsSettings?
}

struct V2rayStreamSettings: Codable {
    enum network: String, Codable {
        case tcp
        case kcp
        case ws
        case http
        case h2
        case domainsocket
    }

    enum security: String, Codable {
        case none
        case tls
    }

    var network: network = .tcp
    var security: security = .none
    var sockopt: V2rayStreamSettingSockopt?
    var tlsSettings: TlsSettings?
    var tcpSettings: TcpSettings?
    var kcpSettings: KcpSettings?
    var wsSettings: WsSettings?
    var httpSettings: HttpSettings?
    var dsSettings: DsSettings?
}

struct TlsSettings: Codable {
    var serverName: String?
    var alpn: String? = "http/1.1"
    var allowInsecure: Bool? // 是否允许不安全连接（用于客户端）。当值为 true 时，V2Ray 不会检查远端主机所提供的 TLS 证书的有效性。
    var allowInsecureCiphers: Bool?
    var certificates: TlsCertificates?
}

struct TlsCertificates: Codable {
    enum usage: String, Codable {
        case encipherment
        case verify
        case issue
    }

    var usage: usage? = .encipherment
    var certificateFile: String?
    var keyFile: String?
    var certificate: String?
    var key: String?
}

struct TcpSettings: Codable {
    var header: TcpSettingHeader? = TcpSettingHeader()
}

struct TcpSettingHeader: Codable {
    var type: String? = "none"
    var request: TcpSettingHeaderRequest?
    var response: TcpSettingHeaderResponse?
}

struct TcpSettingHeaderRequest: Codable {
    var version: String?
    var method: String?
    var path: [String]?
    var headers: TcpSettingHeaderRequestHeaders?
}

struct TcpSettingHeaderRequestHeaders: Codable {
    var host, userAgent, acceptEncoding, connection: [String]?
    var pragma: String?

    enum CodingKeys: String, CodingKey {
        case host = "Host"
        case userAgent = "User-Agent"
        case acceptEncoding = "Accept-Encoding"
        case connection = "Connection"
        case pragma = "Pragma"
    }
}

struct TcpSettingHeaderResponse: Codable {
    var version, status, reason: String?
    var headers: TcpSettingHeaderResponseHeaders?
}

struct TcpSettingHeaderResponseHeaders: Codable {
    var contentType, transferEncoding, connection: [String]?
    var pragma: String?

    enum CodingKeys: String, CodingKey {
        case contentType = "Content-Type"
        case transferEncoding = "Transfer-Encoding"
        case connection = "Connection"
        case pragma = "Pragma"
    }
}

struct KcpSettings: Codable {
    var mtu, tti, uplinkCapacity, downlinkCapacity: Int?
    var congestion: Bool?
    var readBufferSize, writeBufferSize: Int?
    var header: KcpSettingsHeader?
}

var KcpSettingsHeaderType = ["none", "srtp", "utp", "wechat-video", "dtls", "wireguard"]

struct KcpSettingsHeader: Codable {
    // KcpSettingsHeaderType
    var type: String? = "none"
}

struct WsSettings: Codable {
    var path: String?
    var headers: WsSettingsHeader = WsSettingsHeader()
}

struct WsSettingsHeader: Codable {
    var host: String?
}

struct HttpSettings: Codable {
    var host: [String]?
    var path: String?
}

struct DsSettings: Codable {
    var path: String?
}

struct V2rayStreamSettingSockopt: Codable {
    enum tproxy: String, Codable {
        case redirect
        case tproxy
        case off
    }

    var mark: Int?
    var tcpFastOpen: Bool? // 是否启用 TCP Fast Open。
    var tproxy: tproxy = .off // 是否开启透明代理 (仅适用于 Linux)。
}