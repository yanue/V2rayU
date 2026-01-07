//
//  V2rayOutboundHandler.swift
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

class V2rayOutboundHandler {
    private(set) var profile: ProfileModel
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

    // 从 ProfileEntity 初始化
    init(from model: ProfileModel) {
        // 通过传入的 model 初始化 Profile 类的所有属性
        self.profile = model
    }

    func toJSON() -> String {
        self.updateServerSettings()
        self.updateStreamSettings()
        return outbound.toJSON()
    }

    func getOutbound() -> V2rayOutbound {
        self.updateServerSettings()
        self.updateStreamSettings()
        return outbound
    }

    // 更新 server 配置
    private func updateServerSettings() {
        outbound.protocol = self.profile.protocol
        outbound.tag = "proxy"
        switch self.profile.protocol {
        case .vmess:
            // user
            var user = V2rayOutboundVMessUser()
            user.id = self.profile.password
            user.alterId = Int(self.profile.alterId)
            user.security = self.profile.encryption
            // vmess
            serverVmess = V2rayOutboundVMessItem()
            serverVmess.address = self.profile.address
            serverVmess.port = self.profile.port
            serverVmess.users = [user]
            var vmess = V2rayOutboundVMess()
            vmess.vnext = [serverVmess]
            outbound.settings = vmess

        case .vless:
            // user
            var user = V2rayOutboundVLessUser()
            user.id = self.profile.password
            user.flow = self.profile.flow
            user.encryption = self.profile.encryption
            if user.encryption == "" {
                user.encryption = "none" // vless 不支持空字符串
            }
            
            // vless
            serverVless = V2rayOutboundVLessItem()
            serverVless.address = self.profile.address
            serverVless.port = self.profile.port
            serverVless.users = [user]
            var vless = V2rayOutboundVLess()
            vless.vnext = [serverVless]
            outbound.settings = vless

        case .shadowsocks:
            serverShadowsocks = V2rayOutboundShadowsockServer()
            serverShadowsocks.address = self.profile.address
            serverShadowsocks.port = self.profile.port
            serverShadowsocks.method = self.profile.encryption
            serverShadowsocks.password = self.profile.password
            var ss = V2rayOutboundShadowsocks()
            ss.servers = [serverShadowsocks]
            outbound.settings = ss

        case .socks:
            // user
            var user = V2rayOutboundSockUser()
//            user.user = self.profile.alterId // todo
            user.pass = self.profile.password
            // socks5
            serverSocks5 = V2rayOutboundSockServer()
            serverSocks5.address = self.profile.address
            serverSocks5.port = self.profile.port
            serverSocks5.users = [user]
            var socks = V2rayOutboundSocks()
            socks.servers = [serverSocks5]
            outbound.settings = socks

        case .trojan:
            serverTrojan = V2rayOutboundTrojanServer()
            serverTrojan.address = self.profile.address
            serverTrojan.port = self.profile.port
            serverTrojan.password = self.profile.password
            var outboundTrojan = V2rayOutboundTrojan()
            outboundTrojan.servers = [serverTrojan]
            outbound.settings = outboundTrojan

        default:
            break
        }
    }

    private func updateStreamSettings() {
        var streamSettings = V2rayStreamSettings()
        streamSettings.network = self.profile.network

        // 根据网络类型配置
        configureStreamSettings(network: self.profile.network, settings: &streamSettings)

        // 根据安全设置配置
        configureSecuritySettings(security: self.profile.security, settings: &streamSettings)

        outbound.streamSettings = streamSettings
    }

    // 提取网络类型配置
    private func configureStreamSettings(network: V2rayStreamNetwork, settings: inout V2rayStreamSettings) {
        switch network {
        case .tcp:
            if self.profile.headerType != .none {
                streamTcp.header = TcpSettingHeader()
                streamTcp.header?.type = self.profile.headerType.rawValue
                streamTcp.header?.request = TcpSettingHeaderRequest()
                streamTcp.header?.request?.path = [self.profile.path]
                streamTcp.header?.request?.headers.host = [self.profile.host]
            }
            settings.tcpSettings = streamTcp
        case .kcp:
            if self.profile.headerType != .none {
                streamKcp.header = KcpSettingsHeader()
                streamKcp.header?.type = self.profile.headerType.rawValue
            }
            streamKcp.seed = self.profile.path
            settings.kcpSettings = streamKcp
        case .h2:
            streamH2.path = self.profile.path
            streamH2.host = [self.profile.host]
            settings.httpSettings = streamH2
        case .ws:
            streamWs.path = self.profile.path
            streamWs.host = self.profile.host
            streamWs.headers.Host = self.profile.host
            settings.wsSettings = streamWs
        case .domainsocket:
            streamDs.path = self.profile.path
            settings.dsSettings = streamDs
        case .quic:
            streamQuic.key = self.profile.path
            settings.quicSettings = streamQuic
        case .grpc:
            streamGrpc.serviceName = self.profile.path
            settings.grpcSettings = streamGrpc
        case .xhttp:
            streamXhttp.path = self.profile.path
            streamXhttp.host = self.profile.host
            // 假设 profile.extra 是一个 JSON 字符串
            let extraString = self.profile.extra
            if !extraString.isEmpty, let data = extraString.data(using: .utf8) {
                do {
                    let decoder = JSONDecoder()
                    let extra = try decoder.decode(JSONAny.self, from: data)
                    
                    // 赋值给 streamXhttp.extra
                    streamXhttp.extra = extra
                    
                    // 如果外层套了一层 { "extra": { ... } }
                    if let dict = extra.value as? [String: Any], let inner = dict["extra"] {
                        streamXhttp.extra = JSONAny(inner)
                    }
                } catch {
                    print("解析 extra 失败: \(error)")
                }
            }

            settings.xhttpSettings = streamXhttp
        }
    }

    // 提取安全配置
    private func configureSecuritySettings(security: V2rayStreamSecurity, settings: inout V2rayStreamSettings) {
        settings.security = security
        switch security {
        case .tls:
            securityTls = TlsSettings(
                serverName: self.profile.sni,
                allowInsecure: self.profile.allowInsecure,
                alpn: self.profile.alpn.rawValue,
                fingerprint: self.profile.fingerprint.rawValue
            )
            settings.tlsSettings = securityTls
        case .reality:
            securityReality = RealitySettings(
                fingerprint: self.profile.fingerprint.rawValue,
                serverName: self.profile.sni,
                publicKey: self.profile.publicKey,
                shortId: self.profile.shortId,
                spiderX: self.profile.spiderX
            )
            settings.realitySettings = securityReality
        default:
            break
        }
    }
}


extension ProfileEntity {
    func AdaptCore() -> CoreType {
        var mode: CoreType = .XrayCore
        if self.network == .grpc || self.network == .h2 || self.network == .ws {
            mode = .SingBox
        }
        logger.info("AdaptCore: \(self.network.rawValue) -> \(mode.rawValue)")
        return mode
    }
    
    // 是否需要使用oldCore
    func getCoreFile() -> String {
        return  V2rayU.getCoreFile(mode: AdaptCore())
    }
}

func getCoreFile(mode: CoreType = .SingBox) -> String {
    var coreFile: String
#if arch(arm64)
    if mode == .SingBox {
        coreFile = "\(AppHomePath)/bin/sing-box/sing-box-arm64"
    } else {
        coreFile = "\(AppHomePath)/bin/xray-core/xray-arm64"
    }
#else
    if mode == .SingBox {
        coreFile = "\(AppHomePath)/bin/sing-box/sing-box-64"
    } else {
        coreFile = "\(AppHomePath)/bin/xray-core/xray-64"
    }
#endif
    return coreFile
}

extension ProfileEntity {
    /// 使用分享链接保存下来(用于比较是否订阅是否有变化)
    func uniqueKey() -> String {
        if self.shareUri.isEmpty {
            return ShareUri.generateShareUri(item: self)
        } else {
            return self.shareUri
        }
    }
}
