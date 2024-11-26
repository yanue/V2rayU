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
    @Published var `protocol`: V2rayProtocolOutbound
    @Published var subid: String
    @Published var address: String
    @Published var port: Int
    @Published var id: String
    @Published var alterId: Int
    @Published var security: String
    @Published var network: V2rayStreamNetwork = .tcp
    @Published var remark: String
    @Published var headerType: V2rayHeaderType = .none
    @Published var requestHost: String
    @Published var path: String
    @Published var streamSecurity: V2rayStreamSecurity = .none
    @Published var allowInsecure: Bool = true
    @Published var flow: String = ""
    @Published var sni: String = ""
    @Published var alpn: V2rayStreamAlpn = .h2h1
    @Published var fingerprint: V2rayStreamFingerprint = .chrome
    @Published var publicKey: String = ""
    @Published var shortId: String = ""
    @Published var spiderX: String = ""
    
    // 对应编码的 `CodingKeys` 枚举
    enum CodingKeys: String, CodingKey {
        case `protocol`, subid, address, port, id, alterId, security, network, remark, headerType, requestHost, path, streamSecurity, allowInsecure, flow, sni, alpn, fingerprint, publicKey, shortId, spiderX
    }
    
    // 提供默认值的初始化器
    init(
        `protocol`: V2rayProtocolOutbound,
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
        self.protocol = `protocol`  // Initialize protocol
        self.address = address      // Initialize address
        self.port = port            // Initialize port
        self.id = id                // Initialize id
        self.alterId = alterId      // Initialize alterId
        self.security = security    // Initialize security
        self.network = network      // Initialize network
        self.remark = remark        // Initialize remark
        self.headerType = headerType  // Initialize headerType
        self.requestHost = requestHost  // Initialize requestHost
        self.path = path              // Initialize path
        self.streamSecurity = streamSecurity  // Initialize streamSecurity
        self.allowInsecure = allowInsecure  // Initialize allowInsecure
        self.subid = subid          // Initialize subid
        self.flow = flow            // Initialize flow
        self.sni = sni              // Initialize sni
        self.alpn = alpn            // Initialize alpn
        self.fingerprint = fingerprint // Initialize fingerprint
        self.publicKey = publicKey  // Initialize publicKey
        self.shortId = shortId      // Initialize shortId
        self.spiderX = spiderX      // Initialize spiderX
    }
    

    // 生成 JSON 字符串的方法
    func generateJSON() -> String {
        let dictionary: [String: Any] = [
            "protocol": `protocol`.rawValue,  // 这里的 `protocol` 是一个自定义类型
            "subid": subid,
            "address": address,
            "port": port,
            "id": id,
            "alterId": alterId,
            "security": security,
            "network": network.rawValue,  // 假设 V2rayStreamNetwork 是一个枚举类型
            "remark": remark,
            "headerType": headerType.rawValue,  // 假设 V2rayHeaderType 是一个枚举类型
            "requestHost": requestHost,
            "path": path,
            "streamSecurity": streamSecurity.rawValue,  // 假设 V2rayStreamSecurity 是一个枚举类型
            "allowInsecure": allowInsecure,
            "flow": flow,
            "sni": sni,
            "alpn": alpn.rawValue,  // 假设 V2rayStreamAlpn 是一个枚举类型
            "fingerprint": fingerprint.rawValue,  // 假设 V2rayStreamFingerprint 是一个枚举类型
            "publicKey": publicKey,
            "shortId": shortId,
            "spiderX": spiderX
        ]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: dictionary, options: .prettyPrinted)
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                return jsonString
            } else {
                return "{}"
            }
        } catch {
            print("JSONSerialization 错误: \(error)")
            return "{}"
        }
    }
}
