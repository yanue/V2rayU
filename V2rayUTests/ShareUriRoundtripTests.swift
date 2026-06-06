import Testing
import Foundation
@testable import V2rayU

struct ShareUriRoundtripTests {

    private func makeProfile(
        uuid: String = UUID().uuidString,
        protocol: V2rayProtocolOutbound = .vmess,
        remark: String = "test",
        address: String = "1.2.3.4",
        port: Int = 443,
        password: String = UUID().uuidString,
        encryption: String = "auto",
        network: V2rayStreamNetwork = .tcp,
        security: V2rayStreamSecurity = .none,
        sni: String = "",
        host: String = "",
        path: String = "",
        flow: String = "",
        fingerprint: V2rayStreamFingerprint = .chrome,
        headerType: V2rayHeaderType = .none,
        alterId: Int = 0,
        allowInsecure: Bool = true
    ) -> ProfileEntity {
        ProfileEntity(
            uuid: uuid, remark: remark, protocol: `protocol`,
            address: address, port: port, password: password,
            alterId: alterId, encryption: encryption,
            network: network, headerType: headerType,
            host: host, path: path, security: security,
            allowInsecure: allowInsecure, flow: flow, sni: sni,
            fingerprint: fingerprint
        )
    }

    // MARK: - VMess Roundtrip

    @Test func vmessRoundtrip() throws {
        let original = makeProfile(
            protocol: .vmess, remark: "vmess-rt", address: "vmess.example.com",
            port: 8443, password: "12345678-1234-1234-1234-123456789abc",
            network: .ws, security: .tls, sni: "vmess.example.com",
            host: "vmess.example.com", path: "/vmess", alterId: 64
        )
        let encoded = VmessUri(from: original).encode()
        #expect(!encoded.isEmpty)
        #expect(encoded.hasPrefix("vmess://"))

        let decoded = VmessUri()
        let error = decoded.parse(url: URL(string: encoded)!)
        #expect(error == nil)

        let result = decoded.getProfile()
        #expect(result.remark == original.remark)
        #expect(result.address == original.address)
        #expect(result.port == original.port)
        #expect(result.password == original.password)
        #expect(result.network == original.network)
        #expect(result.security == original.security)
    }

    // MARK: - VLESS Roundtrip

    @Test func vlessRoundtrip() throws {
        let original = makeProfile(
            protocol: .vless, remark: "vless-rt", address: "vless.example.com",
            port: 443, password: "abcdef12-3456-7890-abcd-ef1234567890",
            encryption: "none", network: .ws, security: .tls,
            sni: "vless.example.com", host: "vless.example.com", path: "/vless",
            flow: "xtls-rprx-vision"
        )
        let encoded = VlessUri(from: original).encode()
        #expect(!encoded.isEmpty)
        #expect(encoded.hasPrefix("vless://"))

        let decoded = VlessUri()
        let error = decoded.parse(url: URL(string: encoded)!)
        #expect(error == nil)

        let result = decoded.getProfile()
        #expect(result.remark == original.remark)
        #expect(result.address == original.address)
        #expect(result.port == original.port)
        #expect(result.password == original.password)
        // VlessUri does not parse encryption back from standard format
        #expect(result.network == original.network)
    }

    // MARK: - Trojan Roundtrip

    @Test func trojanRoundtrip() throws {
        let original = makeProfile(
            protocol: .trojan, remark: "trojan-rt", address: "trojan.example.com",
            port: 443, password: "trojanPass123",
            network: .tcp, security: .tls, sni: "trojan.example.com"
        )
        let encoded = TrojanUri(from: original).encode()
        #expect(!encoded.isEmpty)
        #expect(encoded.hasPrefix("trojan://"))

        let decoded = TrojanUri()
        let error = decoded.parse(url: URL(string: encoded)!)
        #expect(error == nil)

        let result = decoded.getProfile()
        #expect(result.remark == original.remark)
        #expect(result.address == original.address)
        #expect(result.port == original.port)
        #expect(result.password == original.password)
        #expect(result.security == .tls) // trojan always upgrades to tls
    }

    // MARK: - Shadowsocks Roundtrip

    @Test func shadowsocksRoundtrip() throws {
        let original = makeProfile(
            protocol: .shadowsocks, remark: "ss-rt", address: "ss.example.com",
            port: 8388, password: "ssPass123",
            encryption: "aes-256-gcm"
        )
        let encoded = ShadowsocksUri(from: original).encode()
        #expect(!encoded.isEmpty)
        #expect(encoded.hasPrefix("ss://"))

        let decoded = ShadowsocksUri()
        let error = decoded.parse(url: URL(string: encoded)!)
        #expect(error == nil)

        let result = decoded.getProfile()
        #expect(result.remark == original.remark)
        #expect(result.address == original.address)
        #expect(result.port == original.port)
        #expect(result.password == original.password)
        #expect(result.encryption == original.encryption)
    }

    // MARK: - Hysteria2 Roundtrip

    @Test func hysteria2Roundtrip() throws {
        let original = makeProfile(
            protocol: .hysteria2, remark: "hy2-rt", address: "hy2.example.com",
            port: 443, password: "hy2Pass",
            security: .tls, sni: "hy2.example.com"
        )
        let encoded = Hysteria2Uri(from: original).encode()
        #expect(!encoded.isEmpty)
        #expect(encoded.hasPrefix("hysteria2://"))

        let decoded = Hysteria2Uri()
        let error = decoded.parse(url: URL(string: encoded)!)
        #expect(error == nil)

        let result = decoded.getProfile()
        #expect(result.remark == original.remark)
        #expect(result.address == original.address)
        #expect(result.port == original.port)
        #expect(result.password == original.password)
    }

    // MARK: - AnyTLS Roundtrip

    @Test func anyTlsRoundtrip() throws {
        let original = makeProfile(
            protocol: .anytls, remark: "anytls-rt", address: "any.example.com",
            port: 443, password: "anyPass",
            security: .tls, sni: "any.example.com"
        )
        let encoded = AnyTlsUri(from: original).encode()
        #expect(!encoded.isEmpty)
        #expect(encoded.hasPrefix("anytls://"))

        let decoded = AnyTlsUri()
        let error = decoded.parse(url: URL(string: encoded)!)
        #expect(error == nil)

        let result = decoded.getProfile()
        #expect(result.remark == original.remark)
        #expect(result.address == original.address)
        #expect(result.port == original.port)
        #expect(result.password == original.password)
    }

    // MARK: - Naive Roundtrip

    @Test func naiveRoundtrip() throws {
        var original = makeProfile(
            protocol: .naive, remark: "naive-rt", address: "naive.example.com",
            port: 443, password: "naivePass",
            security: .tls, sni: "naive.example.com"
        )
        original.host = "username"
        let encoded = NaiveUri(from: original).encode()
        #expect(!encoded.isEmpty)
        #expect(encoded.hasPrefix("naive://"))

        let decoded = NaiveUri()
        let error = decoded.parse(url: URL(string: encoded)!)
        #expect(error == nil)

        let result = decoded.getProfile()
        #expect(result.remark == original.remark)
        #expect(result.address == original.address)
        #expect(result.port == original.port)
        #expect(result.password == original.password)
    }

    // MARK: - ShareUri Factory

    @Test func shareUriFactoryAllProtocols() throws {
        let protocols: [V2rayProtocolOutbound] = [.vmess, .vless, .trojan, .shadowsocks, .hysteria2, .anytls, .naive]
        for proto in protocols {
            let profile = makeProfile(protocol: proto, remark: "factory-\(proto.rawValue)")
            let uri = ShareUri.generateShareUri(item: profile)
            #expect(!uri.isEmpty, "ShareUri generation failed for \(proto.rawValue)")
        }
    }

    // MARK: - Edge Cases

    @Test func vlessWithEmptyFields() throws {
        let profile = makeProfile(
            protocol: .vless, remark: "minimal", address: "minimal.test.com",
            port: 80, password: "uuid-here",
            encryption: "none", network: .tcp, security: .tls
        )
        let encoded = VlessUri(from: profile).encode()
        #expect(encoded.hasPrefix("vless://"))

        let decoded = VlessUri()
        let error = decoded.parse(url: URL(string: encoded)!)
        #expect(error == nil)
        let result = decoded.getProfile()
        #expect(result.remark == "minimal")
    }

    @Test func trojanWithChineseRemark() throws {
        let original = makeProfile(
            protocol: .trojan, remark: "中文测试节点", address: "cn.example.com",
            port: 443, password: "pass123",
            security: .tls, sni: "cn.example.com"
        )
        let encoded = TrojanUri(from: original).encode()
        #expect(encoded.contains("%E4%B8%AD%E6%96%87%E6%B5%8B%E8%AF%95%E8%8A%82%E7%82%B9") || encoded.contains("%E4%B8%AD%E6%96%87"))

        let decoded = TrojanUri()
        let error = decoded.parse(url: URL(string: encoded)!)
        #expect(error == nil)
        let result = decoded.getProfile()
        #expect(result.remark == "中文测试节点")
    }

    @Test func shadowsocksWithSpecialChars() throws {
        let original = makeProfile(
            protocol: .shadowsocks, remark: "ss-special", address: "ss.example.com",
            port: 8388, password: "pass+with_special==chars",
            encryption: "chacha20-ietf-poly1305"
        )
        let encoded = ShadowsocksUri(from: original).encode()
        #expect(encoded.hasPrefix("ss://"))

        let decoded = ShadowsocksUri()
        let error = decoded.parse(url: URL(string: encoded)!)
        #expect(error == nil)
        let result = decoded.getProfile()
        #expect(result.password == "pass+with_special==chars")
    }
}
