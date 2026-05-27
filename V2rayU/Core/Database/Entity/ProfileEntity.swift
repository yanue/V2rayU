//
//  ProfileModel.swift
//  V2rayU
//
//  Created by yanue on 2024/12/2.
//

import GRDB
import SwiftUI
import UniformTypeIdentifiers
import CryptoKit

struct ProfileEntity: Codable, Identifiable, Equatable, Hashable, Transferable, TableRecord, FetchableRecord, PersistableRecord, IdColumnProtocol {
    // 公共属性
    var uuid: String // 唯一标识
    var remark: String // 备注
    var speed: Int = -1 // 速度
    var sort: Int = 0 // 排序
    var `protocol`: V2rayProtocolOutbound // 协议
    var network: V2rayStreamNetwork = .tcp // 网络: tcp, kcp, ws, domainsocket, xhttp, h2, grpc, quic
    var security: V2rayStreamSecurity = .none // 底层传输安全加密方式: none, tls, reality
    var subid: String // 订阅ID
    var address: String // 代理服务器地址
    var port: Int // 代理服务器端口
    var password: String // 密码: password(trojan,vmess,shadowsocks) | id(vmess,vless)
    var alterId: Int // vmess
    var encryption: String // 加密方式: security(trojan,vmess) | encryption(vless) | method(shadowsocks)
    var headerType: V2rayHeaderType = .none // 伪装类型: none, http, srtp, utp, wechat-video, dtls, wireguard
    var host: String // 请求域名: headers.Host(ws, h2) | host(xhttp)
    var path: String // 请求路径: path(ws, h2, xhttp) | serviceName(grpc) | key(quic) | seed(kcp)
    var allowInsecure: Bool = true // 允许不安全连接,默认true
    var flow: String = "" // 流控(xtls-rprx-vision | xtls-rprx-vision-udp443): 支持vless|trojan
    var sni: String = "" // sni即serverName(tls): tls|reality
    var alpn: V2rayStreamAlpn = .h2h1 // h3,h2,http1.1
    var fingerprint: V2rayStreamFingerprint = .chrome // 浏览器指纹: chrome, firefox, safari, edge, windows, android, ios
    var publicKey: String = "" // publicKey(reality): reality
    var shortId: String = "" // shortId(reality): reality
    var spiderX: String = "" // spiderX(reality): reality
    var extra: String = "" // xhttp额外字段extra
    var shareUri: String = "" // 原始分享链接(判断订阅是否更新)
    var serverIp: String = "" // 服务器IP
    var serverRegion: String = "" // 服务器IP归宿(国家代码)
    var coreType: ProfileCoreSelection? = .auto // 核心选择: auto/xray/sing-box
    // 统计
    var totalUp: Int64 = 0 // 总上传
    var totalDown: Int64 = 0 // 总下载
    var todayUp: Int64 = 0 // 今日上传
    var todayDown: Int64 = 0 // 今日下载
    var lastUpdate: Date = Date() // 最后更新时间

    // Identifiable 协议的要求
    var id: String {
        return uuid
    }
    static var idColumn: Column { ProfileEntity.Columns.uuid }

    // 拖动排序
    static let draggableType = UTType(exportedAs: "net.yanue.V2rayU")
    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: draggableType)
    }

    // 对应编码的 `CodingKeys` 枚举
    enum CodingKeys: String, CodingKey {
        case uuid, remark, speed, sort, `protocol`, subid, address, port, password, alterId, encryption, network, headerType, host, path, security, allowInsecure, flow, sni, alpn, fingerprint, publicKey, shortId, spiderX, extra, shareUri, serverIp, serverRegion, coreType, totalUp, totalDown, todayUp, todayDown, lastUpdate
    }

    // 安全的 decode 辅助：支持 NULL 回退 + 未知枚举值回退
    private static func safeDecode<T: RawRepresentable & Decodable>(
        from container: KeyedDecodingContainer<CodingKeys>,
        forKey key: CodingKeys,
        fallback: T
    ) -> T where T.RawValue == String {
        if let raw = try? container.decodeIfPresent(String.self, forKey: key),
           let value = T(rawValue: raw) {
            return value
        }
        return fallback
    }

    private static func safeDecode<T: Decodable>(
        from container: KeyedDecodingContainer<CodingKeys>,
        forKey key: CodingKeys,
        fallback: T
    ) -> T {
        if let value = try? container.decodeIfPresent(T.self, forKey: key) {
            return value
        }
        return fallback
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        uuid = try container.decode(String.self, forKey: .uuid)
        remark = Self.safeDecode(from: container, forKey: .remark, fallback: "")
        speed = Self.safeDecode(from: container, forKey: .speed, fallback: -1)
        sort = Self.safeDecode(from: container, forKey: .sort, fallback: 0)
        `protocol` = Self.safeDecode(from: container, forKey: .protocol, fallback: .freedom)
        subid = Self.safeDecode(from: container, forKey: .subid, fallback: "")
        address = Self.safeDecode(from: container, forKey: .address, fallback: "")
        port = Self.safeDecode(from: container, forKey: .port, fallback: 0)
        password = Self.safeDecode(from: container, forKey: .password, fallback: "")
        alterId = Self.safeDecode(from: container, forKey: .alterId, fallback: 0)
        encryption = Self.safeDecode(from: container, forKey: .encryption, fallback: "")
        network = Self.safeDecode(from: container, forKey: .network, fallback: .tcp)
        headerType = Self.safeDecode(from: container, forKey: .headerType, fallback: .none)
        host = Self.safeDecode(from: container, forKey: .host, fallback: "")
        path = Self.safeDecode(from: container, forKey: .path, fallback: "")
        security = Self.safeDecode(from: container, forKey: .security, fallback: .none)
        allowInsecure = Self.safeDecode(from: container, forKey: .allowInsecure, fallback: true)
        flow = Self.safeDecode(from: container, forKey: .flow, fallback: "")
        sni = Self.safeDecode(from: container, forKey: .sni, fallback: "")
        alpn = Self.safeDecode(from: container, forKey: .alpn, fallback: .h2h1)
        fingerprint = Self.safeDecode(from: container, forKey: .fingerprint, fallback: .chrome)
        publicKey = Self.safeDecode(from: container, forKey: .publicKey, fallback: "")
        shortId = Self.safeDecode(from: container, forKey: .shortId, fallback: "")
        spiderX = Self.safeDecode(from: container, forKey: .spiderX, fallback: "")
        extra = Self.safeDecode(from: container, forKey: .extra, fallback: "")
        shareUri = Self.safeDecode(from: container, forKey: .shareUri, fallback: "")
        serverIp = Self.safeDecode(from: container, forKey: .serverIp, fallback: "")
        serverRegion = Self.safeDecode(from: container, forKey: .serverRegion, fallback: "")
        if let raw = try? container.decodeIfPresent(String.self, forKey: .coreType) {
            coreType = ProfileCoreSelection(rawValue: raw) ?? .auto
        } else {
            coreType = nil
        }
        totalUp = Self.safeDecode(from: container, forKey: .totalUp, fallback: Int64(0))
        totalDown = Self.safeDecode(from: container, forKey: .totalDown, fallback: Int64(0))
        todayUp = Self.safeDecode(from: container, forKey: .todayUp, fallback: Int64(0))
        todayDown = Self.safeDecode(from: container, forKey: .todayDown, fallback: Int64(0))
        lastUpdate = Self.safeDecode(from: container, forKey: .lastUpdate, fallback: Date())
    }

    // 提供默认值的初始化器
    init(
        uuid: String = UUID().uuidString,
        remark: String = "",
        speed: Int = -1,
        sort: Int = 0,
        protocol: V2rayProtocolOutbound = .freedom,
        address: String = "",
        port: Int = 0,
        password: String = "",
        alterId: Int = 0,
        encryption: String = "",
        network: V2rayStreamNetwork = .tcp,
        headerType: V2rayHeaderType = .none,
        host: String = "",
        path: String = "",
        security: V2rayStreamSecurity = .none,
        allowInsecure: Bool = true,
        subid: String = "",
        flow: String = "",
        sni: String = "",
        alpn: V2rayStreamAlpn = .h2h1,
        fingerprint: V2rayStreamFingerprint = .chrome,
        publicKey: String = "",
        shortId: String = "",
        spiderX: String = "",
        extra: String = "",
        shareUri: String = "",
        serverIp: String = "",
        serverRegion: String = "",
        coreType: ProfileCoreSelection? = .auto
    ) {
        self.uuid = uuid
        self.speed = speed
        self.sort = sort
        self.remark = remark
        self.protocol = `protocol`
        self.address = address
        self.port = port
        self.password = password
        self.alterId = alterId
        self.encryption = encryption
        self.network = network
        self.headerType = headerType
        self.host = host
        self.path = path
        self.security = security
        self.allowInsecure = allowInsecure
        self.subid = subid
        self.flow = flow
        self.sni = sni
        self.alpn = alpn
        self.fingerprint = fingerprint
        self.publicKey = publicKey
        self.shortId = shortId
        self.spiderX = spiderX
        self.extra = extra
        self.shareUri = shareUri
        self.serverIp = serverIp
        self.serverRegion = serverRegion
        self.coreType = coreType
        self.totalUp = 0
        self.totalDown = 0
        self.todayUp = 0
        self.todayDown = 0

        // hysteria2 defaults: TLS + h3 + hysteria network
        if `protocol` == .hysteria2 {
            if security == .none { self.security = .tls }
            if alpn == .h2h1 { self.alpn = .h3 }
            self.network = .hysteria2
        } else if `protocol` == .anytls || `protocol` == .naive {
            if security == .none { self.security = .tls }
            self.network = .tcp
        }
    }

    // 自定义表名
    static var databaseTableName: String {
        return "profile" // 设置你的表名
    }

    // 定义数据库列
    enum Columns {
        static let uuid = Column(CodingKeys.uuid)
        static let remark = Column(CodingKeys.remark)
        static let speed = Column(CodingKeys.speed)
        static let sort = Column(CodingKeys.sort)
        static let `protocol` = Column(CodingKeys.protocol)
        static let subid = Column(CodingKeys.subid)
        static let address = Column(CodingKeys.address)
        static let port = Column(CodingKeys.port)
        static let password = Column(CodingKeys.password)
        static let alterId = Column(CodingKeys.alterId)
        static let encryption = Column(CodingKeys.encryption)
        static let network = Column(CodingKeys.network)
        static let headerType = Column(CodingKeys.headerType)
        static let host = Column(CodingKeys.host)
        static let path = Column(CodingKeys.path)
        static let security = Column(CodingKeys.security)
        static let allowInsecure = Column(CodingKeys.allowInsecure)
        static let flow = Column(CodingKeys.flow)
        static let sni = Column(CodingKeys.sni)
        static let alpn = Column(CodingKeys.alpn)
        static let fingerprint = Column(CodingKeys.fingerprint)
        static let publicKey = Column(CodingKeys.publicKey)
        static let shortId = Column(CodingKeys.shortId)
        static let spiderX = Column(CodingKeys.spiderX)
        static let extra = Column(CodingKeys.extra)
        static let shareUri = Column(CodingKeys.shareUri)
        static let serverIp = Column(CodingKeys.serverIp)
        static let serverRegion = Column(CodingKeys.serverRegion)
        static let coreType = Column(CodingKeys.coreType)
        // 统计
        static let totalUp = Column(CodingKeys.totalUp)
        static let totalDown = Column(CodingKeys.totalDown)
        static let todayUp = Column(CodingKeys.todayUp)
        static let todayDown = Column(CodingKeys.todayDown)
        static let lastUpdate = Column(CodingKeys.lastUpdate)
    }

    // MARK: - Hysteria2 Config
    struct Hysteria2Config: Codable {
        var obfsPassword: String = ""
        var hopPortRange: String = ""
        var hopInterval: Int = 30
        var bandwidthUp: String = ""
        var bandwidthDown: String = ""
        var masqueradeJson: String = ""
        var finalMaskJson: String = ""
    }

    func getHysteria2Config() -> Hysteria2Config {
        guard let data = extra.data(using: .utf8),
              let config = try? JSONDecoder().decode(Hysteria2Config.self, from: data) else {
            return Hysteria2Config()
        }
        return config
    }

    // 定义迁移
    static func registerMigrations(in migrator: inout DatabaseMigrator) {
        // 创建表
        migrator.registerMigration("createProfileTable") { db in
            try db.create(table: databaseTableName) { t in
                t.column(Columns.uuid.name, .text).notNull().primaryKey()
                t.column(Columns.remark.name, .text).notNull().defaults(to: "")
                t.column(Columns.speed.name, .integer).notNull()
                t.column(Columns.sort.name, .integer).notNull()
                t.column(Columns.protocol.name, .text).notNull()
                t.column(Columns.subid.name, .text)
                t.column(Columns.address.name, .text).notNull()
                t.column(Columns.port.name, .integer).notNull()
                t.column(Columns.password.name, .text)
                t.column(Columns.alterId.name, .integer)
                t.column(Columns.encryption.name, .text)
                t.column(Columns.network.name, .text)
                t.column(Columns.headerType.name, .text)
                t.column(Columns.host.name, .text)
                t.column(Columns.path.name, .text)
                t.column(Columns.security.name, .text)
                t.column(Columns.allowInsecure.name, .boolean)
                t.column(Columns.flow.name, .text)
                t.column(Columns.sni.name, .text)
                t.column(Columns.alpn.name, .text)
                t.column(Columns.fingerprint.name, .text)
                t.column(Columns.publicKey.name, .text)
                t.column(Columns.shortId.name, .text)
                t.column(Columns.spiderX.name, .text)
                t.column(Columns.extra.name, .text)
                t.column(Columns.shareUri.name, .text)
                t.column(Columns.serverIp.name, .text).notNull().defaults(to: "")
                t.column(Columns.serverRegion.name, .text).notNull().defaults(to: "")
                // 统计
                t.column(Columns.totalUp.name, .integer).notNull().defaults(to: 0)
                t.column(Columns.totalDown.name, .integer).notNull().defaults(to: 0)
                t.column(Columns.todayUp.name, .integer).notNull().defaults(to: 0)
                t.column(Columns.todayDown.name, .integer).notNull().defaults(to: 0)
                t.column(Columns.lastUpdate.name, .datetime).defaults(to: "CURRENT_DATETIME")
            }
        }

        migrator.registerMigration("addProfileCoreType") { db in
            let hasCoreTypeColumn = try db.columns(in: databaseTableName).contains { $0.name == Columns.coreType.name }
            guard !hasCoreTypeColumn else { return }
            try db.alter(table: databaseTableName) { t in
                t.add(column: Columns.coreType.name, .text).defaults(to: ProfileCoreSelection.auto.rawValue)
            }
        }

        migrator.registerMigration("addProfileServerIpAndRegion") { db in
            let cols = Set(try db.columns(in: databaseTableName).map(\.name))
            if !cols.contains(Columns.serverIp.name) {
                try db.alter(table: databaseTableName) { t in
                    t.add(column: Columns.serverIp.name, .text).notNull().defaults(to: "")
                }
            }
            if !cols.contains(Columns.serverRegion.name) {
                try db.alter(table: databaseTableName) { t in
                    t.add(column: Columns.serverRegion.name, .text).notNull().defaults(to: "")
                }
            }
        }
    }

}

enum CombinationColor: String, Codable, CaseIterable, Identifiable {
    case red, orange, yellow, green, teal, blue, indigo, purple, pink, gray

    var id: Self { self }

    var displayName: String { rawValue.capitalized }

    var nsColor: NSColor {
        switch self {
        case .red:     return .systemRed
        case .orange:  return .systemOrange
        case .yellow:  return .systemYellow
        case .green:   return .systemGreen
        case .teal:    return .systemTeal
        case .blue:    return .systemBlue
        case .indigo:  return .systemIndigo
        case .purple:  return .systemPurple
        case .pink:    return .systemPink
        case .gray:    return .systemGray
        }
    }

    var color: Color {
        Color(nsColor)
    }
}

enum CombinedInboundType: String, Codable, CaseIterable, Identifiable {
    case http
    case socks

    var id: Self { self }

    var v2rayProtocol: V2rayProtocolInbound {
        switch self {
        case .http: return .http
        case .socks: return .socks
        }
    }
}

struct CombinedInboundOutboundGroup: Codable, Identifiable, Equatable, Hashable {
    var id: String = UUID().uuidString
    var inboundType: CombinedInboundType = .socks
    var port: Int = 1080
    var outboundProfileUUIDs: [String] = []
}

struct CombinedConfigEntity: Codable, Identifiable, Equatable, Hashable, TableRecord, FetchableRecord, PersistableRecord, IdColumnProtocol {
    var uuid: String
    var remark: String
    var sort: Int
    var groupsJson: String
    var coreType: ProfileCoreSelection?
    var colorName: String
    var balancerStrategy: String
    var lastUpdate: Date

    var id: String { uuid }
    static var idColumn: Column { CombinedConfigEntity.Columns.uuid }
    static var databaseTableName: String { "combined_config" }

    enum CodingKeys: String, CodingKey {
        case uuid, remark, sort, groupsJson, coreType, colorName, balancerStrategy, lastUpdate
    }

    enum Columns {
        static let uuid = Column(CodingKeys.uuid)
        static let remark = Column(CodingKeys.remark)
        static let sort = Column(CodingKeys.sort)
        static let groupsJson = Column(CodingKeys.groupsJson)
        static let coreType = Column(CodingKeys.coreType)
        static let colorName = Column(CodingKeys.colorName)
        static let balancerStrategy = Column(CodingKeys.balancerStrategy)
        static let lastUpdate = Column(CodingKeys.lastUpdate)
    }

    init(
        uuid: String = UUID().uuidString,
        remark: String = "",
        sort: Int = 0,
        groups: [CombinedInboundOutboundGroup] = [CombinedInboundOutboundGroup()],
        coreType: ProfileCoreSelection? = .auto,
        colorName: String = CombinationColor.blue.rawValue,
        balancerStrategy: String = "roundRobin",
        lastUpdate: Date = Date()
    ) {
        self.uuid = uuid
        self.remark = remark
        self.sort = sort
        self.coreType = coreType
        self.colorName = colorName
        self.balancerStrategy = balancerStrategy
        self.lastUpdate = lastUpdate
        self.groupsJson = CombinedConfigEntity.encodeGroups(groups)
    }

    var groups: [CombinedInboundOutboundGroup] {
        get { CombinedConfigEntity.decodeGroups(groupsJson) }
        set { groupsJson = CombinedConfigEntity.encodeGroups(newValue) }
    }

    var displayName: String {
        remark.isEmpty ? "组合配置" : remark
    }

    static func encodeGroups(_ groups: [CombinedInboundOutboundGroup]) -> String {
        guard let data = try? JSONEncoder().encode(groups),
              let text = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return text
    }

    static func decodeGroups(_ text: String) -> [CombinedInboundOutboundGroup] {
        guard let data = text.data(using: .utf8),
              let groups = try? JSONDecoder().decode([CombinedInboundOutboundGroup].self, from: data) else {
            return []
        }
        return groups
    }

    static func registerMigrations(in migrator: inout DatabaseMigrator) {
        migrator.registerMigration("createCombinedConfigTable") { db in
            try db.create(table: databaseTableName, ifNotExists: true) { t in
                t.column(Columns.uuid.name, .text).notNull().primaryKey()
                t.column(Columns.remark.name, .text).notNull().defaults(to: "")
                t.column(Columns.sort.name, .integer).notNull().defaults(to: 0)
                t.column(Columns.groupsJson.name, .text).notNull().defaults(to: "[]")
                t.column(Columns.coreType.name, .text).defaults(to: ProfileCoreSelection.auto.rawValue)
                t.column(Columns.lastUpdate.name, .datetime).defaults(to: "CURRENT_DATETIME")
            }
        }
        migrator.registerMigration("addColorAndBalancerToCombinedConfig") { db in
            if try !db.tableExists(databaseTableName) { return }
            if try !db.columns(in: databaseTableName).contains(where: { $0.name == "colorName" }) {
                try db.alter(table: databaseTableName) { t in
                    t.add(column: Columns.colorName.name, .text).defaults(to: CombinationColor.blue.rawValue)
                }
            }
            if try !db.columns(in: databaseTableName).contains(where: { $0.name == "balancerStrategy" }) {
                try db.alter(table: databaseTableName) { t in
                    t.add(column: Columns.balancerStrategy.name, .text).defaults(to: "roundRobin")
                }
            }
        }
    }
}

struct CombinedConfigStore: StoreProtocol {
    typealias Entity = CombinedConfigEntity

    static let shared = CombinedConfigStore()

    let dbReader: DatabaseReader = AppDatabase.shared.reader
    let dbWriter: DatabaseWriter = AppDatabase.shared.dbWriter

    @discardableResult
    func updateSortOrder(_ entities: [CombinedConfigEntity]) -> Bool {
        do {
            try dbWriter.write { db in
                for (index, var entity) in entities.enumerated() {
                    entity.sort = index
                    entity.lastUpdate = Date()
                    try entity.update(db, columns: [CombinedConfigEntity.Columns.sort, CombinedConfigEntity.Columns.lastUpdate])
                }
            }
            return true
        } catch {
            logger.error("CombinedConfigStore.updateSortOrder error: \(error)")
            return false
        }
    }

    func getValidCombination(uuid: String) -> CombinedConfigEntity? {
        guard let item = fetchOne(uuid: uuid), !item.groups.isEmpty else { return nil }
        let profiles = Dictionary(uniqueKeysWithValues: ProfileStore.shared.fetchAll().map { ($0.uuid, $0) })
        var usedPorts = Set<Int>()

        for group in item.groups {
            guard (1...65535).contains(group.port), !usedPorts.contains(group.port) else { return nil }
            guard !group.outboundProfileUUIDs.isEmpty else { return nil }
            guard group.outboundProfileUUIDs.allSatisfy({ profiles[$0] != nil }) else { return nil }
            usedPorts.insert(group.port)
        }
        return item
    }
}
