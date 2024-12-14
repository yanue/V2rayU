//
//  ProxyModel.swift
//  V2rayU
//
//  Created by yanue on 2024/12/2.
//

import GRDB
import SwiftUI
import UniformTypeIdentifiers
/**
 - {"type":"ss","name":"v2rayse_test_1","server":"198.57.27.218","port":5004,"cipher":"aes-256-gcm","password":"g5MeD6Ft3CWlJId"}
 - {"type":"ssr","name":"v2rayse_test_3","server":"20.239.49.44","port":59814,"protocol":"origin","cipher":"dummy","obfs":"plain","password":"3df57276-03ef-45cf-bdd4-4edb6dfaa0ef"}
 - {"type":"vmess","name":"v2rayse_test_2","ws-opts":{"path":"/"},"server":"154.23.190.162","port":443,"uuid":"b9984674-f771-4e67-a198-","alterId":"0","cipher":"auto","network":"ws"}
 - {"type":"vless","name":"test","server":"1.2.3.4","port":7777,"uuid":"abc-def-ghi-fge-zsx","skip-cert-verify":true,"network":"tcp","tls":true,"udp":true}
 - {"type":"trojan","name":"v2rayse_test_4","server":"ca-trojan.bonds.id","port":443,"password":"bc7593fe-0604-4fbe--b4ab-11eb-b65e-1239d0255272","udp":true,"skip-cert-verify":true}
 - {"type":"http","name":"http_proxy","server":"124.15.12.24","port":251,"username":"username","password":"password","udp":true}
 - {"type":"socks5","name":"socks5_proxy","server":"124.15.12.24","port":2312,"udp":true}
 - {"type":"socks5","name":"telegram_proxy","server":"1.2.3.4","port":123,"username":"username","password":"password","udp":true}
 */

final class ProxyModel: ObservableObject, Identifiable, Codable, Equatable {
    var index: Int = 0
    // 公共属性
    @Published var uuid: String
    @Published var `protocol`: V2rayProtocolOutbound
    @Published var network: V2rayStreamNetwork = .tcp
    @Published var streamSecurity: V2rayStreamSecurity = .none
    @Published var subid: String
    @Published var address: String
    @Published var port: Int
    @Published var password: String
    @Published var alterId: Int
    @Published var security: String
    @Published var remark: String
    @Published var headerType: V2rayHeaderType = .none
    @Published var requestHost: String
    @Published var path: String
    @Published var allowInsecure: Bool = true
    @Published var flow: String = ""
    @Published var sni: String = ""
    @Published var alpn: V2rayStreamAlpn = .h2h1
    @Published var fingerprint: V2rayStreamFingerprint = .chrome
    @Published var publicKey: String = ""
    @Published var shortId: String = ""
    @Published var spiderX: String = ""
    // Identifiable 协议的要求
    var id: String {
        return uuid
    }

    // Equatable
    static func == (lhs: ProxyModel, rhs: ProxyModel) -> Bool {
        return lhs.uuid == rhs.uuid
    }

    // server
    private(set) var serverVmess = V2rayOutboundVMessItem()
    private(set) var serverSocks5 = V2rayOutboundSockServer()
    private(set) var serverShadowsocks = V2rayOutboundShadowsockServer()
    private(set) var serverVless = V2rayOutboundVLessItem()
    private(set) var serverTrojan = V2rayOutboundTrojanServer()

    // stream settings
    private(set) var streamTcp = TcpSettings()
    private(set) var streamKcp = KcpSettings()
    private(set) var streamDs = DsSettings()
    private(set) var streamWs = WsSettings()
    private(set) var streamH2 = HttpSettings()
    private(set) var streamQuic = QuicSettings()
    private(set) var streamGrpc = GrpcSettings()

    // security settings
    private(set) var securityTls = TlsSettings() // tls|xtls
    private(set) var securityReality = RealitySettings() // reality

    // outbound
    private(set) var outbound = V2rayOutbound()

    // 对应编码的 `CodingKeys` 枚举
    enum CodingKeys: String, CodingKey {
        case uuid, `protocol`, subid, address, port, password, alterId, security, network, remark,
             headerType, requestHost, path, streamSecurity, allowInsecure, flow, sni, alpn, fingerprint, publicKey, shortId, spiderX
    }

    // 需要手动实现 `init(from:)` 和 `encode(to:)`，如果你使用自定义类型时
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        uuid = try container.decode(String.self, forKey: .uuid)
        `protocol` = try container.decode(V2rayProtocolOutbound.self, forKey: .protocol)
        network = try container.decode(V2rayStreamNetwork.self, forKey: .network)
        streamSecurity = try container.decode(V2rayStreamSecurity.self, forKey: .streamSecurity)
        subid = try container.decode(String.self, forKey: .subid)
        address = try container.decode(String.self, forKey: .address)
        port = try container.decode(Int.self, forKey: .port)
        password = try container.decode(String.self, forKey: .password)
        alterId = try container.decode(Int.self, forKey: .alterId)
        security = try container.decode(String.self, forKey: .security)
        remark = try container.decode(String.self, forKey: .remark)
        headerType = try container.decode(V2rayHeaderType.self, forKey: .headerType)
        requestHost = try container.decode(String.self, forKey: .requestHost)
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
        try container.encode(streamSecurity, forKey: .streamSecurity)
        try container.encode(subid, forKey: .subid)
        try container.encode(address, forKey: .address)
        try container.encode(port, forKey: .port)
        try container.encode(password, forKey: .password)
        try container.encode(alterId, forKey: .alterId)
        try container.encode(security, forKey: .security)
        try container.encode(remark, forKey: .remark)
        try container.encode(headerType, forKey: .headerType)
        try container.encode(requestHost, forKey: .requestHost)
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
    required init(
        uuid: String = UUID().uuidString,
        protocol: V2rayProtocolOutbound,
        address: String,
        port: Int,
        password: String,
        alterId: Int = 0,
        security: String,
        network: V2rayStreamNetwork = .tcp,
        remark: String,
        headerType: V2rayHeaderType = .none,
        requestHost: String = "",
        path: String = "",
        streamSecurity: V2rayStreamSecurity = .none,
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
        self.security = security
        self.network = network
        self.remark = remark
        self.headerType = headerType
        self.requestHost = requestHost
        self.path = path
        self.streamSecurity = streamSecurity
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
        // 初始化时调用更新方法
        updateServerSettings()
        updateStreamSettings()
    }
}

// 拖动排序
extension ProxyModel: Transferable {
    static let draggableType = UTType(exportedAs: "net.yanue.V2rayU")

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: ProxyModel.draggableType)
    }
}

extension ProxyModel {
    // 更新 server 配置
    private func updateServerSettings() {
        switch `protocol` {
        case .vmess:
            // user
            var user = V2rayOutboundVMessUser()
            user.id = password
            user.alterId = Int(alterId)
            user.security = security
            // vmess
            serverVmess = V2rayOutboundVMessItem()
            serverVmess.address = address
            serverVmess.port = port
            serverVmess.users = [user]
            var vmess = V2rayOutboundVMess()
            vmess.vnext = [serverVmess]
            outbound.settings = vmess

        case .vless:
            // user
            var user = V2rayOutboundVLessUser()
            user.id = password
            user.flow = flow
            user.encryption = security
            // vless
            serverVless = V2rayOutboundVLessItem()
            serverVless.address = address
            serverVless.port = port
            serverVless.users = [user]
            var vless = V2rayOutboundVLess()
            vless.vnext = [serverVless]
            outbound.settings = vless

        case .shadowsocks:
            serverShadowsocks = V2rayOutboundShadowsockServer()
            serverShadowsocks.address = address
            serverShadowsocks.port = port
            serverShadowsocks.method = security
            serverShadowsocks.password = password
            var ss = V2rayOutboundShadowsocks()
            ss.servers = [serverShadowsocks]
            outbound.settings = ss

        case .socks:
            // user
            var user = V2rayOutboundSockUser()
            user.user = password
            user.pass = password
            // socks5
            serverSocks5 = V2rayOutboundSockServer()
            serverSocks5.address = address
            serverSocks5.port = port
            serverSocks5.users = [user]
            var socks = V2rayOutboundSocks()
            socks.servers = [serverSocks5]
            outbound.settings = socks

        case .trojan:
            serverTrojan = V2rayOutboundTrojanServer()
            serverTrojan.address = address
            serverTrojan.port = port
            serverTrojan.password = password
            serverTrojan.flow = flow
            var outboundTrojan = V2rayOutboundTrojan()
            outboundTrojan.servers = [serverTrojan]
            outbound.settings = outboundTrojan

        default:
            break
        }
    }

    private func updateStreamSettings() {
        var streamSettings = V2rayStreamSettings()
        streamSettings.network = network

        // 根据网络类型配置
        configureStreamSettings(network: network, settings: &streamSettings)

        // 根据安全设置配置
        configureSecuritySettings(security: streamSecurity, settings: &streamSettings)

        outbound.streamSettings = streamSettings
    }

    // 提取网络类型配置
    private func configureStreamSettings(network: V2rayStreamNetwork, settings: inout V2rayStreamSettings) {
        switch network {
        case .tcp:
            streamTcp.header.type = headerType.rawValue
            settings.tcpSettings = streamTcp
        case .kcp:
            streamKcp.header.type = headerType.rawValue
            settings.kcpSettings = streamKcp
        case .http, .h2:
            streamH2.path = path
            streamH2.host = [requestHost]
            settings.httpSettings = streamH2
        case .ws:
            streamWs.path = path
            streamWs.headers.host = requestHost
            settings.wsSettings = streamWs
        case .domainsocket:
            streamDs.path = path
            settings.dsSettings = streamDs
        case .quic:
            streamQuic.key = path
            settings.quicSettings = streamQuic
        case .grpc:
            streamGrpc.serviceName = path
            settings.grpcSettings = streamGrpc
        }
    }

    // 提取安全配置
    private func configureSecuritySettings(security: V2rayStreamSecurity, settings: inout V2rayStreamSettings) {
        settings.security = security
        switch security {
        case .tls, .xtls:
            securityTls = TlsSettings(
                serverName: sni,
                allowInsecure: allowInsecure,
                alpn: alpn.rawValue,
                fingerprint: fingerprint.rawValue
            )
            settings.tlsSettings = securityTls
        case .reality:
            securityReality = RealitySettings(
                fingerprint: fingerprint.rawValue,
                serverName: sni,
                shortId: shortId,
                spiderX: spiderX
            )
            settings.realitySettings = securityReality
        default:
            break
        }
    }

    func toJSON() -> String {
        updateServerSettings()
        updateStreamSettings()
        return outbound.toJSON()
    }
}

extension ProxyModel: FetchableRecord, PersistableRecord {
    // 自定义表名
    static var databaseTableName: String {
        return "proxy" // 设置你的表名
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
        static let security = Column(CodingKeys.security)
        static let network = Column(CodingKeys.network)
        static let remark = Column(CodingKeys.remark)
        static let headerType = Column(CodingKeys.headerType)
        static let requestHost = Column(CodingKeys.requestHost)
        static let path = Column(CodingKeys.path)
        static let streamSecurity = Column(CodingKeys.streamSecurity)
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
        migrator.registerMigration("createProxyTable") { db in
            try db.create(table: ProxyModel.databaseTableName) { t in
                t.column(ProxyModel.Columns.uuid.name, .text).notNull().primaryKey()
                t.column(ProxyModel.Columns.protocol.name, .text).notNull()
                t.column(ProxyModel.Columns.subid.name, .text)
                t.column(ProxyModel.Columns.address.name, .text).notNull()
                t.column(ProxyModel.Columns.port.name, .integer).notNull()
                t.column(ProxyModel.Columns.password.name, .text)
                t.column(ProxyModel.Columns.alterId.name, .integer)
                t.column(ProxyModel.Columns.security.name, .text)
                t.column(ProxyModel.Columns.network.name, .text)
                t.column(ProxyModel.Columns.remark.name, .text)
                t.column(ProxyModel.Columns.headerType.name, .text)
                t.column(ProxyModel.Columns.requestHost.name, .text)
                t.column(ProxyModel.Columns.path.name, .text)
                t.column(ProxyModel.Columns.streamSecurity.name, .text)
                t.column(ProxyModel.Columns.allowInsecure.name, .boolean)
                t.column(ProxyModel.Columns.flow.name, .text)
                t.column(ProxyModel.Columns.sni.name, .text)
                t.column(ProxyModel.Columns.alpn.name, .text)
                t.column(ProxyModel.Columns.fingerprint.name, .text)
                t.column(ProxyModel.Columns.publicKey.name, .text)
                t.column(ProxyModel.Columns.shortId.name, .text)
                t.column(ProxyModel.Columns.spiderX.name, .text)
            }
        }
        //
    }
}
