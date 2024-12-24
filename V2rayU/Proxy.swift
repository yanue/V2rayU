//
//  Proxy.swift
//  V2rayU
//
//  Created by yanue on 2024/12/14.
//

import Foundation

class Proxy: ProxyModel {
    // 实现 Decodable 协议的初始化方法
    required init(from decoder: Decoder) throws {
        // 先调用父类的初始化方法，解码父类的属性
        try super.init(from: decoder)
    }

    // 从 ProxyModel 初始化
    init(from model: ProxyModel) {
        // 通过传入的 model 初始化 Proxy 类的所有属性
        super.init(
            uuid: model.uuid,
            protocol: model.protocol,
            address: model.address,
            port: model.port,
            password: model.password,
            alterId: model.alterId,
            security: model.security,
            network: model.network,
            remark: model.remark,
            headerType: model.headerType,
            requestHost: model.requestHost,
            path: model.path,
            streamSecurity: model.streamSecurity,
            allowInsecure: model.allowInsecure,
            subid: model.subid,
            flow: model.flow,
            sni: model.sni,
            alpn: model.alpn,
            fingerprint: model.fingerprint,
            publicKey: model.publicKey,
            shortId: model.shortId,
            spiderX: model.spiderX
        )
    }

    func toJSON() -> String {
        updateServerSettings()
        updateStreamSettings()
        return outbound.toJSON()
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
    private(set) var streamXhttp = XhttpSettings()

    // security settings
    private(set) var securityTls = TlsSettings() // tls|xtls
    private(set) var securityReality = RealitySettings() // reality

    // outbound
    private(set) var outbound = V2rayOutbound()

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
        case .h2:
            streamH2.path = path
            streamH2.host = [requestHost]
            settings.httpSettings = streamH2
        case .ws:
            streamWs.path = path
            streamWs.headers.Host = requestHost
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
        case .xhttp:
            streamXhttp.path = path
            streamXhttp.host = requestHost
            settings.xhttpSettings = streamXhttp
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
}
