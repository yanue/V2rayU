import Foundation
import Testing
@testable import V2rayU

/// v4 路由迁移 (#1613): 只测解码与转换, 不读写数据库
struct LegacyRoutingMigrationTests {
    private let defaultRules = RoutingManager().defaultRules

    /// 按 v4 的方式归档(类名 V2rayU.RoutingItem)写入临时 UserDefaults 再读出
    private func roundTrip(_ item: LegacyRoutingItem) throws -> LegacyRoutingItem? {
        let suite = "v2rayu-test-legacy-routing-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let archiver = NSKeyedArchiver(requiringSecureCoding: false)
        archiver.setClassName("V2rayU.RoutingItem", for: LegacyRoutingItem.self)
        archiver.encode(item, forKey: NSKeyedArchiveRootObjectKey)
        archiver.finishEncoding()
        defaults.set(archiver.encodedData, forKey: item.name)
        return LegacyRoutingItem.load(name: item.name, defaults: defaults)
    }

    @Test func customJsonRouting() throws {
        let item = LegacyRoutingItem()
        item.name = "routing.0F6E3D1C-1111-4A4B-9C9D-123456789ABC"
        item.remark = "我的路由"
        item.json = """
        {"domainStrategy": "IPIfNonMatch", "rules": [
          {"type": "field", "outboundTag": "direct", "domain": ["geosite:cn", "baidu.com"]},
          {"type": "field", "outboundTag": "proxy", "ip": ["8.8.8.8/32"], "domain": ["google.com"]},
          {"type": "field", "outboundTag": "block", "domain": ["ads.example.com"]},
          {"type": "field", "outboundTag": "direct", "port": "22"},
          {"type": "field", "outboundTag": "proxy", "network": "udp", "domain": ["quic.example.com"]}
        ]}
        """
        let loaded = try #require(try roundTrip(item))
        #expect(loaded.json == item.json)

        let uuid = LegacyRoutingItem.migratedUuid(for: item.name)
        #expect(uuid == "0F6E3D1C-1111-4A4B-9C9D-123456789ABC")
        let result = try #require(loaded.toEntity(uuid: uuid, defaultRules: defaultRules))
        #expect(result.entity.name == item.name)
        #expect(result.entity.remark == "我的路由")
        #expect(result.entity.domainStrategy == "IPIfNonMatch")
        #expect(result.entity.direct == "geosite:cn\nbaidu.com")
        #expect(result.entity.proxy == "google.com\n8.8.8.8/32")
        #expect(result.entity.block == "ads.example.com")
        // 带端口 / 网络条件的规则无法表示, 跳过而不是扩大匹配范围
        #expect(result.skippedRules == 2)
    }

    @Test func untouchedBuiltinIsSkipped() throws {
        let item = LegacyRoutingItem()
        item.name = RoutingRuleCn
        item.remark = "🌏 绕过中国大陆"
        let loaded = try #require(try roundTrip(item))
        #expect(loaded.toEntity(uuid: LegacyRoutingItem.migratedUuid(for: item.name), defaultRules: defaultRules) == nil)
    }

    @Test func customizedBuiltinKeepsDefaults() throws {
        let item = LegacyRoutingItem()
        item.name = RoutingRuleLANAndCn
        item.remark = "🌏 绕过局域网和中国大陆"
        item.proxy = "openai.com\nchatgpt.com"
        item.direct = "geosite:cn\nmycompany.com"
        let loaded = try #require(try roundTrip(item))
        let uuid = LegacyRoutingItem.migratedUuid(for: item.name)
        let result = try #require(loaded.toEntity(uuid: uuid, defaultRules: defaultRules))
        // 同名: 保留内置路由的行为; 新 uuid: 不覆盖 v5 已有的内置路由
        #expect(result.entity.name == RoutingRuleLANAndCn)
        #expect(result.entity.remark == "🌏 绕过局域网和中国大陆 (v4)")
        #expect(result.entity.proxy == "openai.com\nchatgpt.com")
        let direct = result.entity.direct.components(separatedBy: "\n")
        #expect(direct.contains("geoip:private"))
        #expect(direct.contains("mycompany.com"))
        #expect(direct.filter { $0 == "geosite:cn" }.count == 1)
        #expect(result.entity.domainStrategy == "IPOnDemand")
    }

    @Test func builtinUuidIsStable() {
        let a = LegacyRoutingItem.migratedUuid(for: RoutingRuleCn)
        #expect(a == LegacyRoutingItem.migratedUuid(for: RoutingRuleCn))
        #expect(a != LegacyRoutingItem.migratedUuid(for: RoutingRuleLAN))
        #expect(UUID(uuidString: a) != nil)
    }

    @Test func emptyCustomRoutingIsSkipped() throws {
        let item = LegacyRoutingItem()
        item.name = "routing.\(UUID().uuidString)"
        item.json = "{\"domainStrategy\": \"AsIs\", \"rules\": []}"
        let loaded = try #require(try roundTrip(item))
        #expect(loaded.toEntity(uuid: UUID().uuidString, defaultRules: defaultRules) == nil)
    }
}
