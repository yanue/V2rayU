import Foundation
import Testing
@testable import V2rayU

/// 路由规则里 IP / 网段的识别 (#1695)
struct RoutingIpTests {
    @Test(arguments: ["1.2.3.4", "10.0.0.0/8", "192.168.1.0/24", "0.0.0.0/0", "172.16.0.0/12", "8.8.8.8/32"])
    func ipv4(value: String) {
        #expect(isIp(str: value))
        #expect(parseDomainOrIp(domainIpStr: value).ips == [value])
    }

    @Test(arguments: ["10.0.0.0/33", "256.1.1.1", "1.2.3.4/", "example.com"])
    func notIpv4(value: String) {
        #expect(!isIp(str: value))
    }

    @Test(arguments: ["::1", "2001:db8::/32", "fe80::/10", "::/0"])
    func ipv6(value: String) {
        #expect(parseDomainOrIp(domainIpStr: value).ips == [value])
        #expect(parseDomainOrIp(domainIpStr: value).domains.isEmpty)
    }

    @Test func mixedList() {
        let parsed = parseDomainOrIp(domainIpStr: "10.0.0.0/8\nexample.com\ngeoip:private\n2001:db8::/32")
        #expect(parsed.ips == ["10.0.0.0/8", "geoip:private", "2001:db8::/32"])
        #expect(parsed.domains == ["example.com"])
    }
}
