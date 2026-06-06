import Testing
import Foundation
@testable import V2rayU

struct ProtocolParserTests {

    // MARK: - VMess Type 2 (JSON-based)

    @Test func vmessType2Parser() throws {
        let vmessLink = "vmess://eyJ2IjoiMiIsInBzIjoi5rWL6K+V5pyN5Yqh5ZGYIiwiYWRkIjoiMTIzLjQ1LjY3Ljg5IiwicG9ydCI6IjQ0MyIsImlkIjoiMTM4NmY4NWUtNjU3Yi00ZDZlLTlkNTYtNzhiYWQiLCJhaWQiOiI2NCIsIm5ldCI6IndzIiwidHlwZSI6Im5vbmUiLCJob3N0IjoiJm5iPXd3dy5nb29nbGUuY29tIiwicGF0aCI6Ii8iLCJ0bHMiOiJ0bHMifQ=="
        let uri = VmessUri()
        let url = URL(string: vmessLink)!
        let error = uri.parse(url: url)

        #expect(error == nil)
        let profile = uri.getProfile()
        #expect(profile.remark == "测试服务器")
        #expect(profile.address == "123.45.67.89")
        #expect(profile.port == 443)
        #expect(profile.password == "1386f85e-657b-4d6e-9d56-78bad")
        #expect(profile.alterId == 64)
        #expect(profile.network == .ws)
        #expect(profile.security == .tls)
    }

    @Test func vmessType2WithGrpc() throws {
        let vmessLink = "vmess://eyJ2IjoiMiIsInBzIjoiZ3JwYy10ZXN0IiwiYWRkIjoiZ3JwYy5leGFtcGxlLmNvbSIsInBvcnQiOiI0NDMiLCJpZCI6ImZmMDAwMDAwLTAwMDAtMDAwMC0wMDAwLTAwMDAwMDAwMDAwMCIsImFpZCI6IjAiLCJuZXQiOiJncnBjIiwidHlwZSI6Im5vbmUiLCJob3N0IjoiIiwicGF0aCI6Ii9zZXJ2aWNlbmFtZSIsInRscyI6InRscyJ9"
        let uri = VmessUri()
        let url = URL(string: vmessLink)!
        let error = uri.parse(url: url)

        #expect(error == nil)
        let profile = uri.getProfile()
        #expect(profile.remark == "grpc-test")
        #expect(profile.address == "grpc.example.com")
        #expect(profile.port == 443)
        #expect(profile.network == .grpc)
        #expect(profile.path == "/servicename")
        #expect(profile.security == .tls)
    }

    @Test func vmessType2WithKcp() throws {
        let vmessLink = "vmess://eyJ2IjoiMiIsInBzIjoia2NwLXRlc3QiLCJhZGQiOiJrY3AuZXhhbXBsZS5jb20iLCJwb3J0IjoiODg4OCIsImlkIjoiMDAwMDAwMDAtMDAwMC0wMDAwLTAwMDAtMDAwMDAwMDAwMDAwIiwiYWlkIjoiMCIsIm5ldCI6ImtjcCIsInR5cGUiOiJub25lIiwiaG9zdCI6IiIsInBhdGgiOiIiLCJ0bHMiOiJub25lIn0="
        let uri = VmessUri()
        let url = URL(string: vmessLink)!
        let error = uri.parse(url: url)

        #expect(error == nil)
        let profile = uri.getProfile()
        #expect(profile.remark == "kcp-test")
        #expect(profile.network == .kcp)
        #expect(profile.security == .none)
    }

    // MARK: - VMess Type 1 (URL-format)

    @Test func vmessType1Parser() throws {
        // vmess://base64(security:uuid@host:port)?query
        let userInfo = "auto:e2c7199d-964b-4321-9d33-842b6fcec068@qv2ray.net:8462"
        let encoded = Data(userInfo.utf8).base64EncodedString()
        let link = "vmess://\(encoded)?security=tls&sni=fastgit.org&remark=test-vmess"
        let uri = VmessUri()
        let url = URL(string: link)!
        let error = uri.parse(url: url)

        #expect(error == nil)
        let profile = uri.getProfile()
        #expect(profile.encryption == "auto")
        #expect(profile.password == "e2c7199d-964b-4321-9d33-842b6fcec068")
        #expect(profile.address == "qv2ray.net")
        #expect(profile.port == 8462)
        #expect(profile.security == .tls)
        #expect(profile.sni == "fastgit.org")
    }

    @Test func vmessType1WithWsShadowrocket() throws {
        let userInfo = "auto:e2c7199d-964b-4321-9d33-842b6fcec068@qv2ray.net:8462"
        let encoded = Data(userInfo.utf8).base64EncodedString()
        let link = "vmess://\(encoded)?obfs=websocket&path=/&remarks=vs-test"
        let uri = VmessUri()
        let url = URL(string: link)!
        let error = uri.parse(url: url)

        #expect(error == nil)
        let profile = uri.getProfile()
        #expect(profile.network == .ws)
        #expect(profile.path == "/")
    }

    // MARK: - VLESS

    @Test func vlessBasicParser() throws {
        let link = "vless://f2a5064a-fabb-43ed-a2b6-8ffeb970df7f@example.com:443?flow=xtls-rprx-vision&encryption=none&security=tls&sni=example.com&type=tcp&headerType=none#my-vless"
        let uri = VlessUri()
        let url = URL(string: link)!
        let error = uri.parse(url: url)

        #expect(error == nil)
        let profile = uri.getProfile()
        #expect(profile.password == "f2a5064a-fabb-43ed-a2b6-8ffeb970df7f")
        #expect(profile.address == "example.com")
        #expect(profile.port == 443)
        #expect(profile.flow == "xtls-rprx-vision")
        // VlessUri does not parse encryption from query for standard format
        #expect(profile.security == .tls)
        #expect(profile.sni == "example.com")
        #expect(profile.network == .tcp)
        #expect(profile.remark == "my-vless")
    }

    @Test func vlessRealityParser() throws {
        let link = "vless://44efe52b-e143-46b5-a9e7-aadbfd77eb9c@example.com:443?encryption=none&flow=xtls-rprx-vision&security=reality&sni=sni.yahoo.com&fp=chrome&pbk=nQhM0Ahmm1WPrUFPxE9_qFxXSQ7weIf7yOeMrZU5gRs&sid=5443&type=tcp&headerType=none&host=hk.yahoo.com#reality-test"
        let uri = VlessUri()
        let url = URL(string: link)!
        let error = uri.parse(url: url)

        #expect(error == nil)
        let profile = uri.getProfile()
        #expect(profile.password == "44efe52b-e143-46b5-a9e7-aadbfd77eb9c")
        #expect(profile.security == .reality)
        #expect(profile.sni == "sni.yahoo.com")
        #expect(profile.fingerprint == .chrome)
        #expect(profile.publicKey == "nQhM0Ahmm1WPrUFPxE9_qFxXSQ7weIf7yOeMrZU5gRs")
        #expect(profile.shortId == "5443")
        #expect(profile.flow == "xtls-rprx-vision")
        // VlessUri does not parse encryption from query for standard format
        #expect(profile.network == .tcp)
        #expect(profile.remark == "reality-test")
    }

    @Test func vlessWsParser() throws {
        let link = "vless://44efe52b-e143-46b5-a9e7-aadbfd77eb9c@qv2ray.net:6939?type=ws&security=tls&host=qv2ray.net&path=%2Fsomewhere#VLESSWebSocketTLS"
        let uri = VlessUri()
        let url = URL(string: link)!
        let error = uri.parse(url: url)

        #expect(error == nil)
        let profile = uri.getProfile()
        #expect(profile.network == .ws)
        #expect(profile.host == "qv2ray.net")
        #expect(profile.path == "/somewhere")
        #expect(profile.security == .tls)
        #expect(profile.remark == "VLESSWebSocketTLS")
    }

    @Test func vlessShadowrocketBase64() throws {
        // shadowrocket format: vless://base64encode?query#remark
        let userInfo = "auto:f2a5064a-fabb-43ed-a2b6-8ffeb970df7f@example.com:443"
        let b64 = Data(userInfo.utf8).base64EncodedString()
        let link = "vless://\(b64)?remarks=test-sr&tls=1&peer=sni.example.com"
        let uri = VlessUri()
        let url = URL(string: link)!
        let error = uri.parse(url: url)

        #expect(error == nil)
        let profile = uri.getProfile()
        #expect(profile.password == "f2a5064a-fabb-43ed-a2b6-8ffeb970df7f")
        #expect(profile.address == "example.com")
        #expect(profile.port == 443)
        #expect(profile.security == .tls)
        #expect(profile.sni == "sni.example.com")
        #expect(profile.remark == "test-sr")
    }

    // MARK: - Trojan

    @Test func trojanBasicParser() throws {
        let link = "trojan://password123@trojan.example.com:443?security=tls&sni=trojan.example.com&type=tcp#my-trojan"
        let uri = TrojanUri()
        let url = URL(string: link)!
        let error = uri.parse(url: url)

        #expect(error == nil)
        let profile = uri.getProfile()
        #expect(profile.password == "password123")
        #expect(profile.address == "trojan.example.com")
        #expect(profile.port == 443)
        #expect(profile.security == .tls)
        #expect(profile.sni == "trojan.example.com")
        #expect(profile.network == .tcp)
        #expect(profile.remark == "my-trojan")
    }

    @Test func trojanWithWs() throws {
        let link = "trojan://pass@ws.example.com:443?security=tls&sni=ws.example.com&type=ws&path=%2F&host=ws.example.com#trojan-ws"
        let uri = TrojanUri()
        let url = URL(string: link)!
        let error = uri.parse(url: url)

        #expect(error == nil)
        let profile = uri.getProfile()
        #expect(profile.network == .ws)
        #expect(profile.host == "ws.example.com")
        #expect(profile.path == "/")
        #expect(profile.remark == "trojan-ws")
    }

    @Test func trojanShadowrocket() throws {
        let link = "trojan://%3Apassword123@sr.example.com:443?peer=sni.example.com&obfs=grpc&path=test123#trojan-sr"
        let uri = TrojanUri()
        let url = URL(string: link)!
        let error = uri.parse(url: url)

        #expect(error == nil)
        let profile = uri.getProfile()
        #expect(profile.password == "password123")
        #expect(profile.sni == "sni.example.com")
        #expect(profile.network == .grpc)
        #expect(profile.remark == "trojan-sr")
    }

    // MARK: - Shadowsocks

    @Test func shadowsocksSip002Parser() throws {
        let methodPass = "aes-256-gcm:password123"
        let b64 = Data(methodPass.utf8).base64EncodedString()
        let link = "ss://\(b64)@ss.example.com:8388#my-ss"
        let uri = ShadowsocksUri()
        let url = URL(string: link)!
        let error = uri.parse(url: url)

        #expect(error == nil)
        let profile = uri.getProfile()
        #expect(profile.encryption == "aes-256-gcm")
        #expect(profile.password == "password123")
        #expect(profile.address == "ss.example.com")
        #expect(profile.port == 8388)
        #expect(profile.remark == "my-ss")
    }

    @Test func shadowsocksLegacyParser() throws {
        // Legacy: ss://base64(method:password)@host:port#remark
        let methodPass = "aes-256-cfb:test123"
        let b64 = Data(methodPass.utf8).base64EncodedString()
        let link = "ss://\(b64)@legacy.example.com:8888#legacy-ss"
        let uri = ShadowsocksUri()
        let url = URL(string: link)!
        let error = uri.parse(url: url)

        #expect(error == nil)
        let profile = uri.getProfile()
        #expect(profile.encryption == "aes-256-cfb")
        #expect(profile.password == "test123")
        #expect(profile.address == "legacy.example.com")
        #expect(profile.port == 8888)
    }

    // MARK: - ShadowsocksR

    @Test func shadowsocksRParser() throws {
        let ssrLink = "ssr://MS4yLjMuNDo1NTU1Om9yaWdpbjphZXMtMjU2LWNmYjpwbGFpbjpjR1ZqYUdGdVpB"
        let uri = ShadowsocksRUri()
        let url = URL(string: ssrLink)!
        let error = uri.parse(url: url)

        #expect(error == nil)
        let profile = uri.getProfile()
        #expect(profile.address == "1.2.3.4")
        #expect(profile.port == 5555)
        #expect(!profile.password.isEmpty)
    }

    // MARK: - Hysteria2

    @Test func hysteria2BasicParser() throws {
        let link = "hysteria2://password123@hy2.example.com:443?sni=hy2.example.com&insecure=1#my-hy2"
        let uri = Hysteria2Uri()
        let url = URL(string: link)!
        let error = uri.parse(url: url)

        #expect(error == nil)
        let profile = uri.getProfile()
        #expect(profile.password == "password123")
        #expect(profile.address == "hy2.example.com")
        #expect(profile.port == 443)
        #expect(profile.security == .tls)
        #expect(profile.sni == "hy2.example.com")
        #expect(profile.remark == "my-hy2")
    }

    @Test func hysteria2WithObfs() throws {
        let link = "hysteria2://pass@obfs.example.com:443?obfs-password=myobfspass&sni=obfs.example.com&up=100&down=500#hy2-obfs"
        let uri = Hysteria2Uri()
        let url = URL(string: link)!
        let error = uri.parse(url: url)

        #expect(error == nil)
        let profile = uri.getProfile()
        #expect(profile.password == "pass")
        #expect(profile.address == "obfs.example.com")
        #expect(profile.port == 443)

        let config = profile.getHysteria2Config()
        #expect(config.obfsPassword == "myobfspass")
        #expect(config.bandwidthUp == "100")
        #expect(config.bandwidthDown == "500")
        #expect(profile.remark == "hy2-obfs")
    }

    // MARK: - AnyTLS

    @Test func anyTlsBasicParser() throws {
        let link = "anytls://password@any.example.com:443?sni=any.example.com&insecure=1#my-anytls"
        let uri = AnyTlsUri()
        let url = URL(string: link)!
        let error = uri.parse(url: url)

        #expect(error == nil)
        let profile = uri.getProfile()
        #expect(profile.password == "password")
        #expect(profile.address == "any.example.com")
        #expect(profile.port == 443)
        #expect(profile.security == .tls)
        #expect(profile.sni == "any.example.com")
        #expect(profile.remark == "my-anytls")
    }

    // MARK: - Naive

    @Test func naiveBasicParser() throws {
        let link = "naive://username:password@naive.example.com:443?sni=naive.example.com#my-naive"
        let uri = NaiveUri()
        let url = URL(string: link)!
        let error = uri.parse(url: url)

        #expect(error == nil)
        let profile = uri.getProfile()
        #expect(profile.host == "username")
        #expect(profile.password == "password")
        #expect(profile.address == "naive.example.com")
        #expect(profile.port == 443)
        #expect(profile.sni == "naive.example.com")
        #expect(profile.remark == "my-naive")
    }

    @Test func naiveNoUsernameParser() throws {
        let link = "naive://password@naive2.example.com:443?sni=naive2.example.com#naive-no-user"
        let uri = NaiveUri()
        let url = URL(string: link)!
        let error = uri.parse(url: url)

        #expect(error == nil)
        let profile = uri.getProfile()
        #expect(profile.host == "")
        #expect(profile.password == "password")
        #expect(profile.remark == "naive-no-user")
    }

    // MARK: - Clash Proxy Parsing

    @Test func clashVmessParser() throws {
        let json = """
        {"type":"vmess","name":"clash-vmess","server":"154.23.190.162","port":443,"uuid":"b9984674-f771-4e67-a198-","alterId":0,"cipher":"auto","network":"ws","wsOpts":{"path":"/"}}
        """
        let data = json.data(using: .utf8)!
        let proxy = try JSONDecoder().decode(clashProxy.self, from: data)
        let profile = proxy.toProfile()

        #expect(profile != nil)
        #expect(profile?.remark == "clash-vmess")
        #expect(profile?.address == "154.23.190.162")
        #expect(profile?.port == 443)
        #expect(profile?.password == "b9984674-f771-4e67-a198-")
        #expect(profile?.network == .ws)
        #expect(profile?.path == "/")
    }

    @Test func clashTrojanParser() throws {
        let json = """
        {"type":"trojan","name":"clash-trojan","server":"trojan.example.com","port":443,"password":"secret123","udp":true}
        """
        let data = json.data(using: .utf8)!
        let proxy = try JSONDecoder().decode(clashProxy.self, from: data)
        let profile = proxy.toProfile()

        #expect(profile != nil)
        #expect(profile?.remark == "clash-trojan")
        #expect(profile?.address == "trojan.example.com")
        #expect(profile?.port == 443)
        #expect(profile?.password == "secret123")
        #expect(profile?.security == .tls) // trojan defaults to TLS
    }

    @Test func clashVlessRealityParser() throws {
        let json = """
        {"type":"vless","name":"clash-reality","server":"1.2.3.4","port":7777,"uuid":"abc-def-ghi","skip-cert-verify":true,"network":"tcp","tls":true,"flow":"xtls-rprx-vision","reality-opts":{"public-key":"pubKey123","short-id":"sid456"},"servername":"sni.example.com"}
        """
        let data = json.data(using: .utf8)!
        let proxy = try JSONDecoder().decode(clashProxy.self, from: data)
        let profile = proxy.toProfile()

        #expect(profile != nil)
        #expect(profile?.remark == "clash-reality")
        #expect(profile?.password == "abc-def-ghi")
        #expect(profile?.flow == "xtls-rprx-vision")
        #expect(profile?.sni == "sni.example.com")
        #expect(profile?.security == .tls)
    }

    @Test func clashSsParser() throws {
        let json = """
        {"type":"ss","name":"clash-ss","server":"198.57.27.218","port":5004,"cipher":"aes-256-gcm","password":"g5MeD6Ft3CWlJId"}
        """
        let data = json.data(using: .utf8)!
        let proxy = try JSONDecoder().decode(clashProxy.self, from: data)
        let profile = proxy.toProfile()

        #expect(profile != nil)
        #expect(profile?.remark == "clash-ss")
        #expect(profile?.encryption == "aes-256-gcm")
        #expect(profile?.password == "g5MeD6Ft3CWlJId")
        #expect(profile?.port == 5004)
    }

    // MARK: - Import URI (Integration)

    @Test func importUriDetectsAllProtocols() throws {
        let protocols = [
            "ss://",
            "ssr://",
            "vmess://",
            "vless://",
            "trojan://",
            "hysteria2://",
            "anytls://",
            "naive://",
            "naive+https://",
        ]
        for proto in protocols {
            #expect(supportProtocol(uri: proto + "test"))
        }
        #expect(!supportProtocol(uri: "unknown://test"))
    }

    @Test func importAllProtocolTypes() throws {
        let testCases: [(String, String, V2rayProtocolOutbound)] = [
            ("trojan://pass@a.com:443#t1", "t1", .trojan),
            ("vless://uuid@b.com:443?security=tls#v1", "v1", .vless),
            ("hysteria2://pass@c.com:443#h1", "h1", .hysteria2),
            ("anytls://pass@d.com:443#a1", "a1", .anytls),
            ("naive://user:pass@e.com:443#n1", "n1", .naive),
        ]

        for (uriStr, expectedRemark, expectedProtocol) in testCases {
            let importer = ImportUri(share_uri: uriStr)
            let profile = importer.doImport()
            #expect(profile != nil, "Failed to import: \(uriStr)")
            #expect(profile?.remark == expectedRemark)
            #expect(profile?.protocol == expectedProtocol)
            #expect(profile?.shareUri == uriStr)
        }
    }

    @Test func importSsUri() throws {
        let methodPass = "chacha20-ietf-poly1305:testPass"
        let b64 = Data(methodPass.utf8).base64EncodedString()
        let uriStr = "ss://\(b64)@ss.test.com:8388#mySs"
        let importer = ImportUri(share_uri: uriStr)
        let profile = importer.doImport()
        #expect(profile != nil)
        #expect(profile?.remark == "mySs")
        #expect(profile?.protocol == .shadowsocks)
        #expect(profile?.address == "ss.test.com")
        #expect(profile?.port == 8388)
    }
}
