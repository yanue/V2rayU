import Testing
import Foundation
@testable import V2rayU

struct DnsConfigTests {

    // MARK: - DNS config builder

    @Test func buildDefaultDnsSettingUsesCustomValues() {
        let dns = buildDefaultDnsSetting(
            directDns: "https://dns.alidns.com/dns-query",
            remoteDns: "https://cloudflare-dns.com/dns-query",
            bootstrapDns: "223.5.5.5"
        )
        #expect(dns.contains("dns.alidns.com"))
        #expect(dns.contains("cloudflare-dns.com"))
        #expect(dns.contains("223.5.5.5"))
        #expect(dns.contains("geosite:geolocation-!cn"))
        #expect(dns.contains("geosite:cn"))
    }

    @Test func buildDefaultDnsSettingFallsBackToDefaultsWhenEmpty() {
        let dns = buildDefaultDnsSetting(
            directDns: "",
            remoteDns: "",
            bootstrapDns: ""
        )
        #expect(dns.contains(defaultDirectDns))
        #expect(dns.contains(defaultRemoteDns))
        #expect(dns.contains(defaultBootstrapDns))
    }

    @Test func buildDefaultSingboxDnsSettingUsesCustomValues() {
        // Note: buildDefaultSingboxDnsSetting only outputs bootstrap (as local-dns) and remoteDns.
        // The directDns parameter is accepted but not embedded in the singbox output.
        let dns = buildDefaultSingboxDnsSetting(
            directDns: "https://dns.alidns.com/dns-query",
            remoteDns: "https://cloudflare-dns.com/dns-query",
            bootstrapDns: "8.8.8.8"
        )
        #expect(dns.contains("cloudflare-dns.com"))
        #expect(dns.contains("8.8.8.8"))
        #expect(dns.contains("local-dns"))
        #expect(dns.contains("remote-dns"))
        #expect(dns.contains("detour"))
    }

    @Test func buildDefaultSingboxDnsSettingUses192() {
        let dns = buildDefaultSingboxDnsSetting(
            directDns: "https://dns.192-168-0-1.example.com/dns-query",
            remoteDns: "https://dns.cloudflare.com/dns-query",
            bootstrapDns: "192.168.0.1"
        )
        #expect(dns.contains("192.168.0.1"))
        #expect(dns.contains("dns.cloudflare.com"))
    }

    // MARK: - Defaults

    @Test func defaultDnsConstantsAreValid() {
        #expect(!defaultDirectDns.isEmpty)
        #expect(!defaultRemoteDns.isEmpty)
        #expect(!defaultBootstrapDns.isEmpty)

        #expect(!defaultDnsTargetStrategy.isEmpty)

        #expect(defaultDirectDns.hasPrefix("https://"))
        #expect(defaultRemoteDns.hasPrefix("https://"))
    }

    @Test func defaultPortsAreSensible() {
        #expect(defaultLatencyTestConcurrency > 0)
        #expect(defaultLatencyTestConcurrency <= 20)
        #expect(defaultLatencyTestTimeout > 0)
        #expect(defaultPingTestURL.hasPrefix("http"))
        #expect(defaultUDPTestURL.contains("."))
    }

    // MARK: - Default configs

    @Test func defaultDnsJsonIsValidJson() {
        let data = defaultDns.data(using: .utf8)!
        let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(json != nil)
        #expect(json?["hosts"] != nil)
        #expect(json?["servers"] != nil)
    }

    @Test func defaultSingboxDnsJsonIsValidJson() {
        let data = defaultSingboxDns.data(using: .utf8)!
        let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(json != nil)
        #expect(json?["servers"] != nil)
    }
}
