//
//  V2raySubscription.swift
//  V2rayU
//
//  Created by yanue on 2019/5/15.
//  Copyright © 2019 yanue. All rights reserved.
//

import Cocoa

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
/**
 CREATE TABLE "ProfileItem" (
   "indexId"  varchar NOT NULL,
   "configType"  integer,
   "configVersion"  integer,
   "address"  varchar,
   "port"  integer,
   "id"  varchar,
   "alterId"  integer,
   "security"  varchar,
   "network"  varchar,
   "remarks"  varchar,
   "headerType"  varchar,
   "requestHost"  varchar,
   "path"  varchar,
   "streamSecurity"  varchar,
   "allowInsecure"  varchar,
   "subid"  varchar,
   "isSub"  integer,
   "flow"  varchar,
   "sni"  varchar,
   "alpn"  varchar,
   "coreType"  integer,
   "preSocksPort"  integer,
   "fingerprint"  varchar,
   "displayLog"  integer,
   "publicKey"  varchar,
   "shortId"  varchar,
   "spiderX"  varchar,
   PRIMARY KEY("indexId")
 );
 */
import SwiftUI

class ProxyModel: ObservableObject, Identifiable {
    // 公共属性
    @Published var `protocol`: V2rayProtocolOutbound {
        didSet { updateServerSettings() }
    }

    @Published var network: V2rayStreamNetwork = .tcp {
        didSet { updateStreamSettings() }
    }

    @Published var streamSecurity: V2rayStreamSecurity = .none {
        didSet { updateSecuritySettings() }
    }

    @Published var subid: String
    @Published var address: String
    @Published var port: Int
    @Published var id: String
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

    // 对应编码的 `CodingKeys` 枚举
    enum CodingKeys: String, CodingKey {
        case `protocol`, subid, address, port, id, alterId, security, network, remark, headerType, requestHost, path, streamSecurity, allowInsecure, flow, sni, alpn, fingerprint, publicKey, shortId, spiderX
    }

    // 提供默认值的初始化器
    init(
        protocol: V2rayProtocolOutbound,
        address: String,
        port: Int,
        id: String,
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
        self.protocol = `protocol` // Initialize protocol
        self.address = address // Initialize address
        self.port = port // Initialize port
        self.id = id // Initialize id
        self.alterId = alterId // Initialize alterId
        self.security = security // Initialize security
        self.network = network // Initialize network
        self.remark = remark // Initialize remark
        self.headerType = headerType // Initialize headerType
        self.requestHost = requestHost // Initialize requestHost
        self.path = path // Initialize path
        self.streamSecurity = streamSecurity // Initialize streamSecurity
        self.allowInsecure = allowInsecure // Initialize allowInsecure
        self.subid = subid // Initialize subid
        self.flow = flow // Initialize flow
        self.sni = sni // Initialize sni
        self.alpn = alpn // Initialize alpn
        self.fingerprint = fingerprint // Initialize fingerprint
        self.publicKey = publicKey // Initialize publicKey
        self.shortId = shortId // Initialize shortId
        self.spiderX = spiderX // Initialize spiderX
        // 初始化时调用更新方法
        updateServerSettings()
        updateStreamSettings()
        updateSecuritySettings()
    }

    // 更新 server 配置
    private func updateServerSettings() {
        switch `protocol` {
        case .vmess:
            // user
            var user = V2rayOutboundVMessUser()
            user.id = self.id
            user.alterId = Int(self.alterId)
            user.security = self.security
            // vmess
            serverVmess = V2rayOutboundVMessItem()
            serverVmess.address = self.address
            serverVmess.port = self.port
            serverVmess.users = [user]
        case .vless:
            // user
            var user = V2rayOutboundVLessUser()
            user.id = self.id
            user.flow = self.flow
            user.encryption = self.security
            // vless
            serverVless = V2rayOutboundVLessItem()
            serverVless.address = self.address
            serverVless.port = self.port
            serverVless.users = [user]
        case .shadowsocks:
            serverShadowsocks = V2rayOutboundShadowsockServer()
            serverShadowsocks.address = self.address
            serverShadowsocks.port = self.port
            serverShadowsocks.method = self.security
            serverShadowsocks.password = self.id
        case .socks:
            // user
            var user = V2rayOutboundSockUser()
            user.user = self.id
            user.pass = self.id
            // socks5
            serverSocks5 = V2rayOutboundSockServer()
            serverSocks5.address = self.address
            serverSocks5.port = self.port
            serverSocks5.users = [user]
        case .trojan:
            serverTrojan = V2rayOutboundTrojanServer()
            serverTrojan.address = self.address
            serverTrojan.port = self.port
            serverTrojan.password = self.id
            serverTrojan.flow = self.flow
        default:
            break
        }
    }

    // 更新 stream 配置
    private func updateStreamSettings() {
        switch network {
        case .tcp:
            streamTcp = TcpSettings(
            )
        case .kcp:
            streamKcp = KcpSettings()
        case .domainsocket:
            streamDs = DsSettings()
        case .ws:
            streamWs = WsSettings()
        case .http, .h2:
            streamH2 = HttpSettings()
        case .quic:
            streamQuic = QuicSettings()
        case .grpc:
            streamGrpc = GrpcSettings()
        }
    }

    // 更新 security 配置
    private func updateSecuritySettings() {
        switch streamSecurity {
        case .tls, .xtls:
            securityTls = TlsSettings(
                serverName: sni,
                allowInsecure: allowInsecure,
                alpn: alpn.rawValue,
                fingerprint: fingerprint.rawValue
            )
        case .reality:
            securityReality = RealitySettings(
                fingerprint: fingerprint.rawValue,
                serverName: sni,
                shortId: shortId,
                spiderX: spiderX
            )
        default:
            break
        }
    }

    // 生成 JSON 字符串的方法
    func generateJSON() -> String {
        // 获取 outbound 配置
        let outbound = getOutbound()

        // 使用 JSONEncoder 将对象转换为 JSON 数据
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted // 美化输出（如果需要）
        
        do {
            // 将对象编码为 JSON 数据
            let jsonData = try encoder.encode(outbound)
            
            // 将 JSON 数据转换为字符串
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                return jsonString
            } else {
                return "{}" // 如果转换失败，返回空 JSON 字符串
            }
        } catch {
            print("JSON 编码错误: \(error)")
            return "{}" // 出现错误时返回空 JSON 字符串
        }
    }
    
    func generateSortedJSON() -> String {
        // 获取 outbound 配置
        let outbound = getOutbound()

        // 使用 JSONEncoder 将对象转换为 JSON 数据
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted // 美化输出（如果需要）

        do {
            // 将对象编码为 JSON 数据
            let jsonData = try encoder.encode(outbound)
            
            // 将 JSON 数据转换为字典
            if let jsonObject = try? JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any] {
                // 排序字典的键
                let sortedJsonObject = jsonObject.sorted { $0.key < $1.key }
                
                // 将排序后的字典重新转换为 JSON 数据
                let sortedJsonData = try JSONSerialization.data(withJSONObject: sortedJsonObject, options: .prettyPrinted)
                
                // 将排序后的 JSON 数据转换为字符串
                if let sortedJsonString = String(data: sortedJsonData, encoding: .utf8) {
                    return sortedJsonString
                } else {
                    print("无法将排序后的 JSON 数据转换为字符串")
                    return "{}"
                }
            } else {
                print("JSON 数据转换为字典失败")
                return "{}"
            }
        } catch let error {
            // 捕获编码错误并打印详细信息
            print("JSON 编码错误: \(error)")
            return "{}"
        }
    }



    private func getOutbound() -> V2rayOutbound {
        var outbound = V2rayOutbound()
        outbound.protocol = self.protocol
        outbound.tag = "proxy"

        // 设置协议对应的 settings
        outbound.settings = getProtocolSettings()
        outbound.mux = V2rayOutboundMux()
        outbound.streamSettings = getStreamSettings()

        return outbound
    }

    // 根据用户选择的协议动态生成设置
    private func getProtocolSettings() -> V2rayOutboundSettings? {
        switch self.protocol {
        case .vmess:
            var vmess = V2rayOutboundVMess()
            vmess.vnext = [serverVmess]
            return vmess

        case .vless:
            var vless = V2rayOutboundVLess()
            vless.vnext = [serverVless]
            return vless

        case .shadowsocks:
            var ss = V2rayOutboundShadowsocks()
            ss.servers = [serverShadowsocks]
            return ss

        case .socks:
            var socks5 = V2rayOutboundSocks()
            socks5.servers = [serverSocks5]
            return socks5
            
        case .trojan:
            var trojan = V2rayOutboundTrojan()
            trojan.servers = [serverTrojan]
            return trojan

        default:
            return nil
        }
    }

    // 动态生成 streamSettings
    private func getStreamSettings() -> V2rayStreamSettings {
        var streamSettings = V2rayStreamSettings()
        streamSettings.network = network
        // 根据网络类型动态设置
        switch streamSettings.network {
        case .tcp:
            streamSettings.tcpSettings = streamTcp
        case .kcp:
            streamSettings.kcpSettings = streamKcp
        case .http, .h2:
            streamSettings.httpSettings = streamH2
        case .ws:
            streamSettings.wsSettings = streamWs
        case .domainsocket:
            streamSettings.dsSettings = streamDs
        case .quic:
            streamSettings.quicSettings = streamQuic
        case .grpc:
            streamSettings.grpcSettings = streamGrpc
        }

        // 根据安全设置动态生成
        switch streamSecurity {
        case .tls:
            streamSettings.security = .tls
            streamSettings.tlsSettings = securityTls
        case .xtls:
            streamSettings.security = .xtls
            streamSettings.xtlsSettings = securityTls
        case .reality:
            streamSettings.security = .reality
            streamSettings.realitySettings = securityReality
        default:
            break
        }

        return streamSettings
    }
}
