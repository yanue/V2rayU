import Foundation

/**
 - {"type":"ss","name":"v2rayse_test_1","server":"198.57.27.218","port":5004,"cipher":"aes-256-gcm","password":"g5MeD6Ft3CWlJId"}
 - {"type":"ssr","name":"v2rayse_test_3","server":"20.239.49.44","port":59814,"protocol":"origin","cipher":"dummy","obfs":"plain","password":"3df57276-03ef-45cf-bdd4-4edb6dfaa0ef"}
 - {"type":"vmess","name":"v2rayse_test_2","ws-opts":{"path":"/"},"server":"154.23.190.162","port":443,"uuid":"b9984674-f771-4e67-a198-","alterId":"0","cipher":"auto","network":"ws"}
 - {"type":"vless","name":"test","server":"1.2.3.4","port":7777,"uuid":"abc-def-ghi-fge-zsx","skip-cert-verify":true,"network":"tcp","tls":true,"udp":true}
 - {"type":"trojan","name":"v2rayse_test_4","server":"ca-trojan.bonds.id","port":443,"password":"bc7593fe-0604-4fbe--b4ab-11eb-b65e-1239d0255272","udp":true,"skip-cert-verify":true}
 - {"type":"http","name":"http_proxy","server":"124.15.12.24","port":251,"username":"username","password":"password","udp":true}
 - {"type":"socks5","name":"socks5_proxy","server":"124.15.12.24","port":2312,"udp":true}
 - {"type":"socks5","name":"telegram_proxy","server":"1.2.3.4","port":123,"username":"username","password":"password","udp":true}
 */

// MARK: - clash

struct Clash: Codable {
    var port, socksPort, redirPort, mixedPort: Int?
    var allowLAN: Bool?
    var mode: String
    var logLevel: String?
    var externalController: String?
    var proxies: [clashProxy]
    var rules: [String]?
}

extension Clash {
    /// 单个节点格式不对(缺 server/port、类型不符等)只跳过该节点, 不让整份订阅解析失败。
    /// 全部节点都坏时 proxies 为空, 调用方按"没有节点"处理, 和以前解析失败一样; 没有 proxies 字段仍然解析失败
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        port = try? c.decodeIfPresent(Int.self, forKey: .port)
        socksPort = try? c.decodeIfPresent(Int.self, forKey: .socksPort)
        redirPort = try? c.decodeIfPresent(Int.self, forKey: .redirPort)
        mixedPort = try? c.decodeIfPresent(Int.self, forKey: .mixedPort)
        allowLAN = try? c.decodeIfPresent(Bool.self, forKey: .allowLAN)
        // 只有 proxies 的节点列表文件(proxy-provider)没有 mode
        mode = (try? c.decodeIfPresent(String.self, forKey: .mode)) ?? "rule"
        logLevel = try? c.decodeIfPresent(String.self, forKey: .logLevel)
        externalController = try? c.decodeIfPresent(String.self, forKey: .externalController)
        proxies = (try c.decode([LossyClashProxy].self, forKey: .proxies)).compactMap(\.proxy)
        rules = try? c.decodeIfPresent([String].self, forKey: .rules)
    }
}

/// 解码失败时 proxy 为 nil, 数组其余元素照常解码
private struct LossyClashProxy: Decodable {
    let proxy: clashProxy?

    init(from decoder: Decoder) throws {
        do {
            proxy = try clashProxy(from: decoder)
        } catch {
            logger.info("skip invalid clash proxy: \(error)")
            proxy = nil
        }
    }
}

// MARK: - ClashProxy
struct clashProxy: Codable {
    var type: String
    var name: String
    var server: String
    var port: Int
    var username: String? // socks5 | http
    var password: String?
    var sni: String?
    var skipCERTVerify: Bool?
    var cipher: String? // ss | ssr
    var uuid: String? // vmess | vless
    var alterId: Int? // vmess | vless
    var tls: Bool? // tls
    var fp: String?
    var `protocol`: String? // ssr
    var obfs: String? // ssr
    var udp: Bool? // socks5
    var network: String? // ws | h2
    var servername: String? // priority over wss host, REALITY servername,SNI
    var clientFingerprint: String? // vless
    var fingerprint: String? // vmess
    var security: String? // vmess
    var flow: String? // vless
    var encryption: String? // vless: mihomo 用 encryption（如 mlkem768x25519plus...），默认 none
    var wsOpts: clashWsOpts? // vmess
    var httpOpts: clashHttpOpts? // vmess
    var h2Opts: clashH2Opts? // vmess
    var grpcOpts: grpcOpts? // vmess
    var realityOpts: realityOpts? // vless
    var alpn: [String]? // tuic
    var congestionController: String? // tuic
    var udpRelayMode: String? // tuic
    var privateKey: String? // wireguard
    var publicKey: String? // wireguard
    var preSharedKey: String? // wireguard
    var ip: String? // wireguard
    var ipv6: String? // wireguard
    var reserved: String? // wireguard: "1,2,3" 或 base64, 数组写法转成逗号分隔
    var mtu: Int? // wireguard
    var peers: [clashWireGuardPeer]? // wireguard 多 peer 写法, 只取第一个
}

struct clashWireGuardPeer: Codable {
    var server: String?
    var port: Int?
    var publicKey: String?
    var preSharedKey: String?
    var reserved: String?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: ClashKey.self)
        server = c.clashValue(String.self, "server")
        port = c.clashInt("port")
        publicKey = c.clashValue(String.self, "public-key", "publicKey")
        preSharedKey = c.clashValue(String.self, "pre-shared-key", "preSharedKey")
        reserved = c.clashReserved()
    }
}

// Clash / mihomo 的字段名是连字符写法(ws-opts、skip-cert-verify、reality-opts 等)，
// 原来按属性名(wsOpts)解码，这些字段全部读不到：ws 路径/Host、reality 公钥、跳过证书验证都丢了。
// 这里同时认连字符和驼峰两种写法；可选字段类型不符(如 alterId: "0")时忽略该字段，不让整个订阅解析失败
struct ClashKey: CodingKey {
    var stringValue: String
    var intValue: Int? { nil }
    init(_ string: String) { stringValue = string }
    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { nil }
}

extension KeyedDecodingContainer where K == ClashKey {
    /// 依次按 names 取值，取不到或类型不符返回 nil
    func clashValue<T: Decodable>(_ type: T.Type, _ names: String...) -> T? {
        for name in names {
            if let value = try? decodeIfPresent(T.self, forKey: ClashKey(name)) {
                return value
            }
        }
        return nil
    }

    /// wireguard reserved: 数组 [1, 2, 3] 或字符串 "1,2,3" / base64
    func clashReserved() -> String? {
        if let values = try? decodeIfPresent([Int].self, forKey: ClashKey("reserved")) {
            return values.map(String.init).joined(separator: ",")
        }
        return clashValue(String.self, "reserved")
    }

    /// 数字字段兼容字符串写法(port: "443")
    func clashInt(_ names: String...) -> Int? {
        for name in names {
            if let value = try? decodeIfPresent(Int.self, forKey: ClashKey(name)) {
                return value
            }
            if let text = try? decodeIfPresent(String.self, forKey: ClashKey(name)), let value = Int(text.trimmingCharacters(in: .whitespaces)) {
                return value
            }
        }
        return nil
    }
}

extension clashProxy {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: ClashKey.self)
        // wireguard 的 peers 写法可以只在 peer 里写 server/port, 顶层没有时从第一个 peer 取;
        // 不能直接抛错: proxies 里任何一个节点解码失败都会让整份订阅解析失败
        let peers = c.clashValue([clashWireGuardPeer].self, "peers")
        guard let type = c.clashValue(String.self, "type"),
              let server = c.clashValue(String.self, "server") ?? peers?.first?.server,
              let port = c.clashInt("port") ?? peers?.first?.port else {
            throw DecodingError.dataCorrupted(.init(codingPath: c.codingPath, debugDescription: "clash proxy missing type/server/port"))
        }
        self.type = type
        self.name = c.clashValue(String.self, "name") ?? server
        self.server = server
        self.port = port
        self.username = c.clashValue(String.self, "username")
        self.password = c.clashValue(String.self, "password")
        self.sni = c.clashValue(String.self, "sni")
        self.skipCERTVerify = c.clashValue(Bool.self, "skip-cert-verify", "skipCertVerify", "skipCERTVerify")
        self.cipher = c.clashValue(String.self, "cipher")
        self.uuid = c.clashValue(String.self, "uuid")
        self.alterId = c.clashInt("alterId", "alter-id")
        self.tls = c.clashValue(Bool.self, "tls")
        self.fp = c.clashValue(String.self, "fp")
        self.protocol = c.clashValue(String.self, "protocol")
        self.obfs = c.clashValue(String.self, "obfs")
        self.udp = c.clashValue(Bool.self, "udp")
        self.network = c.clashValue(String.self, "network")
        self.servername = c.clashValue(String.self, "servername")
        self.clientFingerprint = c.clashValue(String.self, "client-fingerprint", "clientFingerprint")
        self.fingerprint = c.clashValue(String.self, "fingerprint")
        self.security = c.clashValue(String.self, "security")
        self.flow = c.clashValue(String.self, "flow")
        self.encryption = c.clashValue(String.self, "encryption")
        self.wsOpts = c.clashValue(clashWsOpts.self, "ws-opts", "wsOpts")
        self.httpOpts = c.clashValue(clashHttpOpts.self, "http-opts", "httpOpts")
        self.h2Opts = c.clashValue(clashH2Opts.self, "h2-opts", "h2Opts")
        self.grpcOpts = c.clashValue(V2rayU.grpcOpts.self, "grpc-opts", "grpcOpts")
        self.realityOpts = c.clashValue(V2rayU.realityOpts.self, "reality-opts", "realityOpts")
        self.alpn = c.clashValue([String].self, "alpn")
        self.congestionController = c.clashValue(String.self, "congestion-controller", "congestion-control", "congestionController")
        self.udpRelayMode = c.clashValue(String.self, "udp-relay-mode", "udpRelayMode")
        self.privateKey = c.clashValue(String.self, "private-key", "privateKey")
        self.publicKey = c.clashValue(String.self, "public-key", "publicKey")
        self.preSharedKey = c.clashValue(String.self, "pre-shared-key", "preSharedKey")
        self.ip = c.clashValue(String.self, "ip")
        self.ipv6 = c.clashValue(String.self, "ipv6")
        self.reserved = c.clashReserved()
        self.mtu = c.clashInt("mtu")
        self.peers = peers
    }
}

extension clashProxy {
    func toProfile() -> ProfileEntity? {
        var profile = ProfileEntity()
        
        profile.remark = self.name
        profile.address = self.server
        profile.port = self.port
        profile.sni = self.sni ?? self.server
        profile.allowInsecure = self.skipCERTVerify ?? true
        profile.security = self.security.flatMap { V2rayStreamSecurity(rawValue: $0) } ?? .none
        // Many clash configs use `tls: true` (bool) instead of `security: "tls"` (string)
        if self.tls == true && profile.security == .none {
            profile.security = .tls
        }
        profile.flow = self.flow ?? ""
        
        // Set type-specific fields
        switch self.type {
        case "trojan":
            profile.protocol = .trojan
            profile.password = self.password ?? ""
            profile.fingerprint = self.fp.flatMap { V2rayStreamFingerprint(rawValue: $0) } ?? .chrome
            // trojan 默认使用 TLS
            if profile.security == .none {
                profile.security = .tls
            }

        case "vmess":
            profile.protocol = .vmess
            profile.password = self.uuid ?? ""
            profile.alterId = self.alterId ?? 0
            profile.encryption = self.cipher ?? "auto"
            profile.fingerprint = self.fingerprint.flatMap { V2rayStreamFingerprint(rawValue: $0) } ?? .none
            profile.network = self.network.flatMap { V2rayStreamNetwork(rawValue: $0) } ?? .tcp
            
            if profile.network == .ws {
                profile.host = self.wsOpts?.host ?? self.servername ?? self.server
                profile.path = self.wsOpts?.path ?? "/"
            } else if profile.network == .h2 {
                profile.host = self.h2Opts?.host?.first ?? self.servername ?? self.server
                profile.path = self.h2Opts?.path ?? "/"
            } else if profile.network == .grpc {
                profile.path = self.grpcOpts?.grpcServiceName ?? "/"
            }

        case "vless":
            profile.protocol = .vless
            profile.password = self.uuid ?? ""
            // mihomo 的 vless 用 `encryption` 字段（不是 cipher）；空值视为 none (#1675)
            let encryption = self.encryption?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            profile.encryption = encryption.isEmpty ? "none" : encryption
            profile.fingerprint = self.clientFingerprint.flatMap { V2rayStreamFingerprint(rawValue: $0) } ?? .chrome
            profile.network = self.network.flatMap { V2rayStreamNetwork(rawValue: $0) } ?? .tcp
            
            if let servername = self.servername, !servername.isEmpty {
                profile.sni = servername
            }

            // mihomo 的 reality 节点是 tls: true + reality-opts，没有 security 字段
            if self.security == "reality" || !(self.realityOpts?.publicKey ?? "").isEmpty {
                profile.security = .reality
                profile.publicKey = self.realityOpts?.publicKey ?? ""
                profile.shortId = self.realityOpts?.shortId ?? ""
            }
            
            if profile.network == .ws {
                profile.host = self.wsOpts?.host ?? self.servername ?? self.server
                profile.path = self.wsOpts?.path ?? "/"
            } else if profile.network == .h2 {
                profile.host = self.h2Opts?.host?.first ?? self.servername ?? self.server
                profile.path = self.h2Opts?.path ?? "/"
            } else if profile.network == .grpc {
                profile.path = self.grpcOpts?.grpcServiceName ?? "/"
            }

        case "ss", "ssr":
            profile.protocol = .shadowsocks
            profile.encryption = self.cipher ?? ""
            profile.password = self.password ?? ""

        case "socks5":
            profile.protocol = .socks
            profile.password = self.password ?? ""

        case "http":
            profile.protocol = .http
            profile.password = self.password ?? ""
            profile.host = self.servername ?? self.server

        case "hysteria2":
            profile.protocol = .hysteria2
            profile.network = .hysteria2
            profile.password = self.password ?? ""
            profile.sni = self.servername ?? self.server

        case "anytls":
            profile.protocol = .anytls
            profile.network = .tcp
            profile.security = .tls
            profile.password = self.password ?? ""
            profile.sni = self.servername ?? self.sni ?? self.server
            profile.fingerprint = self.clientFingerprint.flatMap { V2rayStreamFingerprint(rawValue: $0) }
                ?? self.fp.flatMap { V2rayStreamFingerprint(rawValue: $0) }
                ?? .chrome

        case "naive":
            profile.protocol = .naive
            profile.network = .tcp
            profile.security = .tls
            profile.host = self.username ?? ""
            profile.password = self.password ?? ""
            profile.sni = self.servername ?? self.sni ?? self.server
            // uTLS is not supported on naive outbound
            profile.fingerprint = .none

        case "tuic":
            // 只支持 v5 (uuid + password), v4 的 token 形式 sing-box 不支持
            guard let uuid = self.uuid, !uuid.isEmpty else { return nil }
            profile.protocol = .tuic
            profile.network = .tcp
            profile.security = .tls
            profile.host = uuid
            profile.password = self.password ?? ""
            profile.sni = self.servername ?? self.sni ?? self.server
            profile.fingerprint = .none
            profile.encryption = TuicUri.normalizedCongestionControl(self.congestionController ?? "")
            profile.path = TuicUri.normalizedUdpRelayMode(self.udpRelayMode ?? "")
            profile.alpn = TuicUri.normalizedAlpn((self.alpn ?? []).joined(separator: ","))

        case "wireguard":
            let peer = self.peers?.first
            guard let privateKey = self.privateKey, !privateKey.isEmpty,
                  let publicKey = peer?.publicKey ?? self.publicKey, !publicKey.isEmpty else { return nil }
            profile.protocol = .wireguard
            profile.network = .tcp
            profile.security = .none
            profile.address = peer?.server ?? self.server
            profile.port = peer?.port ?? self.port
            profile.password = privateKey
            profile.publicKey = publicKey
            var wg = ProfileEntity.WireGuardConfig()
            wg.localAddress = WireGuardUri.joinList([self.ip, self.ipv6].compactMap { $0 }.flatMap { WireGuardUri.localAddresses($0) })
            wg.preSharedKey = peer?.preSharedKey ?? self.preSharedKey ?? ""
            wg.reserved = WireGuardUri.normalizedReserved(peer?.reserved ?? self.reserved ?? "")
            if let mtu = self.mtu, mtu > 0 { wg.mtu = mtu }
            profile.setWireGuardConfig(wg)

        default:
            return nil
        }
        
        return profile
    }
}

struct clashWsOpts: Codable {
    var path: String?
    var headers: [String: String]?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: ClashKey.self)
        path = c.clashValue(String.self, "path")
        headers = c.clashValue([String: String].self, "headers")
    }

    /// headers 里的 Host（键名大小写不固定）
    var host: String? {
        headers?.first { $0.key.lowercased() == "host" }?.value
    }
}

struct clashHttpOpts: Codable {
    var path: [String]?
}

struct clashH2Opts: Codable {
    var path: String?
    var host: [String]?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: ClashKey.self)
        path = c.clashValue(String.self, "path")
        host = c.clashValue([String].self, "host") ?? c.clashValue(String.self, "host").map { [$0] }
    }
}

struct grpcOpts: Codable {
    var grpcServiceName: String?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: ClashKey.self)
        grpcServiceName = c.clashValue(String.self, "grpc-service-name", "grpcServiceName")
    }
}

struct realityOpts: Codable {
    var publicKey: String?
    var shortId: String?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: ClashKey.self)
        publicKey = c.clashValue(String.self, "public-key", "publicKey")
        shortId = c.clashValue(String.self, "short-id", "shortId")
    }
}

