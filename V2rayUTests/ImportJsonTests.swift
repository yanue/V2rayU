import Testing
import Foundation
@testable import V2rayU

struct ImportJsonTests {

    @Test func importVmessFromJson() {
        let json = """
        {
            "outbounds": [
                {
                    "protocol": "vmess",
                    "settings": {
                        "vnext": [{
                            "address": "vmess.example.com",
                            "port": 443,
                            "users": [{"id": "uuid-1234", "alterId": 64, "security": "auto"}]
                        }]
                    },
                    "streamSettings": {
                        "network": "ws",
                        "security": "tls",
                        "wsSettings": {"path": "/ws", "headers": {"Host": "vmess.example.com"}},
                        "tlsSettings": {"serverName": "vmess.example.com", "allowInsecure": false}
                    }
                }
            ]
        }
        """
        let profile = importFromJson(json: json)
        #expect(profile != nil)
        #expect(profile?.protocol == .vmess)
        #expect(profile?.address == "vmess.example.com")
        #expect(profile?.port == 443)
        #expect(profile?.password == "uuid-1234")
        #expect(profile?.alterId == 64)
        #expect(profile?.encryption == "auto")
        #expect(profile?.network == .ws)
        #expect(profile?.security == .tls)
        #expect(profile?.sni == "vmess.example.com")
        #expect(profile?.allowInsecure == false)
    }

    @Test func importVlessFromJson() {
        let json = """
        {
            "outbounds": [
                {
                    "protocol": "vless",
                    "settings": {
                        "vnext": [{
                            "address": "vless.example.com",
                            "port": 443,
                            "users": [{"id": "uuid-5678", "flow": "xtls-rprx-vision", "encryption": "none"}]
                        }]
                    },
                    "streamSettings": {
                        "network": "tcp",
                        "security": "reality",
                        "realitySettings": {
                            "serverName": "sni.yahoo.com",
                            "fingerprint": "chrome",
                            "publicKey": "pubKeyHere",
                            "shortId": "1234"
                        }
                    }
                }
            ]
        }
        """
        let profile = importFromJson(json: json)
        #expect(profile != nil)
        #expect(profile?.protocol == .vless)
        #expect(profile?.address == "vless.example.com")
        #expect(profile?.port == 443)
        #expect(profile?.password == "uuid-5678")
        #expect(profile?.flow == "xtls-rprx-vision")
        #expect(profile?.encryption == "none")
        #expect(profile?.security == .reality)
        #expect(profile?.sni == "sni.yahoo.com")
        #expect(profile?.fingerprint == .chrome)
        #expect(profile?.publicKey == "pubKeyHere")
        #expect(profile?.shortId == "1234")
    }

    @Test func importTrojanFromJson() {
        let json = """
        {
            "outbounds": [
                {
                    "protocol": "trojan",
                    "settings": {
                        "servers": [{
                            "address": "trojan.example.com",
                            "port": 443,
                            "password": "trojanPass"
                        }]
                    }
                }
            ]
        }
        """
        let profile = importFromJson(json: json)
        #expect(profile != nil)
        #expect(profile?.protocol == .trojan)
        #expect(profile?.address == "trojan.example.com")
        #expect(profile?.port == 443)
        #expect(profile?.password == "trojanPass")
    }

    @Test func importShadowsocksFromJson() {
        let json = """
        {
            "outbounds": [
                {
                    "protocol": "shadowsocks",
                    "settings": {
                        "servers": [{
                            "address": "ss.example.com",
                            "port": 8388,
                            "password": "ssPass",
                            "method": "aes-256-gcm"
                        }]
                    }
                }
            ]
        }
        """
        let profile = importFromJson(json: json)
        #expect(profile != nil)
        #expect(profile?.protocol == .shadowsocks)
        #expect(profile?.address == "ss.example.com")
        #expect(profile?.port == 8388)
        #expect(profile?.password == "ssPass")
        #expect(profile?.encryption == "aes-256-gcm")
    }

    @Test func importFromJsonReturnsNilForNoOutbound() {
        let json = """
        {"inbounds": [{"protocol": "http"}]}
        """
        let profile = importFromJson(json: json)
        #expect(profile == nil)
    }

    @Test func importFromJsonReturnsNilForInvalidJson() {
        let profile = importFromJson(json: "not json")
        #expect(profile == nil)
    }

    @Test func importFromJsonSkipsNonProxyOutbounds() {
        let json = """
        {
            "outbounds": [
                {"protocol": "freedom", "tag": "direct"},
                {"protocol": "blackhole", "tag": "block"},
                {"protocol": "vmess", "settings": {"vnext": [{"address": "real.com", "port": 443, "users": [{"id": "abc"}]}]}}
            ]
        }
        """
        let profile = importFromJson(json: json)
        #expect(profile != nil)
        #expect(profile?.address == "real.com")
        #expect(profile?.protocol == .vmess)
    }

    @Test func importHysteria2FromJson() {
        let json = """
        {
            "outbounds": [{
                "type": "hysteria2",
                "protocol": "hysteria2",
                "address": "hy2.example.com",
                "port": 443,
                "password": "hy2Pass"
            }]
        }
        """
        let profile = importFromJson(json: json)
        #expect(profile != nil)
        #expect(profile?.protocol == .hysteria2)
        #expect(profile?.address == "hy2.example.com")
        #expect(profile?.port == 443)
        #expect(profile?.password == "hy2Pass")
        #expect(profile?.network == .hysteria2)
    }

    @Test func importAnyTlsFromJson() {
        let json = """
        {
            "outbounds": [{
                "type": "anytls",
                "protocol": "anytls",
                "address": "any.example.com",
                "port": 443,
                "password": "anyPass",
                "tls": {
                    "server_name": "any.example.com",
                    "insecure": false,
                    "alpn": ["h2", "http/1.1"]
                }
            }]
        }
        """
        let profile = importFromJson(json: json)
        #expect(profile != nil)
        #expect(profile?.protocol == .anytls)
        #expect(profile?.address == "any.example.com")
        #expect(profile?.port == 443)
        #expect(profile?.password == "anyPass")
        #expect(profile?.sni == "any.example.com")
    }

    @Test func importNaiveFromJson() {
        let json = """
        {
            "outbounds": [{
                "type": "naive",
                "protocol": "naive",
                "address": "naive.example.com",
                "port": 443,
                "username": "user",
                "password": "naivePass",
                "tls": {
                    "server_name": "naive.example.com",
                    "insecure": false,
                    "alpn": ["h2", "http/1.1"]
                }
            }]
        }
        """
        let profile = importFromJson(json: json)
        #expect(profile != nil)
        #expect(profile?.protocol == .naive)
        #expect(profile?.address == "naive.example.com")
        #expect(profile?.port == 443)
        #expect(profile?.host == "user")
        #expect(profile?.password == "naivePass")
        #expect(profile?.sni == "naive.example.com")
    }
}
