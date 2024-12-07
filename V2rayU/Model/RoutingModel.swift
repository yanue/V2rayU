//
//  V2rayRouting.swift
//  V2rayU
//
//  Created by yanue on 2024/6/27.
//  Copyright © 2024 yanue. All rights reserved.
//

import SwiftUI
import UniformTypeIdentifiers

let RoutingRuleGlobal = "routing.global"
let RoutingRuleLAN = "routing.lan"
let RoutingRuleCn = "routing.cn"
let RoutingRuleLANAndCn = "routing.lanAndCn"

let defaultRuleCn = Dictionary(uniqueKeysWithValues: [
    (RoutingRuleGlobal, "🌏 全局"),
    (RoutingRuleLAN, "🌏 绕过局域网"),
    (RoutingRuleCn, "🌏 绕过中国大陆"),
    (RoutingRuleLANAndCn, "🌏 绕过局域网和中国大陆"),
])

let defaultRuleEn = Dictionary(uniqueKeysWithValues: [
    (RoutingRuleGlobal, "🌏 Global"),
    (RoutingRuleLAN, "🌏 Bypassing the LAN Address"),
    (RoutingRuleCn, "🌏 Bypassing mainland address"),
    (RoutingRuleLANAndCn, "🌏 Bypassing LAN and mainland address"),
])

@MainActor let defaultRules = Dictionary(uniqueKeysWithValues: [
    (RoutingRuleGlobal, RoutingModel(name: RoutingRuleGlobal, remark: "")),
    (RoutingRuleLAN, RoutingModel(name: RoutingRuleLAN, remark: "")),
    (RoutingRuleCn, RoutingModel(name: RoutingRuleCn, remark: "")),
    (RoutingRuleLANAndCn, RoutingModel(name: RoutingRuleLANAndCn, remark: "")),
])

// ----- routing routing item -----
class RoutingModel: ObservableObject, Identifiable, Codable {
    var index: Int = 0
    @Published var uuid: UUID
    @Published var name: String
    @Published var remark: String
    @Published var json: String
    @Published var domainStrategy: String
    @Published var block: String
    @Published var proxy: String
    @Published var direct: String

    // 对应编码的 `CodingKeys` 枚举
    enum CodingKeys: String, CodingKey {
        case uuid, name, remark, json, domainStrategy, block, proxy, direct
    }

    // Initializer
    init(name: String, remark: String, json: String = "", domainStrategy: String = "AsIs", block: String = "", proxy: String = "", direct: String = "") {
        uuid = UUID()
        self.name = name
        self.remark = remark
        self.json = json
        self.domainStrategy = domainStrategy
        self.block = block
        self.proxy = proxy
        self.direct = direct
    }

    // 需要手动实现 `init(from:)` 和 `encode(to:)`，如果你使用自定义类型时
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        uuid = try container.decode(UUID.self, forKey: .uuid)
        name = try container.decode(String.self, forKey: .name)
        remark = try container.decode(String.self, forKey: .remark)
        json = try container.decode(String.self, forKey: .json)
        domainStrategy = try container.decode(String.self, forKey: .domainStrategy)
        block = try container.decode(String.self, forKey: .block)
        proxy = try container.decode(String.self, forKey: .proxy)
        direct = try container.decode(String.self, forKey: .direct)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(uuid, forKey: .uuid)
        try container.encode(name, forKey: .name)
        try container.encode(remark, forKey: .remark)
        try container.encode(json, forKey: .json)
        try container.encode(domainStrategy, forKey: .domainStrategy)
        try container.encode(block, forKey: .block)
        try container.encode(proxy, forKey: .proxy)
        try container.encode(direct, forKey: .direct)
    }

    // parse default settings
    func parseDefaultSettings() -> V2rayRouting {
        var rules: [V2rayRoutingRule] = []

        let (blockDomains, blockIps) = parseDomainOrIp(domainIpStr: block)
        let (proxyDomains, proxyIps) = parseDomainOrIp(domainIpStr: proxy)
        let (directDomains, directIps) = parseDomainOrIp(domainIpStr: direct)

        // // rules
        var ruleProxyDomain, ruleProxyIp, ruleDirectDomain, ruleDirectIp, ruleBlockDomain, ruleBlockIp, ruleDirectIpDefault, ruleDirectDomainDefault: V2rayRoutingRule?
        // proxy
        if proxyDomains.count > 0 {
            ruleProxyDomain = getRoutingRule(outTag: "proxy", domain: proxyDomains, ip: nil, port: nil)
        }
        if proxyIps.count > 0 {
            ruleProxyIp = getRoutingRule(outTag: "proxy", domain: nil, ip: proxyIps, port: nil)
        }

        // direct
        if directDomains.count > 0 {
            ruleDirectDomain = getRoutingRule(outTag: "direct", domain: directDomains, ip: nil, port: nil)
        }
        if directIps.count > 0 {
            ruleDirectIp = getRoutingRule(outTag: "direct", domain: nil, ip: directIps, port: nil)
        }

        // block
        if blockDomains.count > 0 {
            ruleBlockDomain = getRoutingRule(outTag: "block", domain: blockDomains, ip: nil, port: nil)
        }
        if blockIps.count > 0 {
            ruleBlockIp = getRoutingRule(outTag: "block", domain: nil, ip: blockIps, port: nil)
        }

        switch name {
        case RoutingRuleGlobal:
            break
        case RoutingRuleLAN:
            ruleDirectIpDefault = getRoutingRule(outTag: "direct", domain: nil, ip: ["geoip:private"], port: nil)
            ruleDirectDomainDefault = getRoutingRule(outTag: "direct", domain: ["localhost"], ip: nil, port: nil)
            break
        case RoutingRuleCn:
            ruleDirectIpDefault = getRoutingRule(outTag: "direct", domain: nil, ip: ["geoip:cn"], port: nil)
            ruleDirectDomainDefault = getRoutingRule(outTag: "direct", domain: ["geosite:cn"], ip: nil, port: nil)
            break
        case RoutingRuleLANAndCn:
            ruleDirectIpDefault = getRoutingRule(outTag: "direct", domain: nil, ip: ["geoip:cn", "geoip:private"], port: nil)
            ruleDirectDomainDefault = getRoutingRule(outTag: "direct", domain: ["geosite:cn", "localhost"], ip: nil, port: nil)
            break
        default: break
        }
        // 域名阻断 -> 域名代理 -> 域名直连 -> IP阻断 -> IP代理 -> IP直连 的优先级进行匹配

        // 域名阻断
        if ruleBlockDomain != nil {
            ruleBlockDomain?.ip = nil
            rules.append(ruleBlockDomain!)
        }
        // 域名代理
        if ruleProxyDomain != nil {
            ruleProxyDomain?.ip = nil
            rules.append(ruleProxyDomain!)
        }
        // 域名直连
        if ruleDirectDomain != nil {
            ruleDirectDomain!.ip = nil
            rules.append(ruleDirectDomain!)
        }
        // IP阻断
        if ruleBlockIp != nil {
            ruleBlockIp!.domain = nil
            rules.append(ruleBlockIp!)
        }
        // IP代理
        if ruleProxyIp != nil {
            ruleProxyIp!.domain = nil
            rules.append(ruleProxyIp!)
        }
        // IP直连
        if ruleDirectIp != nil {
            ruleDirectIp!.domain = nil
            rules.append(ruleDirectIp!)
        }
        // 如果匹配失败，则私有地址和大陆境内地址直连，否则走代理。
        if ruleDirectIpDefault != nil {
            ruleDirectIpDefault!.domain = nil
            rules.append(ruleDirectIpDefault!)
        }
        if ruleDirectDomainDefault != nil {
            ruleDirectDomainDefault!.ip = nil
            rules.append(ruleDirectDomainDefault!)
        }
        // 默认全部代理, 无需设置规则
        var settings = V2rayRouting()
        if V2rayRouting.domainStrategy(rawValue: domainStrategy) == nil {
            settings.domainStrategy = .AsIs
        } else {
            settings.domainStrategy = V2rayRouting.domainStrategy(rawValue: domainStrategy) ?? .AsIs
        }
        settings.rules = rules
        return settings
    }

    func getRoutingRule(outTag: String, domain: [String]?, ip: [String]?, port: String?) -> V2rayRoutingRule {
        var rule = V2rayRoutingRule()
        rule.outboundTag = outTag
        rule.type = "field"
        rule.domain = domain
        rule.ip = ip
        rule.port = port
        return rule
    }

    func parseDomainOrIp(domainIpStr: String) -> (domains: [String], ips: [String]) {
        let all = domainIpStr.split(separator: "\n")

        var domains: [String] = []
        var ips: [String] = []

        for item in all {
            let tmp = item.trimmingCharacters(in: .whitespacesAndNewlines)

            // is ip
            if isIp(str: tmp) || tmp.contains("geoip:") {
                ips.append(tmp)
                continue
            }

            // is domain
            if tmp.contains("domain:") || tmp.contains("geosite:") {
                domains.append(tmp)
                continue
            }

            if isDomain(str: tmp) {
                domains.append(tmp)
                continue
            }
        }

//        print("ips", ips, "domains", domains)

        return (domains, ips)
    }

    func isIp(str: String) -> Bool {
        let pattern = "^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])(/[0-9]{2})?$"
        if (str.count == 0) || (str.range(of: pattern, options: .regularExpression) == nil) {
            return false
        }
        return true
    }

    func isDomain(str: String) -> Bool {
        let pattern = "[a-zA-Z0-9][-a-zA-Z0-9]{0,62}(.[a-zA-Z0-9][-a-zA-Z0-9]{0,62})+"
        if (str.count == 0) || (str.range(of: pattern, options: .regularExpression) == nil) {
            return false
        }
        return true
    }
}

extension RoutingModel: Transferable {
    static let draggableType = UTType(exportedAs: "net.yanue.V2rayU")

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: RoutingModel.draggableType)
    }
}

// parse json to V2rayRouting
func parseRoutingRuleJson(json: String) -> (V2rayRouting, err: Error?) {
    // utf8
    let jsonData = json.data(using: String.Encoding.utf8, allowLossyConversion: false)
    if jsonData == nil {
        return (V2rayRouting(), nil)
    }
    let jsonDecoder = JSONDecoder()
    var res = V2rayRouting()
    var err: Error?
    do {
        res = try jsonDecoder.decode(V2rayRouting.self, from: jsonData!)
    } catch let error {
        print("parseJson err", error)
        err = error
    }
    return (res, err)
}
