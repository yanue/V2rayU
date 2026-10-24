import Foundation
import Testing
@testable import V2rayU

/// TUN 链路（sing-box TUN → socks → 核心）相关配置生成测试。
@Suite(.serialized) struct TunDnsChainTests {

    // MARK: - 系统 DNS 占位地址

    private func withDefaults(_ keys: [UserDefaults.KEY], _ body: () throws -> Void) rethrows {
        let saved = keys.map { ($0, UserDefaults.standard.object(forKey: $0.rawValue)) }
        defer {
            for (key, value) in saved {
                if let value { UserDefaults.standard.set(value, forKey: key.rawValue) } else { UserDefaults.del(forKey: key) }
            }
        }
        try body()
    }

    @Test("System DNS placeholder is a non-DDR public resolver that is routed into TUN")
    func systemDnsPlaceholder() {
        withDefaults([.tunDnsChina, .dnsBootstrap, .tunRouteExcludeHosts]) {
            UserDefaults.set(forKey: .tunDnsChina, value: "223.5.5.5")
            UserDefaults.set(forKey: .dnsBootstrap, value: "223.5.5.5")
            UserDefaults.set(forKey: .tunRouteExcludeHosts, value: "")
            #expect(TunConfigHandler.systemDnsAddress() == "114.114.114.114")
            // 不能用被 route_exclude 的地址（tunDnsChina / bootstrap / 用户排除），否则查询绕过 TUN
            UserDefaults.set(forKey: .tunDnsChina, value: "114.114.114.114")
            #expect(TunConfigHandler.systemDnsAddress() == "114.114.115.115")
            UserDefaults.set(forKey: .tunRouteExcludeHosts, value: "114.114.0.0/16, example.com")
            #expect(TunConfigHandler.systemDnsAddress() == "180.76.76.76")
            // 永远不会选用支持 DDR 的公共 DNS
            for ddr in ["1.1.1.1", "8.8.8.8", "9.9.9.9", "208.67.222.222"] {
                #expect(!TunConfigHandler.systemDnsPlaceholders.contains(ddr))
            }
        }
    }

    // MARK: - TUN remote-dns: DoH + IPv4-only when IPv6 disabled

    @Test("TUN remote DNS uses DoH and honours IPv6 setting (new DNS format)")
    func tunRemoteDnsNewFormat() throws {
        let savedIPv6 = UserDefaults.getBool(forKey: .tunEnableIPv6, default: true)
        let savedRemote = UserDefaults.get(forKey: .tunDnsRemote)
        testSingboxVersionOverride = "1.13.15"
        defer {
            testSingboxVersionOverride = nil
            UserDefaults.setBool(forKey: .tunEnableIPv6, value: savedIPv6)
            if savedRemote.isEmpty { UserDefaults.del(forKey: .tunDnsRemote) } else { UserDefaults.set(forKey: .tunDnsRemote, value: savedRemote) }
        }
        UserDefaults.set(forKey: .tunDnsRemote, value: "8.8.8.8")

        for ipv6 in [true, false] {
            UserDefaults.setBool(forKey: .tunEnableIPv6, value: ipv6)
            let config = try JSONDecoder().decode(SingboxStruct.self, from: Data(TunConfigHandler.buildTunConfig().utf8))
            let remote = try #require(config.dns.servers.first { $0.tag == "remote-dns" })
            #expect(remote.type == "https")
            #expect(remote.server == "8.8.8.8")
            #expect(remote.path == "/dns-query")
            #expect(remote.detour == "proxy")
            let expected = ipv6 ? "prefer_ipv4" : "ipv4_only"
            #expect(config.dns.strategy == expected)
            // 规则级 strategy 不能覆盖成会返回 AAAA 的值
            for rule in config.dns.rules where rule.strategy != nil {
                #expect(rule.strategy == expected)
            }
        }
    }

    @Test("Removed OpenDNS remote DNS falls back to the default")
    func removedRemoteDnsFallsBack() throws {
        try withDefaults([.tunDnsRemote]) {
            UserDefaults.set(forKey: .tunDnsRemote, value: "208.67.222.222")
            #expect(TunConfigHandler.tunRemoteDns() == "1.1.1.1")
            let config = try JSONDecoder().decode(SingboxStruct.self, from: Data(TunConfigHandler.buildTunConfig().utf8))
            let remote = try #require(config.dns.servers.first { $0.tag == "remote-dns" })
            #expect((remote.server ?? remote.address ?? "").contains("1.1.1.1"))
            UserDefaults.set(forKey: .tunDnsRemote, value: "9.9.9.9")
            #expect(TunConfigHandler.tunRemoteDns() == "9.9.9.9")
        }
    }

    @Test("TUN remote DNS uses DoH address in legacy DNS format")
    func tunRemoteDnsLegacyFormat() throws {
        let savedRemote = UserDefaults.get(forKey: .tunDnsRemote)
        testSingboxVersionOverride = "1.11.15"
        defer {
            testSingboxVersionOverride = nil
            if savedRemote.isEmpty { UserDefaults.del(forKey: .tunDnsRemote) } else { UserDefaults.set(forKey: .tunDnsRemote, value: savedRemote) }
        }
        UserDefaults.set(forKey: .tunDnsRemote, value: "1.1.1.1")
        let config = try JSONDecoder().decode(SingboxStruct.self, from: Data(TunConfigHandler.buildTunConfig().utf8))
        let remote = try #require(config.dns.servers.first { $0.tag == "remote-dns" })
        #expect(remote.address == "https://1.1.1.1/dns-query")
    }

    // MARK: - 公共 Wi-Fi 网页登录

    @Test("Captive portal probe classification")
    func captiveClassify() {
        let success = "<HTML><HEAD><TITLE>Success</TITLE></HEAD><BODY>Success</BODY></HTML>"
        #expect(CaptivePortal.classify(curlOutput: success + "\n200") == .online)
        #expect(CaptivePortal.classify(curlOutput: "\n302") == .captive)
        #expect(CaptivePortal.classify(curlOutput: "<html>Hotel WiFi Login</html>\n200") == .captive)
        #expect(CaptivePortal.classify(curlOutput: "\n000") == .unknown)
        #expect(CaptivePortal.classify(curlOutput: "\n503") == .unknown)
        #expect(CaptivePortal.classify(curlOutput: "garbage") == .unknown)
    }

    @Test("Detection domains resolve via DHCP DNS and route direct in TUN")
    func captiveWhitelistInTunConfig() throws {
        testSingboxVersionOverride = "1.13.15"
        defer { testSingboxVersionOverride = nil }
        let config = try JSONDecoder().decode(SingboxStruct.self, from: Data(TunConfigHandler.buildTunConfig().utf8))
        let routeIdx = try #require(config.route.rules.firstIndex { $0.domain == CaptivePortal.detectionDomains })
        #expect(config.route.rules[routeIdx].outbound == "direct")
        let hijackIdx = try #require(config.route.rules.firstIndex { $0.action == "hijack-dns" })
        #expect(hijackIdx < routeIdx)
        if let dhcp = CaptivePortal.dhcpDns() {
            #expect(config.dns.servers.contains { $0.tag == "dhcp-dns" && $0.server == dhcp })
            #expect(config.dns.rules.first?.server == "dhcp-dns")
            #expect(config.dns.rules.first?.domain == CaptivePortal.detectionDomains)
        }
    }

    // MARK: - xray behind TUN

    private func xrayConfig(tunChainMode: Bool) throws -> [String: Any] {
        let profile = ProfileEntity(protocol: .vless, address: "example.com", port: 443, password: "uuid", network: .tcp, security: .tls)
        let json = V2rayConfigHandler(tunChainMode: tunChainMode).toJSON(item: profile)
        return try #require(try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])
    }

    private func outbounds(_ config: [String: Any]) -> [[String: Any]] {
        config["outbounds"] as? [[String: Any]] ?? []
    }

    private func sockopt(_ outbound: [String: Any]) -> [String: Any]? {
        (outbound["streamSettings"] as? [String: Any])?["sockopt"] as? [String: Any]
    }

    @Test("xray in TUN chain: routeOnly sniffing, own DNS for server, bound to physical interface")
    func xrayTunChainOptions() throws {
        let config = try xrayConfig(tunChainMode: true)

        for inbound in config["inbounds"] as? [[String: Any]] ?? [] where inbound["protocol"] as? String != "dokodemo-door" {
            let sniffing = try #require(inbound["sniffing"] as? [String: Any])
            #expect(sniffing["enabled"] as? Bool == true)
            #expect(sniffing["routeOnly"] as? Bool == true)
        }

        let iface = TunConfigHandler.physicalDefaultInterface()
        let proxy = try #require(outbounds(config).first { $0["protocol"] as? String == "vless" })
        let proxySockopt = try #require(sockopt(proxy))
        #expect(["UseIPv4v6", "UseIPv4"].contains(proxySockopt["domainStrategy"] as? String ?? ""))
        #expect(proxySockopt["interface"] as? String == iface)

        let freedom = try #require(outbounds(config).first { $0["protocol"] as? String == "freedom" })
        #expect(sockopt(freedom)?["interface"] as? String == iface)
        #expect(sockopt(freedom)?["domainStrategy"] == nil)

        let blackhole = try #require(outbounds(config).first { $0["protocol"] as? String == "blackhole" })
        #expect(sockopt(blackhole) == nil)
    }

    @Test("xray in TUN chain keeps user sniffing settings and drops system-resolver DNS")
    func xrayTunChainKeepsSniffingDropsLocalhost() throws {
        try withDefaults([.enableSniffing]) {
            UserDefaults.setBool(forKey: .enableSniffing, value: true)
            let config = try xrayConfig(tunChainMode: true)
            for inbound in config["inbounds"] as? [[String: Any]] ?? [] where inbound["protocol"] as? String != "dokodemo-door" {
                let sniffing = try #require(inbound["sniffing"] as? [String: Any])
                #expect(sniffing["routeOnly"] as? Bool == true)
                #expect((sniffing["destOverride"] as? [String])?.isEmpty == false)
            }
            let servers = (config["dns"] as? [String: Any])?["servers"] as? [Any] ?? []
            #expect(!servers.contains { ($0 as? String) == "localhost" })
        }
    }

    @Test("xray outside TUN keeps previous behaviour")
    func xrayNonTunUnchanged() throws {
        let config = try xrayConfig(tunChainMode: false)
        for inbound in config["inbounds"] as? [[String: Any]] ?? [] {
            #expect((inbound["sniffing"] as? [String: Any])?["routeOnly"] == nil)
        }
        for outbound in outbounds(config) {
            #expect(sockopt(outbound) == nil)
        }
    }
}
