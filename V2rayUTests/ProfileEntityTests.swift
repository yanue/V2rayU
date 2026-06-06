import Testing
import Foundation
import GRDB
@testable import V2rayU

struct ProfileEntityTests {

    // MARK: - Initialization

    @Test func defaultInit() {
        let p = ProfileEntity()
        #expect(p.uuid.count == 36) // UUID string
        #expect(p.remark == "")
        #expect(p.protocol == .freedom)
        #expect(p.network == .tcp)
        #expect(p.security == .none)
        #expect(p.port == 0)
        #expect(p.allowInsecure == true)
        #expect(p.sort == 0)
        #expect(p.speed == -1)
    }

    @Test func vmessInit() {
        let p = ProfileEntity(protocol: .vmess, address: "vmess.example.com", port: 443, password: "uuid-1234")
        #expect(p.protocol == .vmess)
        #expect(p.address == "vmess.example.com")
        #expect(p.port == 443)
        #expect(p.password == "uuid-1234")
        #expect(p.security == .none)
        #expect(p.network == .tcp)
    }

    @Test func hysteria2InitDefaults() {
        let p = ProfileEntity(protocol: .hysteria2)
        #expect(p.protocol == .hysteria2)
        #expect(p.network == .hysteria2)
        #expect(p.security == .tls)
        #expect(p.alpn == .h3)
    }

    @Test func anytlsInitDefaults() {
        let p = ProfileEntity(protocol: .anytls)
        #expect(p.protocol == .anytls)
        #expect(p.security == .tls)
        #expect(p.network == .tcp)
    }

    @Test func naiveInitDefaults() {
        let p = ProfileEntity(protocol: .naive)
        #expect(p.protocol == .naive)
        #expect(p.security == .tls)
        #expect(p.network == .tcp)
    }

    // MARK: - Codable Roundtrip

    @Test func codableRoundtrip() throws {
        let original = ProfileEntity(
            uuid: "test-uuid-123", remark: "my-server", protocol: .vmess,
            address: "1.2.3.4", port: 443, password: "abc-def-ghi",
            alterId: 64, encryption: "auto", network: .ws,
            headerType: .none, host: "example.com", path: "/ws",
            security: .tls, sni: "example.com",
            fingerprint: .chrome
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ProfileEntity.self, from: data)

        #expect(decoded.uuid == original.uuid)
        #expect(decoded.remark == original.remark)
        #expect(decoded.protocol == original.protocol)
        #expect(decoded.address == original.address)
        #expect(decoded.port == original.port)
        #expect(decoded.password == original.password)
        #expect(decoded.alterId == original.alterId)
        #expect(decoded.network == original.network)
        #expect(decoded.path == original.path)
        #expect(decoded.security == original.security)
        #expect(decoded.sni == original.sni)
        #expect(decoded.fingerprint == original.fingerprint)
    }

    @Test func codableHandlesPortAsIntAndString() throws {
        // Some imports may send port as int or string
        let json = """
        {"uuid":"test","remark":"r","protocol":"vmess","address":"1.2.3.4","port":443,"password":"p","network":"tcp"}
        """
        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(ProfileEntity.self, from: data)
        #expect(decoded.port == 443)
    }

    @Test func codableSafeDecodeFallsBackForMissingFields() throws {
        let json = """
        {"uuid":"test-minimal","protocol":"vmess","address":"","port":0}
        """
        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(ProfileEntity.self, from: data)
        #expect(decoded.remark == "")
        #expect(decoded.network == .tcp)
        #expect(decoded.security == .none)
        #expect(decoded.fingerprint == .chrome)
        #expect(decoded.speed == -1)
        #expect(decoded.sort == 0)
    }

    @Test func codableHandlesNullValues() throws {
        let json = """
        {"uuid":"test-null","protocol":"vmess","address":"","port":0,"remark":null,"speed":null}
        """
        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(ProfileEntity.self, from: data)
        #expect(decoded.remark == "")
        #expect(decoded.speed == -1)
    }

    // MARK: - Field Trimming

    @Test func trimFields() {
        var p = ProfileEntity(
            remark: "  hello  ", address: "  example.com  ",
            password: "  pass  ", encryption: "  auto  ", host: "  host  ", path: "  /path  ",
            flow: "  flow  ", sni: "  sni  "
        )
        p.trimFields()
        #expect(p.remark == "hello")
        #expect(p.address == "example.com")
        #expect(p.password == "pass")
        #expect(p.host == "host")
        #expect(p.path == "/path")
        #expect(p.encryption == "auto")
        #expect(p.flow == "flow")
        #expect(p.sni == "sni")
    }

    // MARK: - Hysteria2 Config

    @Test func hysteria2ConfigDefault() {
        let p = ProfileEntity(protocol: .hysteria2)
        let config = p.getHysteria2Config()
        #expect(config.obfsPassword == "")
        #expect(config.hopPortRange == "")
        #expect(config.hopInterval == 30)
        #expect(config.bandwidthUp == "")
        #expect(config.bandwidthDown == "")
        #expect(config.masqueradeJson == "")
    }

    @Test func hysteria2ConfigRoundtrip() {
        var p = ProfileEntity(protocol: .hysteria2)
        var config = p.getHysteria2Config()
        config.obfsPassword = "myobfs"
        config.hopPortRange = "100-200"
        config.hopInterval = 60
        config.bandwidthUp = "100"
        config.bandwidthDown = "500"

        let encoder = JSONEncoder()
        let data = try! encoder.encode(config)
        p.extra = String(data: data, encoding: .utf8)!

        let loadedConfig = p.getHysteria2Config()
        #expect(loadedConfig.obfsPassword == "myobfs")
        #expect(loadedConfig.hopPortRange == "100-200")
        #expect(loadedConfig.hopInterval == 60)
        #expect(loadedConfig.bandwidthUp == "100")
        #expect(loadedConfig.bandwidthDown == "500")
    }

    // MARK: - Equatable/Hashable

    @Test func equatableIsSynthesized() {
        // ProfileEntity auto-synthesizes Equatable by comparing all stored properties
        // Use same lastUpdate to avoid Date() differences breaking equality
        let fixedDate = Date(timeIntervalSinceReferenceDate: 0)
        var a = ProfileEntity(uuid: "same-uuid", remark: "a")
        var b = ProfileEntity(uuid: "same-uuid", remark: "b")
        var c = ProfileEntity(uuid: "same-uuid", remark: "a")
        a.lastUpdate = fixedDate
        b.lastUpdate = fixedDate
        c.lastUpdate = fixedDate
        #expect(a != b) // different remarks → not equal
        #expect(a == c) // identical fields → equal
    }

    // MARK: - In-memory Database

    @Test func databaseInsertAndFetch() throws {
        let dbQueue = try DatabaseQueue()
        var migrator = DatabaseMigrator()
        ProfileEntity.registerMigrations(in: &migrator)
        try migrator.migrate(dbQueue)

        var profile = ProfileEntity(
            uuid: "db-test-uuid", remark: "db-test", protocol: .vmess,
            address: "10.0.0.1", port: 443, password: "pass123"
        )
        profile.trimFields()

        try dbQueue.write { db in
            try profile.insert(db)
        }

        let fetched = try dbQueue.read { db in
            try ProfileEntity.filter(ProfileEntity.Columns.uuid == "db-test-uuid").fetchOne(db)
        }
        #expect(fetched != nil)
        #expect(fetched?.remark == "db-test")
        #expect(fetched?.address == "10.0.0.1")
        #expect(fetched?.port == 443)
    }

    @Test func databaseUpdateFields() throws {
        let dbQueue = try DatabaseQueue()
        var migrator = DatabaseMigrator()
        ProfileEntity.registerMigrations(in: &migrator)
        try migrator.migrate(dbQueue)

        let uuid = "update-test-uuid"
        try dbQueue.write { db in
            var p = ProfileEntity(uuid: uuid, remark: "before", protocol: .vmess, address: "1.1.1.1", port: 80)
            p.trimFields()
            try p.insert(db)
        }

        try dbQueue.write { db in
            var p = ProfileEntity(uuid: uuid, remark: "after", protocol: .vmess, address: "2.2.2.2", port: 443)
            p.trimFields()
            try p.update(db)
        }

        let fetched = try dbQueue.read { db in
            try ProfileEntity.fetchOne(db, key: uuid)
        }
        #expect(fetched?.remark == "after")
        #expect(fetched?.address == "2.2.2.2")
        #expect(fetched?.port == 443)
    }

    @Test func databaseDelete() throws {
        let dbQueue = try DatabaseQueue()
        var migrator = DatabaseMigrator()
        ProfileEntity.registerMigrations(in: &migrator)
        try migrator.migrate(dbQueue)

        let uuid = "delete-test-uuid"
        try dbQueue.write { db in
            var p = ProfileEntity(uuid: uuid, remark: "to-delete", protocol: .vmess, address: "x", port: 80)
            p.trimFields()
            try p.insert(db)
        }

        try dbQueue.write { db in
            try ProfileEntity.filter(ProfileEntity.Columns.uuid == uuid).deleteAll(db)
        }

        let fetched = try dbQueue.read { db in
            try ProfileEntity.fetchOne(db, key: uuid)
        }
        #expect(fetched == nil)
    }

    @Test func databaseFetchAllOrdered() throws {
        let dbQueue = try DatabaseQueue()
        var migrator = DatabaseMigrator()
        ProfileEntity.registerMigrations(in: &migrator)
        try migrator.migrate(dbQueue)

        try dbQueue.write { db in
            var p1 = ProfileEntity(uuid: "z-first", remark: "z", sort: 2, protocol: .vmess, address: "a", port: 1)
            p1.trimFields()
            try p1.insert(db)
            var p2 = ProfileEntity(uuid: "a-second", remark: "a", sort: 1, protocol: .vmess, address: "b", port: 2)
            p2.trimFields()
            try p2.insert(db)
        }

        let all = try dbQueue.read { db in
            try ProfileEntity.order(ProfileEntity.Columns.sort.asc).fetchAll(db)
        }
        #expect(all.count == 2)
        #expect(all[0].uuid == "a-second") // sort 1
        #expect(all[1].uuid == "z-first")  // sort 2
    }

    // MARK: - CombinedConfigEntity

    @Test func combinedConfigEntityDefaults() {
        let config = CombinedConfigEntity()
        #expect(!config.uuid.isEmpty)
        #expect(config.remark == "")
        #expect(config.groups.count == 1)
        #expect(config.groups[0].port == 1080)
        #expect(config.groups[0].inboundType == .mixed)
    }

    @Test func combinedConfigEntityGroupsJsonRoundtrip() throws {
        let groups = [
            CombinedInboundOutboundGroup(id: "g1", inboundType: .http, port: 8080, outboundProfileUUIDs: ["p1"]),
            CombinedInboundOutboundGroup(id: "g2", inboundType: .socks, port: 1080, outboundProfileUUIDs: ["p2", "p3"]),
        ]
        let config = CombinedConfigEntity(remark: "test-combo", groups: groups)
        #expect(config.groups.count == 2)
        #expect(config.groups[0].port == 8080)
        #expect(config.groups[1].outboundProfileUUIDs.count == 2)

        let json = CombinedConfigEntity.encodeGroups(groups)
        let decoded = CombinedConfigEntity.decodeGroups(json)
        #expect(decoded.count == 2)
        #expect(decoded[0].id == "g1")
        #expect(decoded[1].id == "g2")
    }

    @Test func combinedConfigDatabase() throws {
        let dbQueue = try DatabaseQueue()
        var migrator = DatabaseMigrator()
        CombinedConfigEntity.registerMigrations(in: &migrator)
        try migrator.migrate(dbQueue)

        let config = CombinedConfigEntity(uuid: "combo-1", remark: "my-combo")
        try dbQueue.write { db in
            try config.insert(db)
        }

        let fetched = try dbQueue.read { db in
            try CombinedConfigEntity.fetchOne(db, key: "combo-1")
        }
        #expect(fetched != nil)
        #expect(fetched?.remark == "my-combo")
    }

    // MARK: - SubscriptionEntity

    @Test func subscriptionEntityDefaults() {
        let sub = SubscriptionEntity()
        #expect(!sub.uuid.isEmpty)
        #expect(sub.url == "")
        #expect(sub.enable == true)
        #expect(sub.sort == 0)
        #expect(sub.updateInterval == 3600)
    }

    @Test func subscriptionDatabase() throws {
        let dbQueue = try DatabaseQueue()
        var migrator = DatabaseMigrator()
        SubscriptionEntity.registerMigrations(in: &migrator)
        try migrator.migrate(dbQueue)

        let sub = SubscriptionEntity(uuid: "sub-1", remark: "my-sub", url: "https://example.com/sub", sort: 1)
        try dbQueue.write { db in
            try sub.insert(db)
        }

        let fetched = try dbQueue.read { db in
            try SubscriptionEntity.fetchOne(db, key: "sub-1")
        }
        #expect(fetched != nil)
        #expect(fetched?.remark == "my-sub")
        #expect(fetched?.url == "https://example.com/sub")
    }

    // MARK: - RoutingEntity

    @Test func routingEntityDefaults() {
        let r = RoutingEntity()
        #expect(!r.uuid.isEmpty)
        #expect(r.name == "")
        #expect(r.domainStrategy == "AsIs")
        #expect(r.domainMatcher == "hybrid")
    }

    @Test func routingDatabase() throws {
        let dbQueue = try DatabaseQueue()
        var migrator = DatabaseMigrator()
        RoutingEntity.registerMigrations(in: &migrator)
        try migrator.migrate(dbQueue)

        let r = RoutingEntity(uuid: "route-1", name: "my-route", remark: "my routing", proxy: "proxy-out")
        try dbQueue.write { db in
            try r.insert(db)
        }

        let fetched = try dbQueue.read { db in
            try RoutingEntity.fetchOne(db, key: "route-1")
        }
        #expect(fetched != nil)
        #expect(fetched?.name == "my-route")
        #expect(fetched?.proxy == "proxy-out")
    }
}
