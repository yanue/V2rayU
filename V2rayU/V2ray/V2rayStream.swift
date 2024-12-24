//
//  v2rayStream.swift
//  V2rayU
//
//  Created by yanue on 2018/10/26.
//  Copyright © 2018 yanue. All rights reserved.
//

import Cocoa

// protocol
enum V2rayStreamNetwork: String, Codable, CaseIterable, Identifiable {
    case tcp
    case ws
    case h2
    case grpc
    case quic
    case kcp
    case domainsocket
    case xhttp
    var id: Self { self }
}

enum V2rayStreamSecurity: String, Codable, CaseIterable, Identifiable {
    case none
    case tls
    case xtls
    case reality // for vless
    var id: Self { self }
}

enum V2rayStreamAlpn: String, Codable, CaseIterable, Identifiable {
    case none = ""
    case h3 = "h3"
    case h2 = "h2"
    case h1 = "http1.1"
    case h3h2 = "h3,h2"
    case h2h1 = "h2,http1.1"
    case h3h2h1 = "h3,h2,http1.1"
    var id: Self { self }
}

enum V2rayStreamFingerprint: String, Codable, CaseIterable, Identifiable {
    case none = ""
    case chrome
    case edge
    case firefox
    case safari
    case ios
    case android
    case random
    case randomized
    var id: Self { self }
}


enum V2rayHeaderType: String, Codable, CaseIterable, Identifiable {
    case none
    case http
    var id: Self { self }
}


struct V2rayStreamSettings: Codable {
    var network: V2rayStreamNetwork = .tcp
    var security: V2rayStreamSecurity = .none
    var sockopt: V2rayStreamSettingSockopt?
    // transport
    var tcpSettings: TcpSettings?
    var rawSettings: TcpSettings? // 更名自曾经的 TCP 传输层,和 tcpSettings 配置一样,为兼容旧版本,请使用 tcpSettings
    var kcpSettings: KcpSettings?
    var wsSettings: WsSettings?
    var httpSettings: HttpSettings?
    var dsSettings: DsSettings?
    var quicSettings: QuicSettings?
    var grpcSettings: GrpcSettings?
    var xhttpSettings: XhttpSettings?
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
    var version: String? // 默认 "1.1"
    var method: String? // 默认 "GET"
    var path: [String] = ["/"] // 默认 "/"。当有多个值时，每次请求随机选择一个值。
    var headers: TcpSettingHeaderRequestHeaders = TcpSettingHeaderRequestHeaders()
}

struct TcpSettingHeaderRequestHeaders: Codable {
    var host: [String] = []
    var userAgent: [String] = ["Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36"]
    var acceptEncoding: [String]? // 默认 ["gzip", "deflate"]
    var connection: [String]? // 默认 ["keep-alive"]
    var pragma: String? // 默认 "no-cache"

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

// mKCP 使用 UDP 来模拟 TCP 连接。
// mKCP 牺牲带宽来降低延迟。传输同样的内容，mKCP 一般比 TCP 消耗更多的流量。
struct KcpSettings: Codable {
    var mtu: Int = 1350 // 最大传输单元（maximum transmission unit） 请选择一个介于 576 - 1460 之间的值。
    var tti: Int = 50 // 传输时间间隔（transmission time interval），单位毫秒（ms），mKCP 将以这个时间频率发送数据。 请选译一个介于 10 - 100 之间的值。
    var uplinkCapacity: Int = 5 // 上行链路容量，即主机发出数据所用的最大带宽，单位 MB/s，注意是 Byte 而非 bit。 可以设置为 0，表示一个非常小的带宽。
    var downlinkCapacity: Int = 20 // 下行链路容量，即主机接收数据所用的最大带宽，单位 MB/s，注意是 Byte 而非 bit。 可以设置为 0，表示一个非常小的带宽。
    var congestion: Bool = false // 是否启用拥塞控制。开启拥塞控制之后，Xray 会自动监测网络质量，当丢包严重时，会自动降低吞吐量；当网络畅通时，也会适当增加吞吐量。
    var readBufferSize: Int = 2 // 单个连接的读取缓冲区大小，单位是 MB。
    var writeBufferSize: Int = 2 // 单个连接的写入缓冲区大小，单位是 MB。
    var seed: String = "" // 可选的混淆密码，使用 AES-128-GCM 算法混淆流量数据，客户端和服务端需要保持一致。
    var header: KcpSettingsHeader = KcpSettingsHeader()
}

let KcpSettingsHeaderType = ["none", "srtp", "utp", "wechat-video", "dtls", "wireguard", "dns"]

struct KcpSettingsHeader: Codable {
    // KcpSettingsHeaderType
    var type: String = "none"
    var domain: String = "" // type为"dns"使用域名伪装，填写一个域名。
}

struct WsSettings: Codable {
    var path: String = "/" // 默认 "/"
    var host: [String] = [""] // 为了兼容旧版,设置host同时设置headers.Host
    var heartbeatPeriod: Int? // 心跳周期，单位秒。默认值 0 表示不发送心跳。
    var headers: WsSettingsHeader = WsSettingsHeader()
}

struct WsSettingsHeader: Codable {
    // 当在服务端指定该值，或在 headers 中指定host，将会校验与客户端请求host是否一致。
    var Host: String = "" // 默认 ""
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


let QuicSettingsSecurity = ["none", "aes-128-gcm", "chacha20-poly1305"]

struct QuicSettings: Codable {
    //  QuicSettingsSecurity
    var security: String = "none"
    var key: String = ""
    var header: QuicSettingHeader = QuicSettingHeader()
}

let QuicSettingsHeaderType = ["none", "srtp", "utp", "wechat-video", "dtls", "wireguard"]

struct QuicSettingHeader: Codable {
    // QuicSettingsHeaderType
    var type: String = "none"
}

struct GrpcSettings: Codable {
    var authority: String? // 一个字符串，可以当 Host 来用，实现一些其它用途
    // 在服务端填写 "serviceName": "/my/sample/path1|path2"，客户端可填写 "serviceName": "/my/sample/path1" 或 "/my/sample/path2"。
    var serviceName: String = "" // 一个字符串，指定服务名称，类似于 HTTP/2 中的 Path。 客户端会使用此名称进行通信，服务端会验证服务名称是否匹配。
    var multiMode: Bool = false
    var user_agent: String?
    var idle_timeout: Int = 60
    var health_check_timeout: Int = 20
    var permit_without_stream: Bool = false
    var initial_windows_size: Int = 0
}

struct XhttpSettings: Codable {
    var path: String = "/" // 无论是 TLS 还是 REALITY，一般来说 XHTTP 配置只需填 path，其它不填即可
    var host: String = "" // host 的行为与 Xray 其它基于 HTTP 的传输层一致，客户端发送 host 的优先级为 host > serverName > address。服务端若设了 host，将会检查客户端发来的值是否一致，否则不会检查，建议没事别设。host 不可填在 headers 内。
    var mode: String = "auto"
    // extra 是 host、path、mode 以外的所有参数的原始 JSON 分享方案，当 extra 存在时，只有该四项会生效。且分享链接中只有这四项，
    // GUI 一般也只有这四项，因为 extra 中的参数都相对低频，且应当由服务发布者直接下发给客户端，不应该让客户端随意改。
    var extra: XhttpSettingExtra?
}

struct XhttpSettingExtra: Codable {
    var headers: [String: String]?
    var xPaddingBytes: String = "100-1000"
    var noGRPCHeader: Bool = false
    var noSSEHeader: Bool = false
    var scMaxEachPostBytes: Int = 1000000
    var scMinPostsIntervalMs: Int = 30
    var scMaxBufferedPosts: Int = 30
    var xmux: XhttpSettingExtraXmux? // 默认
//    var downloadSettings: V2rayStreamSettings? // 全新的streamSettings配置,用于下行流量
}

struct XhttpSettingExtraXmux: Codable {
    var maxConcurrency: String = "16-32"
    var maxConnections: Int = 0
    var cMaxReuseTimes: String = "64-128"
    var cMaxLifetimeMs: Int = 0
    var hMaxRequestTimes: String = "800-900"
    var hKeepAlivePeriod: Int = 0
}
