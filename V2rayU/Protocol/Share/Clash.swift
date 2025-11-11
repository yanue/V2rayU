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
    var wsOpts: clashWsOpts? // vmess
    var httpOpts: clashHttpOpts? // vmess
    var h2Opts: clashH2Opts? // vmess
    var grpcOpts: grpcOpts? // vmess
    var realityOpts: realityOpts? // vless
}

extension clashProxy {
    func toProfile() -> ProfileEntity? {
        var profile = ProfileEntity()
        
        profile.remark = self.name
        profile.address = self.server
        profile.port = self.port
        profile.uuid = self.uuid ?? ""
        profile.sni = self.sni ?? self.server
        profile.allowInsecure = self.skipCERTVerify ?? true
        profile.security = self.security.flatMap { V2rayStreamSecurity(rawValue: $0) } ?? .none
        profile.flow = self.flow ?? ""
        
        // Set type-specific fields
        switch self.type {
        case "trojan":
            profile.protocol = .trojan
            profile.password = self.password ?? ""
            profile.fingerprint = self.fp.flatMap { V2rayStreamFingerprint(rawValue: $0) } ?? .chrome

        case "vmess":
            profile.protocol = .vmess
            profile.password = self.uuid ?? ""
            profile.alterId = self.alterId ?? 0
            profile.encryption = self.cipher ?? "auto"
            profile.network = self.network.flatMap { V2rayStreamNetwork(rawValue: $0) } ?? .tcp
            
            if profile.network == .ws {
                profile.host = self.servername ?? self.server
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
            profile.encryption = self.cipher ?? "none"
            profile.network = self.network.flatMap { V2rayStreamNetwork(rawValue: $0) } ?? .tcp
            
            if self.security == "reality" {
                profile.sni = self.servername ?? self.server
                profile.fingerprint = self.clientFingerprint.flatMap { V2rayStreamFingerprint(rawValue: $0) } ?? .chrome
                profile.publicKey = self.realityOpts?.publicKey ?? ""
                profile.shortId = self.realityOpts?.shortId ?? ""
            }
            
            if profile.network == .ws {
                profile.host = self.servername ?? self.server
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

        default:
            return nil
        }
        
        return profile
    }
}

struct clashWsOpts: Codable {
    var path: String?
}

struct clashHttpOpts: Codable {
    var path: [String]?
}

struct clashH2Opts: Codable {
    var path: String?
    var host: [String]?
}

struct grpcOpts: Codable {
    var grpcServiceName: String?
}

struct realityOpts: Codable {
    var publicKey: String?
    var shortId: String?
}

