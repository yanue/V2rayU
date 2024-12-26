//
//  Routing.swift
//  V2rayU
//
//  Created by yanue on 2024/12/14.
//

import Combine
import Foundation
import GRDB

class RoutingHandler {
    private(set) var routing: RoutingModel

    init(from model: RoutingModel) {
        self.routing = model
    }

    // parse default settings
    func getRouting() -> V2rayRouting {
        // 根据json配置生成
        let (res, err) = parseRoutingRuleJson(json: self.routing.json)
        if err != nil {
            print("parseRule err", err)
        } else {
            return res
        }

        // 根据默认规则生成
        var rules: [V2rayRoutingRule] = []

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
        if V2rayRouting.domainStrategy(rawValue: self.routing.domainStrategy) == nil {
            settings.domainStrategy = .AsIs
        } else {
            settings.domainStrategy = V2rayRouting.domainStrategy(rawValue: self.routing.domainStrategy) ?? .AsIs
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