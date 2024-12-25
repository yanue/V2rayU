//
//  ProfileModel.swift
//  V2rayU
//
//  Created by yanue on 2024/12/2.
//

import GRDB
import SwiftUI
import UniformTypeIdentifiers
// vless://E810CEBF-FD2F-4B9F-ACF0-A459E431C624@vlh.yanue.net:443?encryption=none&security=tls&sni=vlh.yanue.net&fp=chrome&pbk=nQhM0Ahmm1WPrUFPxE9_qFxXSQ7weIf7yOeMrZU5gRs&allowInsecure=1&type=http&host=vlh.yanue.net&path=%2Fvlh2#yanue-vless_h2
class ProfileModel: ObservableObject, Identifiable, Codable {
    var index: Int = 0
    // 公共属性
    @Published var uuid: String // 唯一标识
    @Published var remark: String // 备注
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

    // 对应编码的 `CodingKeys` 枚举
    enum CodingKeys: String, CodingKey {
        case uuid, `protocol`, subid, address, port, password, alterId, encryption, network, remark,
             headerType, host, path, security, allowInsecure, flow, sni, alpn, fingerprint, publicKey, shortId, spiderX
    }

    // 需要手动实现 `init(from:)` 和 `encode(to:)`，如果你使用自定义类型时
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        uuid = try container.decode(String.self, forKey: .uuid)
        `protocol` = try container.decode(V2rayProtocolOutbound.self, forKey: .protocol)
        network = try container.decode(V2rayStreamNetwork.self, forKey: .network)
        security = try container.decode(V2rayStreamSecurity.self, forKey: .security)
        subid = try container.decode(String.self, forKey: .subid)
        address = try container.decode(String.self, forKey: .address)
        port = try container.decode(Int.self, forKey: .port)
        password = try container.decode(String.self, forKey: .password)
        alterId = try container.decode(Int.self, forKey: .alterId)
        encryption = try container.decode(String.self, forKey: .encryption)
        remark = try container.decode(String.self, forKey: .remark)
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
        try container.encode(`protocol`, forKey: .protocol)
        try container.encode(network, forKey: .network)
        try container.encode(security, forKey: .security)
        try container.encode(subid, forKey: .subid)
        try container.encode(address, forKey: .address)
        try container.encode(port, forKey: .port)
        try container.encode(password, forKey: .password)
        try container.encode(alterId, forKey: .alterId)
        try container.encode(encryption, forKey: .encryption)
        try container.encode(remark, forKey: .remark)
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
    init(
        uuid: String = UUID().uuidString,
        protocol: V2rayProtocolOutbound,
        address: String,
        port: Int,
        password: String,
        alterId: Int = 0,
        encryption: String,
        network: V2rayStreamNetwork = .tcp,
        remark: String,
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
        self.protocol = `protocol`
        self.address = address
        self.port = port
        self.password = password
        self.alterId = alterId
        self.encryption = encryption
        self.network = network
        self.remark = remark
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
        self.uuid = uuid
    }
}

// 拖动排序
extension ProfileModel: Transferable {
    static let draggableType = UTType(exportedAs: "net.yanue.V2rayU")

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: ProfileModel.draggableType)
    }
}

// 实现GRDB
extension ProfileModel: TableRecord, FetchableRecord, PersistableRecord  {
    // 自定义表名
    static var databaseTableName: String {
        return "profile" // 设置你的表名
    }

    // 定义数据库列
    enum Columns {
        static let uuid = Column(CodingKeys.uuid)
        static let `protocol` = Column(CodingKeys.protocol)
        static let subid = Column(CodingKeys.subid)
        static let address = Column(CodingKeys.address)
        static let port = Column(CodingKeys.port)
        static let password = Column(CodingKeys.password)
        static let alterId = Column(CodingKeys.alterId)
        static let encryption = Column(CodingKeys.encryption)
        static let network = Column(CodingKeys.network)
        static let remark = Column(CodingKeys.remark)
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
            try db.create(table: ProfileModel.databaseTableName) { t in
                t.column(ProfileModel.Columns.uuid.name, .text).notNull().primaryKey()
                t.column(ProfileModel.Columns.protocol.name, .text).notNull()
                t.column(ProfileModel.Columns.subid.name, .text)
                t.column(ProfileModel.Columns.address.name, .text).notNull()
                t.column(ProfileModel.Columns.port.name, .integer).notNull()
                t.column(ProfileModel.Columns.password.name, .text)
                t.column(ProfileModel.Columns.alterId.name, .integer)
                t.column(ProfileModel.Columns.encryption.name, .text)
                t.column(ProfileModel.Columns.network.name, .text)
                t.column(ProfileModel.Columns.remark.name, .text)
                t.column(ProfileModel.Columns.headerType.name, .text)
                t.column(ProfileModel.Columns.host.name, .text)
                t.column(ProfileModel.Columns.path.name, .text)
                t.column(ProfileModel.Columns.security.name, .text)
                t.column(ProfileModel.Columns.allowInsecure.name, .boolean)
                t.column(ProfileModel.Columns.flow.name, .text)
                t.column(ProfileModel.Columns.sni.name, .text)
                t.column(ProfileModel.Columns.alpn.name, .text)
                t.column(ProfileModel.Columns.fingerprint.name, .text)
                t.column(ProfileModel.Columns.publicKey.name, .text)
                t.column(ProfileModel.Columns.shortId.name, .text)
                t.column(ProfileModel.Columns.spiderX.name, .text)
            }
        }
    }
}
