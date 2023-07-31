//
//  v2rayStream.swift
//  V2rayU
//
//  Created by yanue on 2018/10/26.
//  Copyright © 2018 yanue. All rights reserved.
//

import Cocoa

struct V2rayTransport: Codable {
    var tlsSettings: TlsSettings?
    var tcpSettings: TcpSettings?
    var kcpSettings: KcpSettings?
    var wsSettings: WsSettings?
    var httpSettings: HttpSettings?
    var dsSettings: DsSettings?
    var quicSettings: QuicSettings?
    var xtlsSettings: TlsSettings?
    var realitySettings: RealitySettings?
    var grpcSettings: GrpcSettings?
}

struct V2rayStreamSettings: Codable {
    enum network: String, Codable {
        case tcp
        case kcp
        case ws
        case http
        case h2
        case domainsocket
        case quic
        case grpc
    }

    enum security: String, Codable {
        case none
        case tls
        case xtls
        case reality // for vless
    }

    var network: network = .tcp
    var security: security = .none
    var sockopt: V2rayStreamSettingSockopt?
    // transport
    var tcpSettings: TcpSettings?
    var kcpSettings: KcpSettings?
    var wsSettings: WsSettings?
    var httpSettings: HttpSettings?
    var dsSettings: DsSettings?
    var quicSettings: QuicSettings?
    var grpcSettings: GrpcSettings?
    // security
    var tlsSettings: TlsSettings?
    var xtlsSettings: TlsSettings?
    var realitySettings: RealitySettings?
}

struct TlsSettings: Codable {
    var serverName: String = ""
    var allowInsecure: Bool = true
    var allowInsecureCiphers: Bool?
    var certificates: TlsCertificates?
    var alpn: String?
    var fingerprint: String = "chrome" // 必填，使用 tls 库模拟客户端 TLS 指纹
}

struct RealitySettings: Codable {
    var show: Bool = true  // 选填，若为 true，输出调试信息
    var fingerprint: String = "chrome" // 必填，使用 uTLS 库模拟客户端 TLS 指纹
    var serverName: String = "" // 服务端 serverNames 之一
    var publicKey: String = "" // 服务端私钥对应的公钥
    var shortId: String = "" // 服务端 shortIds 之一
    var spiderX: String = "" // 爬虫初始路径与参数，建议每个客户端不同
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
    var header: TcpSettingHeader = TcpSettingHeader()
}

struct TcpSettingHeader: Codable {
    var type: String = "none" // http or none
    var request: TcpSettingHeaderRequest?
    var response: TcpSettingHeaderResponse?
}

struct TcpSettingHeaderRequest: Codable {
    var version: String = ""
    var method: String = ""
    var path: [String] = []
    var headers: TcpSettingHeaderRequestHeaders = TcpSettingHeaderRequestHeaders()
}

struct TcpSettingHeaderRequestHeaders: Codable {
    var host: [String] = []
    var userAgent: [String] = []
    var acceptEncoding: [String] = []
    var connection: [String] = []
    var pragma: String = ""

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
    var mtu: Int = 1350
    var tti: Int = 20
    var uplinkCapacity: Int = 50
    var downlinkCapacity: Int = 20
    var congestion: Bool = false
    var readBufferSize: Int = 1
    var writeBufferSize: Int = 1
    var header: KcpSettingsHeader = KcpSettingsHeader()
}

var KcpSettingsHeaderType = ["none", "srtp", "utp", "wechat-video", "dtls", "wireguard"]

struct KcpSettingsHeader: Codable {
    // KcpSettingsHeaderType
    var type: String = "none"
}

struct WsSettings: Codable {
    var path: String = ""
    var headers: WsSettingsHeader = WsSettingsHeader()
}

struct WsSettingsHeader: Codable {
    var host: String = ""
}

struct HttpSettings: Codable {
    var host: [String] = [""]
    var path: String = ""
}

struct DsSettings: Codable {
    var path: String = ""
}

struct V2rayStreamSettingSockopt: Codable {
    enum tproxy: String, Codable {
        case redirect
        case tproxy
        case off
    }

    var mark: Int = 0
    var tcpFastOpen: Bool = false // 是否启用 TCP Fast Open。
    var tproxy: tproxy = .off // 是否开启透明代理 (仅适用于 Linux)。
}


var QuicSettingsSecurity = ["none", "aes-128-gcm", "chacha20-poly1305"]

struct QuicSettings: Codable {
    //  QuicSettingsSecurity
    var security: String = "none"
    var key: String = ""
    var header: QuicSettingHeader = QuicSettingHeader()
}

var QuicSettingsHeaderType = ["none", "srtp", "utp", "wechat-video", "dtls", "wireguard"]

struct QuicSettingHeader: Codable {
    // QuicSettingsHeaderType
    var type: String = "none"
}

struct GrpcSettings: Codable {
    var serviceName: String = ""
    var multiMode: Bool = false
    var user_agent: String = ""
    var idle_timeout: Int = 60
    var health_check_timeout: Int = 60
    var permit_without_stream: Bool = false
    var initial_windows_size: Int = 0
}
