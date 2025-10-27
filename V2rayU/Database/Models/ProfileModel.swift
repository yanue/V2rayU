//
//  ProfileModel.swift
//  V2rayU
//
//  Created by yanue on 2024/12/2.
//

import GRDB
import SwiftUI
import UniformTypeIdentifiers

struct ProfileDTO: Codable, Identifiable, Equatable, Hashable, Transferable, TableRecord, FetchableRecord, PersistableRecord {
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
    var alpn: V2rayStreamAlpn = .h2h1 // alpn(tls): tls|reality
    var fingerprint: V2rayStreamFingerprint = .chrome // 浏览器指纹: chrome, firefox, safari, edge, windows, android, ios
    var publicKey: String = "" // publicKey(reality): reality
    var shortId: String = "" // shortId(reality): reality
    var spiderX: String = "" // spiderX(reality): reality
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

    // 拖动排序
    static let draggableType = UTType(exportedAs: "net.yanue.V2rayU")
    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: draggableType)
    }

    // 对应编码的 `CodingKeys` 枚举
    enum CodingKeys: String, CodingKey {
        case uuid, remark, speed, sort, `protocol`, subid, address, port, password, alterId, encryption, network, headerType, host, path, security, allowInsecure, flow, sni, alpn, fingerprint, publicKey, shortId, spiderX, totalUp, totalDown, todayUp, todayDown, lastUpdate
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
        spiderX: String = ""
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
        self.totalUp = 0
        self.totalDown = 0
        self.todayUp = 0
        self.todayDown = 0
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
        // 统计
        static let totalUp = Column(CodingKeys.totalUp)
        static let totalDown = Column(CodingKeys.totalDown)
        static let todayUp = Column(CodingKeys.todayUp)
        static let todayDown = Column(CodingKeys.todayDown)
        static let lastUpdate = Column(CodingKeys.lastUpdate)
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
                // 统计
                t.column(Columns.totalUp.name, .integer).notNull().defaults(to: 0)
                t.column(Columns.totalDown.name, .integer).notNull().defaults(to: 0)
                t.column(Columns.todayUp.name, .integer).notNull().defaults(to: 0)
                t.column(Columns.todayDown.name, .integer).notNull().defaults(to: 0)
                t.column(Columns.lastUpdate.name, .datetime).defaults(to: "CURRENT_DATETIME")
            }
        }
    }

    func save() {
        do {
            let dbWriter = AppDatabase.shared.dbWriter
            try dbWriter.write { db in
                try self.save(db)
            }
        } catch {
            logger.info("save error: \(error)")
        }
    }
    
    /// profile 唯一标识符, 用于检测重复配置
    /// 不需要 subid, 因为比较时已筛选
    func uniqueKey() -> String {
        return "\(`protocol`.rawValue)-\(address)-\(port)-\(password)-\(alterId)-\(network.rawValue)-\(host)-\(path)-\(security.rawValue)"
    }

    /// 更新 `profile_stat` 表中指定 `uuid` 的统计数据
    static func update_stat(uuid: String, up: Int, down: Int, lastUpdate: Date) throws {
        let sql = """
        UPDATE profile
        SET
            todayUp   = todayUp + ?,
            todayDown = todayDown + ?,
            totalUp   = totalUp + ?,
            totalDown = totalDown + ?,
            lastUpdate = ?
        WHERE uuid = ?
        """
        do {
            let dbWriter = AppDatabase.shared.dbWriter
            try dbWriter.write { db in
                try db.execute(
                    sql: sql,
                    arguments: [up, down, up, down, lastUpdate, uuid]
                )
            }
        } catch {
            logger.info("update_stat error: \(error)")
        }
    }

    /// 清空 `profile_stat` 表中指定 `uuid` 的今日数据
    /// 如果 `lastUpdate` 日期非今天，则将 `todayUp` 和 `todayDown` 清零，并更新 `lastUpdate` 为当前时间
    /// - Parameters:
    ///   - uuid: 唯一标识符
    static func clearTodayData(uuid: String) throws {
        // 获取当前日期的开始时间（00:00:00）
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        do {
            let dbReader = AppDatabase.shared.reader
            return try dbReader.read { db in
                let sql = "SELECT lastUpdate FROM profile WHERE uuid = ?"
                // 查询指定 `uuid` 的 `lastUpdate`
                guard let lastUpdate: Date = try Date.fetchOne(db, sql: sql, arguments: [uuid]) else {
                    // 如果未查询到记录，直接返回
                    return
                }
                // 如果 `lastUpdate` 小于今日开始时间，表示非今天，需要清空今日数据
                if lastUpdate < todayStart {
                    do {
                        let dbWriter = AppDatabase.shared.dbWriter
                        return try dbWriter.write { db in
                            try db.execute(
                                sql: """
                                UPDATE profile
                                SET todayUp = 0, todayDown = 0, lastUpdate = ?
                                WHERE uuid = ?
                                """,
                                arguments: [Date(), uuid]
                            )
                        }
                    } catch {
                        logger.info("getFastOne error: \(error)")
                    }
                }
            }
        } catch {
            logger.info("clearTodayData error: \(error)")
            return
        }
    }
}

// MARK: - UI Model (SwiftUI 绑定)

@dynamicMemberLookup
final class ProfileModel: ObservableObject, Identifiable {
    @Published var dto: ProfileDTO
    var id: String { dto.uuid }

    init(from dto: ProfileDTO) {
        self.dto = dto
    }

    // 动态代理属性访问
    subscript<T>(dynamicMember keyPath: KeyPath<ProfileDTO, T>) -> T {
        dto[keyPath: keyPath]
    }

    subscript<T>(dynamicMember keyPath: WritableKeyPath<ProfileDTO, T>) -> T {
        get { dto[keyPath: keyPath] }
        set { dto[keyPath: keyPath] = newValue }
    }

    // 转换回 DTO
    func toDTO() -> ProfileDTO { dto }

    func clone() -> ProfileModel {
        return ProfileModel(from: self.toDTO())
    }
}
