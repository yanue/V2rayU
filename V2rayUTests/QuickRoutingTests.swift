import Foundation
import Testing
@testable import V2rayU

/// 快捷分流: 域名归一化、规则行、列表增删
struct QuickRoutingTests {
    @Test func normalizeHost() {
        #expect(QuickRouting.normalizeHost("www.Google.com:443") == "www.google.com")
        #expect(QuickRouting.normalizeHost("example.com.") == "example.com")
        #expect(QuickRouting.normalizeHost("1.2.3.4:8080") == "1.2.3.4")
        #expect(QuickRouting.normalizeHost("[2001:db8::1]:443") == "2001:db8::1")
        #expect(QuickRouting.normalizeHost("2001:db8::1") == "2001:db8::1")
        #expect(QuickRouting.normalizeHost("localhost") == nil)
        #expect(QuickRouting.normalizeHost("127.0.0.1:1080") == nil)
        #expect(QuickRouting.normalizeHost("") == nil)
        #expect(QuickRouting.normalizeHost("not a host") == nil)
    }

    @Test func ruleLine() {
        #expect(QuickRouting.ruleLine(host: "example.com") == "domain:example.com")
        #expect(QuickRouting.ruleLine(host: "1.2.3.4") == "1.2.3.4")
        #expect(QuickRouting.ruleLine(host: "2001:db8::1") == "2001:db8::1")
    }

    @Test func applyMovesBetweenListsAndDedupes() {
        var entity = RoutingEntity(name: "custom", remark: "custom", block: "", proxy: "domain:google.com", direct: "geoip:cn\ndomain:example.com")
        #expect(QuickRouting.apply(line: "domain:example.com", target: .proxy, entity: &entity))
        #expect(entity.direct == "geoip:cn")
        #expect(entity.proxy == "domain:google.com\ndomain:example.com")

        // 再加一次同样的: 内容不变
        #expect(QuickRouting.apply(line: "domain:example.com", target: .proxy, entity: &entity) == false)

        #expect(QuickRouting.apply(line: "domain:example.com", target: .block, entity: &entity))
        #expect(entity.proxy == "domain:google.com")
        #expect(entity.block == "domain:example.com")
    }

    @Test func singboxDomainPrefixBecomesSuffixRule() {
        let saved = UserDefaults.get(forKey: .runningRouting)
        defer { UserDefaults.set(forKey: .runningRouting, value: saved) }
        let entity = RoutingEntity(uuid: "test-quick-\(UUID().uuidString)", name: "custom", remark: "quick-test",
                                   proxy: "domain:example.com\nkeyword-site", direct: "")
        RoutingStore.shared.upsert(entity)
        defer { RoutingStore.shared.delete(uuid: entity.uuid) }
        UserDefaults.set(forKey: .runningRouting, value: entity.uuid)

        let rules = RoutingManager().getSingboxRoutingRules()
        let proxyRules = rules.filter { $0.outbound == "proxy" }
        #expect(proxyRules.contains { $0.domain_suffix == ["example.com"] })
        #expect(proxyRules.contains { $0.domain == ["keyword-site"] })
        #expect(!proxyRules.contains { $0.domain?.contains("example.com") == true })
    }

    @Test @MainActor func recentHostsAreUniqueNewestFirstDomainsOnly() {
        func conn(_ id: String, host: String, start: String) -> ClashConnection {
            ClashConnection(id: id, metadata: ClashConnectionMetadata(host: host), start: start)
        }
        let list = [
            conn("1", host: "a.com", start: "2026-10-28T10:00:00Z"),
            conn("2", host: "b.com", start: "2026-10-28T10:00:05Z"),
            conn("3", host: "a.com", start: "2026-10-28T10:00:09Z"),
            conn("4", host: "1.2.3.4", start: "2026-10-28T10:00:10Z"),
            conn("5", host: "", start: "2026-10-28T10:00:11Z"),
        ]
        #expect(AppMenuManager.recentHosts(list) == ["a.com", "b.com"])
        #expect(AppMenuManager.recentHosts(list, limit: 1) == ["a.com"])
    }
}

/// URL Scheme: 机场一键导入链接解析
struct UrlSchemeHandlerTests {
    @Test func parsesClashInstallConfig() {
        let url = URL(string: "clash://install-config?url=https%3A%2F%2Fexample.com%2Fsub%3Ftoken%3Dabc&name=My%20Airport")!
        #expect(UrlSchemeHandler.parseSubscriptionImport(url) == SubscriptionImportRequest(url: "https://example.com/sub?token=abc", name: "My Airport"))
    }

    @Test func parsesV2rayuAndSingboxForms() {
        let a = URL(string: "v2rayu://install-sub?url=https://example.com/sub")!
        #expect(UrlSchemeHandler.parseSubscriptionImport(a) == SubscriptionImportRequest(url: "https://example.com/sub", name: "example.com"))
        let b = URL(string: "sing-box://import-remote-profile?url=https%3A%2F%2Fexample.com%2Fsb#Air%20Port")!
        #expect(UrlSchemeHandler.parseSubscriptionImport(b) == SubscriptionImportRequest(url: "https://example.com/sb", name: "Air Port"))
    }

    @Test func keepsUnencodedInnerQuery() {
        let a = URL(string: "clash://install-config?url=https://x.com/sub?token=a&flag=clash")!
        #expect(UrlSchemeHandler.parseSubscriptionImport(a) == SubscriptionImportRequest(url: "https://x.com/sub?token=a&flag=clash", name: "x.com"))
        let b = URL(string: "clash://install-config?url=https://x.com/sub?token=a&flag=clash&name=Air%20Port")!
        #expect(UrlSchemeHandler.parseSubscriptionImport(b) == SubscriptionImportRequest(url: "https://x.com/sub?token=a&flag=clash", name: "Air Port"))
    }

    @Test func rejectsNonHttpAndUnknownActions() {
        #expect(UrlSchemeHandler.parseSubscriptionImport(URL(string: "clash://install-config?url=file:///etc/passwd")!) == nil)
        #expect(UrlSchemeHandler.parseSubscriptionImport(URL(string: "clash://install-config")!) == nil)
        #expect(UrlSchemeHandler.parseSubscriptionImport(URL(string: "clash://something-else?url=https://a.com")!) == nil)
        #expect(UrlSchemeHandler.parseSubscriptionImport(URL(string: "vmess://abc")!) == nil)
        #expect(UrlSchemeHandler.parseSubscriptionImport(URL(string: "https://example.com/?url=https://a.com")!) == nil)
    }
}
