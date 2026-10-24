import Foundation
import GRDB
import Testing
@testable import V2rayU

/// 组合配置链式代理（#1698）配置生成测试。
@Suite struct ChainProxyTests {

    private let entry = ProfileEntity(uuid: "entry-uuid", protocol: .vless, address: "entry.example.com", port: 443, password: "uuid", network: .tcp, security: .tls)
    private let exit = ProfileEntity(uuid: "exit-uuid", protocol: .trojan, address: "exit.example.com", port: 443, password: "pass", network: .ws, security: .tls)

    private let entryTag = "combo-chain-0-0-entry-uuid"
    private let exitTag = "combo-chain-0-1-exit-uuid"

    private func resolved(mode: CombinedOutboundMode, coreType: CoreType) -> CombinedConfigResolved {
        let group = CombinedInboundOutboundGroup(id: "g1", inboundType: .mixed, port: 18080, outboundProfileUUIDs: [entry.uuid, exit.uuid])
        return CombinedConfigResolved(
            combination: CombinedConfigEntity(uuid: "combo", groups: [group], outboundMode: mode),
            groups: [CombinedConfigResolvedGroup(group: group, profiles: [entry, exit])],
            coreType: coreType,
            warningMessage: nil,
            canLaunch: true
        )
    }

    private func parse(_ json: String) throws -> [String: Any] {
        try #require(try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])
    }

    private func outbound(_ config: [String: Any], tag: String) -> [String: Any]? {
        (config["outbounds"] as? [[String: Any]])?.first { $0["tag"] as? String == tag }
    }

    private func dialerProxy(_ outbound: [String: Any]?) -> String? {
        ((outbound?["streamSettings"] as? [String: Any])?["sockopt"] as? [String: Any])?["dialerProxy"] as? String
    }

    // MARK: - 数据兼容

    @Test("Migration adds outboundMode defaulting to balance for existing combinations")
    func migrationDefaultsToBalance() throws {
        let dbQueue = try DatabaseQueue()
        // 模拟旧版本: 只执行到加颜色/策略为止的迁移，插入一条旧数据
        var oldMigrator = DatabaseMigrator()
        CombinedConfigEntity.registerMigrations(in: &oldMigrator)
        try oldMigrator.migrate(dbQueue, upTo: "addColorAndBalancerToCombinedConfig")
        try dbQueue.write { db in
            try db.execute(sql: "INSERT INTO combined_config (uuid, remark, sort, groupsJson, lastUpdate) VALUES ('old', 'old', 0, '[]', ?)", arguments: [Date()])
        }
        try oldMigrator.migrate(dbQueue)
        let fetched = try dbQueue.read { db in try CombinedConfigEntity.fetchOne(db, key: "old") }
        #expect(fetched?.outboundMode == .balance)

        var chain = CombinedConfigEntity(uuid: "new", outboundMode: .chain)
        chain.remark = "chain"
        try dbQueue.write { db in try chain.insert(db) }
        #expect(try dbQueue.read { db in try CombinedConfigEntity.fetchOne(db, key: "new") }?.outboundMode == .chain)
    }

    @Test("Chain needs chain mode and at least two profiles")
    func isChainRequiresTwoProfiles() {
        let two = CombinedInboundOutboundGroup(outboundProfileUUIDs: ["a", "b"])
        let one = CombinedInboundOutboundGroup(outboundProfileUUIDs: ["a"])
        #expect(CombinedConfigEntity(outboundMode: .chain).isChain(two))
        #expect(!CombinedConfigEntity(outboundMode: .chain).isChain(one))
        #expect(!CombinedConfigEntity(outboundMode: .balance).isChain(two))
    }

    // MARK: - Xray

    @Test("Xray chain: exit dials through entry via sockopt.dialerProxy")
    func xrayChain() throws {
        let config = try parse(V2rayConfigHandler().toJSON(combination: resolved(mode: .chain, coreType: .XrayCore)))

        #expect(dialerProxy(outbound(config, tag: entryTag)) == nil)
        let exitOutbound = try #require(outbound(config, tag: exitTag))
        #expect(dialerProxy(exitOutbound) == entryTag)
        // 出口保留自身传输层
        #expect((exitOutbound["streamSettings"] as? [String: Any])?["network"] as? String == "ws")
        // "proxy" 也走整条链
        #expect(dialerProxy(outbound(config, tag: "proxy")) == entryTag)

        let rules = ((config["routing"] as? [String: Any])?["rules"] as? [[String: Any]]) ?? []
        let comboRule = try #require(rules.first { ($0["inboundTag"] as? [String])?.first?.hasPrefix("combo-in-") == true })
        #expect(comboRule["outboundTag"] as? String == exitTag)
        #expect(comboRule["balancerTag"] == nil)
    }

    @Test("Xray chain under TUN: only the entry hop binds interface")
    func xrayChainTun() throws {
        let config = try parse(V2rayConfigHandler(enableTun: false, tunChainMode: true).toJSON(combination: resolved(mode: .chain, coreType: .XrayCore)))
        let exitSockopt = ((outbound(config, tag: exitTag)?["streamSettings"] as? [String: Any])?["sockopt"] as? [String: Any]) ?? [:]
        #expect(exitSockopt["interface"] == nil)
        #expect(exitSockopt["domainStrategy"] == nil)
        #expect(exitSockopt["dialerProxy"] as? String == entryTag)
    }

    @Test("Xray balance mode is unchanged")
    func xrayBalanceUnchanged() throws {
        let config = try parse(V2rayConfigHandler().toJSON(combination: resolved(mode: .balance, coreType: .XrayCore)))
        let outbounds = (config["outbounds"] as? [[String: Any]]) ?? []
        #expect(outbounds.allSatisfy { dialerProxy($0) == nil })
        #expect(outbound(config, tag: "combo-out-0-0-entry-uuid") != nil)
        let balancers = ((config["routing"] as? [String: Any])?["balancers"] as? [[String: Any]]) ?? []
        #expect(balancers.contains { $0["tag"] as? String == "combo-balancer-0" })
    }

    // MARK: - sing-box

    @Test("sing-box chain: exit dials through entry via detour")
    func singboxChain() throws {
        let config = try parse(SingboxConfigHandler().toJSON(combination: resolved(mode: .chain, coreType: .SingBox)))

        #expect(outbound(config, tag: entryTag)?["detour"] == nil)
        #expect(outbound(config, tag: exitTag)?["detour"] as? String == entryTag)
        #expect(outbound(config, tag: "proxy")?["detour"] as? String == entryTag)
        // 入口在本机解析服务器域名，后续节点交给上一跳解析
        #expect(outbound(config, tag: entryTag)?["domain_resolver"] != nil)
        #expect(outbound(config, tag: exitTag)?["domain_resolver"] == nil)
        #expect(outbound(config, tag: "proxy")?["domain_resolver"] == nil)
        // 链式不生成 selector
        #expect(outbound(config, tag: "combo-selector-0") == nil)

        let rules = ((config["route"] as? [String: Any])?["rules"] as? [[String: Any]]) ?? []
        #expect(rules.contains { $0["outbound"] as? String == exitTag })
    }

    @Test("sing-box balance mode is unchanged")
    func singboxBalanceUnchanged() throws {
        let config = try parse(SingboxConfigHandler().toJSON(combination: resolved(mode: .balance, coreType: .SingBox)))
        let outbounds = (config["outbounds"] as? [[String: Any]]) ?? []
        #expect(outbounds.allSatisfy { $0["detour"] == nil })
        #expect(outbound(config, tag: "combo-selector-0") != nil)
    }
}
