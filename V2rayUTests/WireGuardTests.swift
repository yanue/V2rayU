import Foundation
import Testing
import Yams
@testable import V2rayU

/// WireGuard: 分享链接 / Clash 解析, Xray outbound 与 sing-box endpoint 生成
struct WireGuardTests {
    // 私钥/公钥是 base64, 含 + / =, 解析时不能丢
    private let privateKey = "yAnz5TF+lXXJte14tji3zlMNq+hd2rYUIgJBgB3fBmk="
    private let publicKey = "bmXOC+F1FxEMF9dyiK2H5/1SUtzH0JuVo51h2wPfgyo="

    private var link: String {
        "wireguard://\(privateKey.addingPercentEncoding(withAllowedCharacters: .alphanumerics)!)@engage.cloudflareclient.com:2408"
            + "?publickey=\(publicKey.addingPercentEncoding(withAllowedCharacters: .alphanumerics)!)"
            + "&address=172.16.0.2/32,%202606:4700:110:8a36::2/128&reserved=AQID&mtu=1280#warp"
    }

    @Test func parseUri() throws {
        let uri = WireGuardUri()
        #expect(uri.parse(url: URL(string: link)!) == nil)
        let profile = uri.getProfile()
        let wg = profile.getWireGuardConfig()

        #expect(profile.protocol == .wireguard)
        #expect(profile.address == "engage.cloudflareclient.com")
        #expect(profile.port == 2408)
        #expect(profile.password == privateKey)
        #expect(profile.publicKey == publicKey)
        #expect(wg.localAddress == "172.16.0.2/32,2606:4700:110:8a36::2/128")
        #expect(wg.reserved == "1,2,3") // base64 AQID → 1,2,3
        #expect(wg.mtu == 1280)
        #expect(profile.remark == "warp")
    }

    @Test func parseRejectsMissingKeys() {
        #expect(WireGuardUri().parse(url: URL(string: "wireguard://@1.2.3.4:51820?publickey=abc#x")!) != nil)
        #expect(WireGuardUri().parse(url: URL(string: "wireguard://priv@1.2.3.4:51820#x")!) != nil)
    }

    @Test func wgSchemeImport() {
        let profile = ImportUri(share_uri: link.replacingOccurrences(of: "wireguard://", with: "wg://")).doImport()
        #expect(profile?.protocol == .wireguard)
        #expect(profile?.password == privateKey)
        #expect(supportProtocol(uri: "wireguard://x"))
        #expect(supportProtocol(uri: "wg://x"))
    }

    @Test func roundtrip() throws {
        let uri = WireGuardUri()
        #expect(uri.parse(url: URL(string: link)!) == nil)
        let original = uri.getProfile()

        let encoded = WireGuardUri(from: original).encode()
        #expect(encoded.hasPrefix("wireguard://"))
        let decoded = WireGuardUri()
        #expect(decoded.parse(url: URL(string: encoded)!) == nil)
        let result = decoded.getProfile()

        #expect(result.password == original.password)
        #expect(result.publicKey == original.publicKey)
        #expect(result.address == original.address)
        #expect(result.port == original.port)
        #expect(result.getWireGuardConfig().localAddress == original.getWireGuardConfig().localAddress)
        #expect(result.getWireGuardConfig().reserved == "1,2,3")
        #expect(result.remark == "warp")
        #expect(!ShareUri.generateShareUri(item: original).isEmpty)
    }

    @Test func reservedFormats() {
        #expect(WireGuardUri.parseReserved("1,2,3") == [1, 2, 3])
        #expect(WireGuardUri.parseReserved("[1, 2, 3]") == [1, 2, 3])
        #expect(WireGuardUri.parseReserved("AQID") == [1, 2, 3])
        #expect(WireGuardUri.parseReserved("") == nil)
        #expect(WireGuardUri.parseReserved("1,2") == nil)
        #expect(WireGuardUri.parseReserved("1,2,300") == nil)
    }

    @Test func clashTopLevelAndPeers() throws {
        let yaml = """
        mode: rule
        proxies:
          - name: wg1
            type: wireguard
            server: 1.2.3.4
            port: 51820
            ip: 172.16.0.2
            ipv6: fd01::2
            private-key: \(privateKey)
            public-key: \(publicKey)
            reserved: [1, 2, 3]
            mtu: 1408
          - name: wg2
            type: wireguard
            server: 5.6.7.8
            port: 1
            ip: 10.0.0.2/32
            private-key: \(privateKey)
            peers:
              - server: peer.example.com
                port: 2408
                public-key: \(publicKey)
                pre-shared-key: psk
                reserved: AQID
        """
        let profiles = try YAMLDecoder().decode(Clash.self, from: yaml).proxies.compactMap { $0.toProfile() }
        #expect(profiles.count == 2)
        let top = try #require(profiles.first)
        #expect(top.protocol == .wireguard)
        #expect(top.address == "1.2.3.4")
        #expect(top.publicKey == publicKey)
        #expect(top.getWireGuardConfig().localAddress == "172.16.0.2/32,fd01::2/128")
        #expect(top.getWireGuardConfig().reserved == "1,2,3")
        #expect(top.getWireGuardConfig().mtu == 1408)

        let peer = try #require(profiles.last)
        #expect(peer.address == "peer.example.com")
        #expect(peer.port == 2408)
        #expect(peer.getWireGuardConfig().preSharedKey == "psk")
        #expect(peer.getWireGuardConfig().reserved == "1,2,3")
    }

    private func sampleProfile() -> ProfileEntity {
        let uri = WireGuardUri()
        _ = uri.parse(url: URL(string: link)!)
        return uri.getProfile()
    }

    @Test func xrayOutbound() throws {
        let outbound = V2rayOutboundHandler(from: ProfileModel(from: sampleProfile())).getOutbound()
        #expect(outbound.protocol == .wireguard)
        #expect(outbound.streamSettings == nil)
        let settings = try #require(outbound.settings as? V2rayOutboundWireGuard)
        #expect(settings.secretKey == privateKey)
        #expect(settings.address == ["172.16.0.2/32", "2606:4700:110:8a36::2/128"])
        #expect(settings.reserved == [1, 2, 3])
        #expect(settings.mtu == 1280)
        #expect(settings.peers.first?.publicKey == publicKey)
        #expect(settings.peers.first?.endpoint == "engage.cloudflareclient.com:2408")
        #expect(outbound.toJSON().contains("\"protocol\" : \"wireguard\""))
    }

    @Test func endpointHostParsing() {
        #expect(WireGuardUri.endpoint(host: "2001:db8::1", port: 51820) == "[2001:db8::1]:51820")
        #expect(WireGuardUri.host(ofEndpoint: "[2001:db8::1]:51820") == "2001:db8::1")
        #expect(WireGuardUri.host(ofEndpoint: "a.example.com:51820") == "a.example.com")
    }

    /// sing-box >= 1.11: wireguard outbound 改写成 endpoint; 原来是默认出站(第一个)时要补 route.final
    @Test func singboxEndpointConversion() throws {
        let outbound = SingboxOutboundHandler(from: ProfileModel(from: sampleProfile())).getOutbound()
        #expect(outbound.type == "wireguard")
        #expect(outbound.peer_public_key == publicKey)

        var config = SingboxStruct()
        config.outbounds = [outbound, SingboxOutbound(type: "direct", tag: "direct")]
        config.moveWireGuardToEndpoints()

        #expect(config.outbounds.map(\.type) == ["direct"])
        #expect(config.route.final == "proxy")
        let endpoint = try #require(config.endpoints?.first)
        #expect(endpoint.tag == "proxy")
        #expect(endpoint.private_key == privateKey)
        #expect(endpoint.address == ["172.16.0.2/32", "2606:4700:110:8a36::2/128"])
        #expect(endpoint.mtu == 1280)
        let peer = try #require(endpoint.peers?.first)
        #expect(peer.address == "engage.cloudflareclient.com")
        #expect(peer.port == 2408)
        #expect(peer.public_key == publicKey)
        #expect(peer.reserved == [1, 2, 3])
        #expect(peer.allowed_ips == ["0.0.0.0/0", "::/0"])

        // 不是第一个出站时不改默认出站
        var combo = SingboxStruct()
        var wg = outbound
        wg.tag = "combo-out-0-1"
        combo.outbounds = [SingboxOutbound(type: "selector", tag: "sel", outbounds: ["combo-out-0-1"]), wg]
        combo.moveWireGuardToEndpoints()
        #expect(combo.route.final == nil)
        #expect(combo.endpoints?.first?.tag == "combo-out-0-1")
    }

    @Test func validator() {
        var profile = sampleProfile()
        #expect(ProfileValidator.problem(of: profile) == nil)
        profile.publicKey = ""
        #expect(ProfileValidator.problem(of: profile) != nil)
    }

    /// Clash 常写 ip: 172.16.0.2, sing-box endpoint 需要 CIDR
    @Test func localAddressGetsPrefix() {
        #expect(WireGuardUri.localAddresses("172.16.0.2, fd01::2,10.0.0.0/8") == ["172.16.0.2/32", "fd01::2/128", "10.0.0.0/8"])
    }

    /// 自己生成的 Xray / sing-box 配置能导回来
    @Test func importJson() throws {
        let profile = sampleProfile()
        let xray = "{\"outbounds\": [\(V2rayOutboundHandler(from: ProfileModel(from: profile)).getOutbound().toJSON())]}"
        var config = SingboxStruct()
        config.outbounds = [SingboxOutboundHandler(from: ProfileModel(from: profile)).getOutbound()]
        config.moveWireGuardToEndpoints()
        let data = try JSONEncoder().encode(config)
        let singbox = try #require(String(data: data, encoding: .utf8))

        for json in [xray, singbox] {
            let imported = try #require(importFromJson(json: json))
            #expect(imported.protocol == .wireguard)
            #expect(imported.address == profile.address)
            #expect(imported.port == profile.port)
            #expect(imported.password == privateKey)
            #expect(imported.publicKey == publicKey)
            #expect(imported.getWireGuardConfig().localAddress == profile.getWireGuardConfig().localAddress)
            #expect(imported.getWireGuardConfig().reserved == "1,2,3")
        }
    }

    @Test func validatorReportsField() {
        var profile = sampleProfile()
        var wg = profile.getWireGuardConfig()
        wg.localAddress = ""
        profile.setWireGuardConfig(wg)
        #expect(ProfileValidator.problem(of: profile) == .missingField(.LocalAddress))
        profile.publicKey = ""
        #expect(ProfileValidator.problem(of: profile) == .missingField(.PeerPublicKey))
    }

    /// 从别的协议切到 TUIC 时残留的 encryption/path 不能写进配置
    @Test func tuicIgnoresLeftoverFields() {
        var profile = ProfileEntity(protocol: .tuic)
        profile.address = "t.example.com"
        profile.port = 443
        profile.host = "uuid"
        profile.password = "pw"
        profile.encryption = "none"
        profile.path = "/ws"
        let outbound = SingboxOutboundHandler(from: ProfileModel(from: profile)).getOutbound()
        #expect(outbound.congestion_control == nil)
        #expect(outbound.udp_relay_mode == nil)
    }

    /// peers 写法只在 peer 里写 server/port: 不能让整份订阅解码失败
    @Test func clashPeersOnlyServer() throws {
        let yaml = """
        mode: rule
        proxies:
          - name: trojan
            type: trojan
            server: t.example.com
            port: 443
            password: pw
          - name: wg-peers-only
            type: wireguard
            ip: 172.16.0.2
            private-key: \(privateKey)
            peers:
              - server: peer.example.com
                port: 2408
                public-key: \(publicKey)
        """
        let profiles = try YAMLDecoder().decode(Clash.self, from: yaml).proxies.compactMap { $0.toProfile() }
        #expect(profiles.map(\.protocol) == [.trojan, .wireguard])
        let wg = try #require(profiles.last)
        #expect(wg.address == "peer.example.com")
        #expect(wg.port == 2408)
        #expect(wg.remark == "wg-peers-only")
    }

    /// IPv6 对端: 分享链接要加方括号, 否则 URL 生成失败(只剩 #备注)
    @Test func ipv6EndpointRoundtrip() throws {
        var profile = sampleProfile()
        profile.address = "2606:4700:d0::a29f:c001"
        let encoded = WireGuardUri(from: profile).encode()
        #expect(encoded.hasPrefix("wireguard://"))
        let decoded = WireGuardUri()
        #expect(decoded.parse(url: URL(string: encoded)!) == nil)
        #expect(decoded.getProfile().address == "2606:4700:d0::a29f:c001")
        #expect(decoded.getProfile().port == profile.port)
        #expect(decoded.getProfile().password == privateKey)
    }

    /// TUIC: URL.user 已解码、URL.password 未解码; 密码里的 %41 不能被多解一次
    @Test func tuicCredentialDecoding() throws {
        let uri = TuicUri()
        #expect(uri.parse(url: URL(string: "tuic://uu%2541:ab%2541c@[2001:db8::1]:443#t")!) == nil)
        let profile = uri.getProfile()
        #expect(profile.host == "uu%41")
        #expect(profile.password == "ab%41c")
        #expect(profile.address == "2001:db8::1")

        let again = TuicUri()
        #expect(again.parse(url: URL(string: TuicUri(from: profile).encode())!) == nil)
        #expect(again.getProfile().host == "uu%41")
        #expect(again.getProfile().password == "ab%41c")
        #expect(again.getProfile().address == "2001:db8::1")
    }

    /// TUIC 必须带 ALPN, 表单里选了空也要生成 h3
    @Test func tuicAlpnNeverEmpty() {
        var profile = ProfileEntity(protocol: .tuic)
        profile.address = "t.example.com"
        profile.port = 443
        profile.host = "uuid"
        profile.password = "pw"
        profile.alpn = .none
        let outbound = SingboxOutboundHandler(from: ProfileModel(from: profile)).getOutbound()
        #expect(outbound.tls?.alpn == ["h3"])
    }
}
