//
//  ProxyModel.swift
//  V2rayU
//
//  Created by yanue on 2024/12/2.
//

import SQLite
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

final class ProxyModel: ObservableObject, Identifiable, Codable {
    var index: Int = 0
    // 公共属性
    @Published var uuid: UUID
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
    // Identifiable 协议的要求
  var id: UUID {
      return uuid
  }
    // 对应编码的 `CodingKeys` 枚举
    enum CodingKeys: String, CodingKey {
        case uuid, `protocol`, subid, address, port, password, alterId, security, network, remark,
             headerType, requestHost, path, streamSecurity, allowInsecure, flow, sni, alpn, fingerprint, publicKey, shortId, spiderX
    }

    // 需要手动实现 `init(from:)` 和 `encode(to:)`，如果你使用自定义类型时
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        uuid = try container.decode(UUID.self, forKey: .uuid)
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
        uuid: UUID = UUID(),
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

extension ProxyModel: DatabaseModel {
    static var tableName: String {
        return "proxy"
    }

    func primaryKeyCondition() -> SQLite.Expression<Bool> {
        return Expression<String>("uuid") == uuid.uuidString
    }

    static func initSql() -> String {
        """
        CREATE TABLE IF NOT EXISTS \(tableName) (
            uuid TEXT PRIMARY KEY,
            protocol TEXT,
            network TEXT,
            streamSecurity TEXT,
            subid TEXT,
            address TEXT,
            port INTEGER,
            password TEXT,
            alterId INTEGER,
            security TEXT,
            remark TEXT,
            headerType TEXT,
            requestHost TEXT,
            path TEXT,
            allowInsecure BOOLEAN,
            flow TEXT,
            sni TEXT,
            alpn TEXT,
            fingerprint TEXT,
            publicKey TEXT,
            shortId TEXT,
            spiderX TEXT
        );
        """
    }

    static func fromRow(_ row: Row) throws -> Self {
        // 提取字段，使用value标签
        let uuidString = try row.get(Expression<String>("uuid"))
        let uuid = UUID(uuidString: uuidString) ?? UUID()
        let protocolValue = try row.get(Expression<String>("protocol"))
        let address = try row.get(Expression<String>("address"))
        let port = try row.get(Expression<Int>("port"))
        let password = try row.get(Expression<String>("password"))
        let alterId = try row.get(Expression<Int>("alterId"))
        let security = try row.get(Expression<String>("security"))
        let networkValue = try row.get(Expression<String>("network"))
        let remark = try row.get(Expression<String>("remark"))
        let headerTypeValue = try row.get(Expression<String>("headerType"))
        let requestHost = try row.get(Expression<String>("requestHost"))
        let path = try row.get(Expression<String>("path"))
        let streamSecurityValue = try row.get(Expression<String>("streamSecurity"))
        let allowInsecureString = try row.get(Expression<Int>("allowInsecure"))
        let allowInsecure = allowInsecureString == 1
        let subid = try row.get(Expression<String>("subid"))
        let flow = try row.get(Expression<String>("flow"))
        let sni = try row.get(Expression<String>("sni"))
        let alpnValue = try row.get(Expression<String>("alpn"))
        let fingerprintValue = try row.get(Expression<String>("fingerprint"))
        let publicKey = try row.get(Expression<String>("publicKey"))
        let shortId = try row.get(Expression<String>("shortId"))
        let spiderX = try row.get(Expression<String>("spiderX"))

        // 将从数据库获取的字段值转化为相应的枚举类型
        let protocolEnum = V2rayProtocolOutbound(rawValue: protocolValue) ?? .vmess
        let networkEnum = V2rayStreamNetwork(rawValue: networkValue) ?? .tcp
        let headerTypeEnum = V2rayHeaderType(rawValue: headerTypeValue) ?? .none
        let streamSecurityEnum = V2rayStreamSecurity(rawValue: streamSecurityValue) ?? .none
        let alpnEnum = V2rayStreamAlpn(rawValue: alpnValue) ?? .h2h1
        let fingerprintEnum = V2rayStreamFingerprint(rawValue: fingerprintValue) ?? .chrome

        // 使用提取的值来初始化模型，传递默认值
        return Self(
            uuid: uuid, // 使用从数据库提取的 UUID
            protocol: protocolEnum,
            address: address,
            port: port,
            password: password,
            alterId: alterId,
            security: security,
            network: networkEnum,
            remark: remark,
            headerType: headerTypeEnum,
            requestHost: requestHost,
            path: path,
            streamSecurity: streamSecurityEnum,
            allowInsecure: allowInsecure,
            subid: subid,
            flow: flow,
            sni: sni,
            alpn: alpnEnum,
            fingerprint: fingerprintEnum,
            publicKey: publicKey,
            shortId: shortId,
            spiderX: spiderX
        )
    }

    // 返回要插入到数据库的数据
    func toInsertValues() -> [Setter] {
        return [
            Expression<String>("uuid") <- uuid.uuidString,
            Expression<String>("protocol") <- `protocol`.rawValue,
            Expression<String>("network") <- network.rawValue,
            Expression<String>("streamSecurity") <- streamSecurity.rawValue,
            Expression<String>("subid") <- subid,
            Expression<String>("address") <- address,
            Expression<Int>("port") <- port,
            Expression<String>("password") <- password,
            Expression<Int>("alterId") <- alterId,
            Expression<String>("security") <- security,
            Expression<String>("remark") <- remark,
            Expression<String>("headerType") <- headerType.rawValue,
            Expression<String>("requestHost") <- requestHost,
            Expression<String>("path") <- path,
            Expression<Bool>("allowInsecure") <- allowInsecure,
            Expression<String>("flow") <- flow,
            Expression<String>("sni") <- sni,
            Expression<String>("alpn") <- alpn.rawValue,
            Expression<String>("fingerprint") <- fingerprint.rawValue,
            Expression<String>("publicKey") <- publicKey,
            Expression<String>("shortId") <- shortId,
            Expression<String>("spiderX") <- spiderX,
        ]
    }
}
