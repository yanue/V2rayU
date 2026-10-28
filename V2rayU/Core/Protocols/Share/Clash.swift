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
        guard let type = c.clashValue(String.self, "type"), let server = c.clashValue(String.self, "server"),
              let port = c.clashInt("port") else {
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

