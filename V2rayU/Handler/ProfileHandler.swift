//
//  Profile.swift
//  V2rayU
//
//  Created by yanue on 2024/12/14.
//

import Foundation

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

class ProfileHandler: ProfileModel {
    // 实现 Decodable 协议的初始化方法
    required init(from decoder: Decoder) throws {
        // 先调用父类的初始化方法，解码父类的属性
        try super.init(from: decoder)
    }

    // 从 ProfileModel 初始化
    init(from model: ProfileModel) {
        // 通过传入的 model 初始化 Profile 类的所有属性
        super.init(
            uuid: model.uuid,
            protocol: model.protocol,
            address: model.address,
            port: model.port,
            password: model.password,
            alterId: model.alterId,
            encryption: model.encryption,
            network: model.network,
            remark: model.remark,
            headerType: model.headerType,
            host: model.host,
            path: model.path,
            security: model.security,
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
            user.security = encryption
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
            user.encryption = encryption
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
            serverShadowsocks.method = encryption
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
        configureSecuritySettings(security: security, settings: &streamSettings)

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
            streamKcp.seed = path
            settings.kcpSettings = streamKcp
        case .h2:
            streamH2.path = path
            streamH2.host = [host]
            settings.httpSettings = streamH2
        case .ws:
            streamWs.path = path
            streamWs.host = host
            streamWs.headers.Host = host
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
            streamXhttp.host = host
            settings.xhttpSettings = streamXhttp
        }
    }

    // 提取安全配置
    private func configureSecuritySettings(security: V2rayStreamSecurity, settings: inout V2rayStreamSettings) {
        settings.security = security
        switch security {
        case .tls:
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
