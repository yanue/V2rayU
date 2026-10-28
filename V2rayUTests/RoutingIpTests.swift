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

/// 订阅更新时按服务器认出同一个节点：备注变化不影响 (#1669)
struct ProfileServerKeyTests {
    @Test func remarkDoesNotAffectServerKey() {
        let a = ProfileEntity(remark: "香港 01 | 剩余 10G", protocol: .vmess, address: "Example.com", port: 443, password: "uuid-1")
        var b = a
        b.remark = "香港 01 | 剩余 9G"
        b.address = "example.com"
        #expect(a.serverKey() == b.serverKey())
    }

    @Test func differentServerDiffers() {
        let a = ProfileEntity(remark: "a", protocol: .vmess, address: "example.com", port: 443, password: "uuid-1")
        var b = a
        b.port = 8443
        #expect(a.serverKey() != b.serverKey())
    }
}
