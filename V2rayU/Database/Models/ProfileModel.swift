//
//  ProfileModel.swift
//  V2rayU
//
//  Created by yanue on 2024/12/2.
//

import GRDB
import SwiftUI
import UniformTypeIdentifiers


struct ProfileDTO: Codable, Identifiable,  Equatable, Hashable {
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

    // Identifiable 协议的要求
    var id: String {
        return uuid
    }
    
    // 对应编码的 `CodingKeys` 枚举
    enum CodingKeys: String, CodingKey {
        case uuid, remark, speed, sort, `protocol`, subid, address, port, password, alterId, encryption, network, headerType, host, path, security, allowInsecure, flow, sni, alpn, fingerprint, publicKey, shortId, spiderX
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
    }
    
}

// 拖动排序
extension ProfileDTO: Transferable {
    static let draggableType = UTType(exportedAs: "net.yanue.V2rayU")

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: draggableType)
    }
}

final class ProfileModel: ObservableObject, Identifiable, Codable, Equatable  {
    var index: Int = 0
    // 公共属性
    @Published var uuid: String // 唯一标识
    @Published var remark: String // 备注
    @Published var speed: Int = -1 // 速度
    @Published var sort: Int = 0 // 排序
    @Published var `protocol`: V2rayProtocolOutbound // 协议
    @Published var network: V2rayStreamNetwork = .tcp // 网络: tcp, kcp, ws, domainsocket, xhttp, h2, grpc, quic
    @Published var security: V2rayStreamSecurity = .none // 底层传输安全加密方式: none, tls, reality
    @Published var subid: String // 订阅ID
    @Published var address: String // 代理服务器地址
    @Published var port: Int // 代理服务器端口
    @Published var password: String // 密码: password(trojan,vmess,shadowsocks) | id(vmess,vless)
    @Published var alterId: Int // vmess
    @Published var encryption: String // 加密方式: security(trojan,vmess) | encryption(vless) | method(shadowsocks)
    @Published var headerType: V2rayHeaderType = .none // 伪装类型: none, http, srtp, utp, wechat-video, dtls, wireguard
    @Published var host: String // 请求域名: headers.Host(ws, h2) | host(xhttp)
    @Published var path: String // 请求路径: path(ws, h2, xhttp) | serviceName(grpc) | key(quic) | seed(kcp)
    @Published var allowInsecure: Bool = true // 允许不安全连接,默认true
    @Published var flow: String = "" // 流控(xtls-rprx-vision | xtls-rprx-vision-udp443): 支持vless|trojan
    @Published var sni: String = "" // sni即serverName(tls): tls|reality
    @Published var alpn: V2rayStreamAlpn = .h2h1 // alpn(tls): tls|reality
    @Published var fingerprint: V2rayStreamFingerprint = .chrome // 浏览器指纹: chrome, firefox, safari, edge, windows, android, ios
    @Published var publicKey: String = "" // publicKey(reality): reality
    @Published var shortId: String = "" // shortId(reality): reality
    @Published var spiderX: String = "" // spiderX(reality): reality

    // Identifiable 协议的要求
    var id: String {
        return uuid
    }
    
    static func == (lhs: ProfileModel, rhs: ProfileModel) -> Bool {
        return lhs.uuid == rhs.uuid
    }

    // 对应编码的 `CodingKeys` 枚举
    enum CodingKeys: String, CodingKey {
        case uuid, remark, speed, sort, `protocol`, subid, address, port, password, alterId, encryption, network, headerType, host, path, security, allowInsecure, flow, sni, alpn, fingerprint, publicKey, shortId, spiderX
    }

    // 需要手动实现 `init(from:)` 和 `encode(to:)`，如果你使用自定义类型时
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        uuid = try container.decode(String.self, forKey: .uuid)
        remark = try container.decode(String.self, forKey: .remark)
        speed = try container.decode(Int.self, forKey: .speed)
        sort = try container.decode(Int.self, forKey: .sort)
        `protocol` = try container.decode(V2rayProtocolOutbound.self, forKey: .protocol)
        network = try container.decode(V2rayStreamNetwork.self, forKey: .network)
        security = try container.decode(V2rayStreamSecurity.self, forKey: .security)
        subid = try container.decode(String.self, forKey: .subid)
        address = try container.decode(String.self, forKey: .address)
        port = try container.decode(Int.self, forKey: .port)
        password = try container.decode(String.self, forKey: .password)
        alterId = try container.decode(Int.self, forKey: .alterId)
        encryption = try container.decode(String.self, forKey: .encryption)
        headerType = try container.decode(V2rayHeaderType.self, forKey: .headerType)
        host = try container.decode(String.self, forKey: .host)
        path = try container.decode(String.self, forKey: .path)
        allowInsecure = try container.decode(Bool.self, forKey: .allowInsecure)
        flow = try container.decode(String.self, forKey: .flow)
        sni = try container.decode(String.self, forKey: .sni)
        alpn = try container.decode(V2rayStreamAlpn.self, forKey: .alpn)
        fingerprint = try container.decode(V2rayStreamFingerprint.self, forKey: .fingerprint)
        publicKey = try container.decode(String.self, forKey: .publicKey)
        shortId = try container.decode(String.self, forKey: .shortId)
        spiderX = try container.decode(String.self, forKey: .spiderX)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(uuid, forKey: .uuid)
        try container.encode(remark, forKey: .remark)
        try container.encode(speed, forKey: .speed)
        try container.encode(sort, forKey: .sort)
        try container.encode(`protocol`, forKey: .protocol)
        try container.encode(network, forKey: .network)
        try container.encode(security, forKey: .security)
        try container.encode(subid, forKey: .subid)
        try container.encode(address, forKey: .address)
        try container.encode(port, forKey: .port)
        try container.encode(password, forKey: .password)
        try container.encode(alterId, forKey: .alterId)
        try container.encode(encryption, forKey: .encryption)
        try container.encode(headerType, forKey: .headerType)
        try container.encode(host, forKey: .host)
        try container.encode(path, forKey: .path)
        try container.encode(allowInsecure, forKey: .allowInsecure)
        try container.encode(flow, forKey: .flow)
        try container.encode(sni, forKey: .sni)
        try container.encode(alpn, forKey: .alpn)
        try container.encode(fingerprint, forKey: .fingerprint)
        try container.encode(publicKey, forKey: .publicKey)
        try container.encode(shortId, forKey: .shortId)
        try container.encode(spiderX, forKey: .spiderX)
    }

    // 提供默认值的初始化器
    init(from dto: ProfileDTO) {
        self.uuid = dto.uuid
        self.speed = dto.speed
        self.sort = dto.sort
        self.remark = dto.remark
        self.protocol = dto.`protocol`
        self.address = dto.address
        self.port = dto.port
        self.password = dto.password
        self.alterId = dto.alterId
        self.encryption = dto.encryption
        self.network = dto.network
        self.headerType = dto.headerType
        self.host = dto.host
        self.path = dto.path
        self.security = dto.security
        self.allowInsecure = dto.allowInsecure
        self.subid = dto.subid
        self.flow = dto.flow
        self.sni = dto.sni
        self.alpn = dto.alpn
        self.fingerprint = dto.fingerprint
        self.publicKey = dto.publicKey
        self.shortId = dto.shortId
        self.spiderX = dto.spiderX
    }
    
    func toDTO() -> ProfileDTO {
        return ProfileDTO(
            uuid: self.uuid,
            remark: self.remark,
            speed: self.speed,
            sort: self.sort,
            protocol: self.protocol,
            address: self.address,
            port: self.port,
            password: self.password,
            alterId: self.alterId,
            encryption: self.encryption,
            network: self.network,
            headerType: self.headerType,
            host: self.host,
            path: self.path,
            security: self.security,
            allowInsecure: self.allowInsecure,
            subid: self.subid,
            flow: self.flow,
            sni: self.sni,
            alpn: self.alpn,
            fingerprint: self.fingerprint,
            publicKey: self.publicKey,
            shortId: self.shortId,
            spiderX: self.spiderX
        )
    }
    
    func clone() -> ProfileModel {
        return ProfileModel(from: self.toDTO())
    }
}

// 实现GRDB
extension ProfileDTO: TableRecord, FetchableRecord, PersistableRecord {
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
    }

    // 定义迁移
    static func registerMigrations(in migrator: inout DatabaseMigrator) {
        // 创建表
        migrator.registerMigration("createProfileTable") { db in
            try db.create(table: databaseTableName) { t in
                t.column(Columns.uuid.name, .text).notNull().primaryKey()
                t.column(Columns.remark.name, .text).notNull()
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
}
