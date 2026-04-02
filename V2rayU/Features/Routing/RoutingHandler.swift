//
//  Routing.swift
//  V2rayU
//
//  Created by yanue on 2024/12/14.
//

import Combine
import Foundation
import GRDB

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

func parseDomainOrIp(domainIpStr: String) -> (domains: [String], ips: [String]) {
    let all = domainIpStr.split(separator: "\n")
    var domains: [String] = []
    var ips: [String] = []
    
    for item in all {
        let tmp = item.trimmingCharacters(in: .whitespacesAndNewlines)
        if tmp.isEmpty { continue }
        
        if isIp(str: tmp) || tmp.contains("geoip:") {
            ips.append(tmp)
        } else if tmp.contains("domain:") || tmp.contains("geosite:") || isDomain(str: tmp) {
            domains.append(tmp)
        }
    }
    return (domains, ips)
}

func isIp(str: String) -> Bool {
    let pattern = "^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])(/[0-9]{2})?$"
    return str.range(of: pattern, options: .regularExpression) != nil
}

func isDomain(str: String) -> Bool {
    let pattern = "[a-zA-Z0-9][-a-zA-Z0-9]{0,62}(.[a-zA-Z0-9][-a-zA-Z0-9]{0,62})+"
    return str.range(of: pattern, options: .regularExpression) != nil
}

class RoutingManager {

    let defaultRules = Dictionary(uniqueKeysWithValues: [
       (RoutingRuleGlobal, RoutingEntity(name: RoutingRuleGlobal, remark: "🌏 Global")),
       (RoutingRuleLAN, RoutingEntity(name: RoutingRuleLAN, remark: "🌏 Bypassing the LAN Address", block:"category-ads-all", direct: "geoip:private\nlocalhost")),
       (RoutingRuleCn, RoutingEntity(name: RoutingRuleCn, remark: "🌏 Bypassing mainland address", block:"category-ads-all", direct: "geoip:cn\ngeosite:cn")),
       (RoutingRuleLANAndCn, RoutingEntity(name: RoutingRuleLANAndCn, remark: "🌏 Bypassing LAN and mainland address", block:"category-ads-all", direct: "geoip:cn\ngeoip:private\ngeosite:cn\nlocalhost")),
    ])

    // 获取正在运行路由规则, 优先级: 用户选择 > 默认规则
    func getRunning() -> V2rayRouting {
        let entity = getRunningEntity()
        let handler = RoutingHandler(from: entity)
        if UserDefaults.get(forKey: .runningRouting) != entity.uuid {
            UserDefaults.set(forKey: .runningRouting, value: entity.uuid)
        }
        return handler.getRouting()
    }
    
    // 确保默认路由存在
    private func ensureDefaultRouting() {
        var all = RoutingStore.shared.fetchAll()
        if all.count == 0 {
            for (rule, var item) in defaultRules {
                if isMainland {
                    item.domainStrategy = "AsIs"
                    item.domainMatcher = "hybrid"
                    item.remark = defaultRuleCn[rule] ?? item.remark
                }
                RoutingStore.shared.upsert(item)
                all.append(item)
            }
        }
    }
    
    func getSingboxRoutingRules() -> [RouteRule] {
        let routingEntity = getRunningEntity()
        var rules: [RouteRule] = []
        
        let (blockDomains, blockIps) = parseDomainOrIp(domainIpStr: routingEntity.block)
        let (proxyDomains, proxyIps) = parseDomainOrIp(domainIpStr: routingEntity.proxy)
        let (directDomains, directIps) = parseDomainOrIp(domainIpStr: routingEntity.direct)
        
        if !blockDomains.isEmpty || !blockIps.isEmpty {
            rules.append(RouteRule(outbound: "block", domain: blockDomains + blockIps))
        }
        
        if !proxyDomains.isEmpty || !proxyIps.isEmpty {
            rules.append(RouteRule(outbound: "proxy", domain: proxyDomains + proxyIps))
        }
        
        if !directDomains.isEmpty || !directIps.isEmpty {
            rules.append(RouteRule(outbound: "direct", domain: directDomains + directIps))
        }
        
        switch routingEntity.name {
        case RoutingRuleGlobal:
            break
        case RoutingRuleLAN:
            if !directIps.contains("geoip:private") {
                rules.append(RouteRule(outbound: "direct", domain: ["geoip:private"]))
            }
            if !directDomains.contains("localhost") {
                rules.append(RouteRule(outbound: "direct", domain: ["localhost"]))
            }
        case RoutingRuleCn:
            if !directIps.contains("geoip:cn") {
                rules.append(RouteRule(outbound: "direct", domain: ["geoip:cn"]))
            }
            if !directDomains.contains("geosite:cn") {
                rules.append(RouteRule(outbound: "direct", domain: ["geosite:cn"]))
            }
        case RoutingRuleLANAndCn:
            if !directIps.contains("geoip:cn") {
                rules.append(RouteRule(outbound: "direct", domain: ["geoip:cn"]))
            }
            if !directIps.contains("geoip:private") {
                rules.append(RouteRule(outbound: "direct", domain: ["geoip:private"]))
            }
            if !directDomains.contains("geosite:cn") {
                rules.append(RouteRule(outbound: "direct", domain: ["geosite:cn"]))
            }
            if !directDomains.contains("localhost") {
                rules.append(RouteRule(outbound: "direct", domain: ["localhost"]))
            }
        default:
            break
        }
        
        return rules
    }
    
    func getRunningEntity() -> RoutingEntity {
        ensureDefaultRouting()
        let runningRouting = UserDefaults.get(forKey: .runningRouting)
        let all = RoutingStore.shared.fetchAll()
        for item in all {
            if item.uuid == runningRouting {
                return item
            }
        }
        if let first = all.first {
            return first
        }
        return defaultRules[RoutingRuleLANAndCn]!
    }
    
}

class RoutingHandler {
    private(set) var routing: RoutingEntity

    init(from model: RoutingEntity) {
        self.routing = model
    }

    // parse default settings
    func getRouting() -> V2rayRouting {
        // api-rule:  {"inboundTag": ["api"], "outboundTag": "api", "type": "field"}
        let apiRule = getRoutingRule(outTag: "metrics_out", inboundTag: ["metrics_in"])

        // 根据默认规则生成
        var rules: [V2rayRoutingRule] = [apiRule]

        let (blockDomains, blockIps) = parseDomainOrIp(domainIpStr: self.routing.block)
        let (proxyDomains, proxyIps) = parseDomainOrIp(domainIpStr: self.routing.proxy)
        let (directDomains, directIps) = parseDomainOrIp(domainIpStr: self.routing.direct)

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

        switch self.routing.name {
        case RoutingRuleGlobal:
            break
        case RoutingRuleLAN:
            if directIps.isEmpty {
                ruleDirectIpDefault = getRoutingRule(outTag: "direct", domain: nil, ip: ["geoip:private"], port: nil)
            }
            if directDomains.isEmpty {
                ruleDirectDomainDefault = getRoutingRule(outTag: "direct", domain: ["localhost"], ip: nil, port: nil)
            }
            break
        case RoutingRuleCn:
            if directIps.isEmpty {
                ruleDirectIpDefault = getRoutingRule(outTag: "direct", domain: nil, ip: ["geoip:cn"], port: nil)
            }
            if directDomains.isEmpty {
                ruleDirectDomainDefault = getRoutingRule(outTag: "direct", domain: ["geosite:cn"], ip: nil, port: nil)
            }
            break
        case RoutingRuleLANAndCn:
            if directIps.isEmpty {
                ruleDirectIpDefault = getRoutingRule(outTag: "direct", domain: nil, ip: ["geoip:cn", "geoip:private"], port: nil)
            }
            if directDomains.isEmpty {
                ruleDirectDomainDefault = getRoutingRule(outTag: "direct", domain: ["geosite:cn", "localhost"], ip: nil, port: nil)
            }
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
        if V2rayRouting.domainStrategy(rawValue: self.routing.domainStrategy) == nil {
            settings.domainStrategy = .AsIs
        } else {
            settings.domainStrategy = V2rayRouting.domainStrategy(rawValue: self.routing.domainStrategy) ?? .AsIs
        }
        // 最后添加默认规则
//        let proxyRule = getRoutingRule(outTag: "proxy", )
//        rules.append(proxyRule)
        settings.rules = rules
        return settings
    }

    func getRoutingRule(outTag: String, domain: [String]? = nil, ip: [String]? = nil, port: String? = nil, inboundTag: [String]? = nil, network: String? = nil) -> V2rayRoutingRule {
        var rule = V2rayRoutingRule()
        rule.outboundTag = outTag
        rule.inboundTag = inboundTag
        rule.type = "field"
        rule.domain = domain
        rule.ip = ip
        rule.port = port
        rule.network = network
        return rule
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
        logger.info("parseRoutingRuleJson err: \(json), \(error)")
        err = error
    }
    return (res, err)
}
