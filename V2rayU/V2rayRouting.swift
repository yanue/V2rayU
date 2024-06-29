//
//  V2rayRouting.swift
//  V2rayU
//
//  Created by yanue on 2024/6/27.
//  Copyright © 2024 yanue. All rights reserved.
//

import Foundation

let RoutingRuleGlobal = "routing.global"
let RoutingRuleLAN = "routing.lan"
let RoutingRuleCn = "routing.cn"
let RoutingRuleLANAndCn = "routing.lanAndCn"

let defaultRuleCn = Dictionary(uniqueKeysWithValues: [
    (RoutingRuleGlobal, "🌏全局"),
    (RoutingRuleLAN, "🌏 绕过局域网"),
    (RoutingRuleCn, "🌏 绕过中国大陆"),
    (RoutingRuleLANAndCn, "🌏 绕过局域网和中国大陆")
])

let defaultRuleEn = Dictionary(uniqueKeysWithValues: [
    (RoutingRuleGlobal, "🌏 Global"),
    (RoutingRuleLAN, "🌏 Bypassing the LAN Address"),
    (RoutingRuleCn, "🌏 Bypassing mainland address"),
    (RoutingRuleLANAndCn, "🌏 Bypassing LAN and mainland address")
])

let defaultRules = Dictionary(uniqueKeysWithValues: [
    (RoutingRuleGlobal,RoutingItem(name: RoutingRuleGlobal, remark: "")),
    (RoutingRuleLAN,RoutingItem(name: RoutingRuleLAN, remark: "")),
    (RoutingRuleCn,RoutingItem(name: RoutingRuleCn, remark: "")),
    (RoutingRuleLANAndCn,RoutingItem(name: RoutingRuleLANAndCn,remark:""))
])

// ----- routing server manager -----
class V2rayRoutings: NSObject {
    static var shared = V2rayRoutings()

    static let lock = NSLock()

    static let default_rule_content =  """
{
    "domainStrategy": "AsIs",
    "rules": [
    ]
}
"""
    // Initialization
    override init() {
        super.init()
        V2rayRoutings.loadConfig()
    }

    // routing server list
    static private var routings: [RoutingItem] = []

    // (init) load routing server list from UserDefaults
    static func loadConfig() {
        self.lock.lock()
        defer {
            self.lock.unlock()
        }

        // static reset
        self.routings = []

        // load name list from UserDefaults
        var list = UserDefaults.getArray(forKey: .routingCustomList) ?? [];
        
        print("V2rayRoutings-loadConfig", list)
 
        let langStr = Locale.current.languageCode
        let isMainland = langStr == "zh-CN" || langStr == "zh" || langStr == "zh-Hans" || langStr == "zh-Hant"
        // for defaultRules
        for (key, rule) in defaultRules {
            // load and check
            if nil == RoutingItem.load(name: key) {
                if isMainland {
                    rule.remark = defaultRuleCn[key] ?? rule.remark
                } else {
                    rule.remark = defaultRuleEn[key] ?? rule.remark
                }
                // create new
                rule.store()
            } 
            // if not in list, append
            if !list.contains(key) {
                list.append(key)
            }
        }
       
        // load each RoutingItem
        for item in list {
            guard let routing = RoutingItem.load(name: item) else {
                // delete from UserDefaults
                RoutingItem.remove(name: item)
                continue
            }
            // append
            self.routings.append(routing)
        }
        print("V2rayRoutings-loadConfig", self.routings.count)
    }

    static func isDefaultRule(name: String) -> Bool {
        return defaultRules.keys.contains(name)
    }
    
    // get list from routing server list
    static func list() -> [RoutingItem] {
        return self.routings
    }

    static func all()  -> [RoutingItem] {
        // static reset
        var items : [RoutingItem] = []

        // load name list from UserDefaults
        var list = UserDefaults.getArray(forKey: .routingCustomList)
        if list == nil {
            list = []
        }

        // load each V2rayItem
        for item in list! {
            guard let routing = RoutingItem.load(name: item) else {
                // delete from UserDefaults
                RoutingItem.remove(name: item)
                continue
            }
            // append
            items.append(routing) 
        }
        return items
    }
    
    // get count from routing server list
    static func count() -> Int {
        return self.routings.count
    }

    // move item to new index
    static func move(oldIndex: Int, newIndex: Int) {
        if !V2rayRoutings.routings.indices.contains(oldIndex) {
            NSLog("index out of range", oldIndex)
            return
        }
        if !V2rayRoutings.routings.indices.contains(newIndex) {
            NSLog("index out of range", newIndex)
            return
        }

        let o = self.routings[oldIndex]
        self.routings.remove(at: oldIndex)
        self.routings.insert(o, at: newIndex)

        // update server list UserDefaults
        self.saveItemList()
    }

    // add routing server (by scan qrcode)
    static func add(remark: String, json: String) {
        var remark_ = remark
        if remark.count == 0 {
            remark_ = "new routing"
        }

        // name is : routing. + uuid
        let name = "routing." + UUID().uuidString

        let routing = RoutingItem(name: name, remark: remark_, json: json)
        // save to routing UserDefaults
        routing.store()
        

        // just add to mem
        self.routings.append(routing)
        print("routing", name, self.routings)

        // update server list UserDefaults
        self.saveItemList()
    }
    
    // remove routing server (tmp and UserDefaults and config json file)
    static func remove(idx: Int) {
        if !V2rayRoutings.routings.indices.contains(idx) {
            NSLog("index out of range", idx)
            return
        }

        let routing = V2rayRoutings.routings[idx]

        // delete from tmp
        self.routings.remove(at: idx)

        // delete from routing UserDefaults
        RoutingItem.remove(name: routing.name)

        // update server list UserDefaults
        self.saveItemList()

        // if cuerrent item is default
        let curName = UserDefaults.get(forKey: .routingSelectedRule)
        if curName != nil && routing.name == curName {
            UserDefaults.del(forKey: .routingSelectedRule)
        }
    }

    // update server list UserDefaults
    static func saveItemList() {
        var routingCustomList: Array<String> = []
        for item in V2rayRoutings.list() {
            routingCustomList.append(item.name)
        }
        
        print("routingCustomList", routingCustomList);
        UserDefaults.setArray(forKey: .routingCustomList, value: routingCustomList)
    }

    // load json file data
    static func load(idx: Int) -> RoutingItem? {
        if !V2rayRoutings.routings.indices.contains(idx) {
            NSLog("index out of range", idx)
            return nil
        }

        return self.routings[idx]
    }

    static func save(routing: RoutingItem) {
        // store
        routing.store()

        // refresh data
        for (idx, item) in self.routings.enumerated() {
            if item.name == routing.name {
                self.routings[idx].remark = routing.remark
                break
            }
        }
    }

    // get by name
    static func getIndex(name: String) -> Int {
        for (idx, item) in self.routings.enumerated() {
            if item.name == name {
                return idx
            }
        }
        return -1
    }
}

// ----- routing routing item -----
class RoutingItem: NSObject, NSCoding {
    var name: String
    var remark: String
    var json: String
    var domainStrategy: String
    var block: String
    var proxy: String
    var direct: String

    // Initializer
    init(name: String, remark: String, json: String = "", domainStrategy: String = "AsIs", block: String="", proxy: String="", direct: String="") {
        self.name = name
        self.remark = remark
        self.json = json
        self.domainStrategy = domainStrategy
        self.block = block
        self.proxy = proxy
        self.direct = direct
    }

    // NSCoding required initializer (decoding)
    required init(coder decoder: NSCoder) {
        self.name = decoder.decodeObject(forKey: "Name") as? String ?? ""
        self.remark = decoder.decodeObject(forKey: "Remark") as? String ?? ""
        self.json = decoder.decodeObject(forKey: "Json") as? String ?? ""
        self.domainStrategy = decoder.decodeObject(forKey: "DomainStrategy") as? String ?? "AsIs"
        self.block = decoder.decodeObject(forKey: "Block") as? String ?? ""
        self.proxy = decoder.decodeObject(forKey: "Proxy") as? String ?? ""
        self.direct = decoder.decodeObject(forKey: "Direct") as? String ?? ""
    }

    // NSCoding required method (encoding)
    func encode(with coder: NSCoder) {
        coder.encode(name, forKey: "Name")
        coder.encode(remark, forKey: "Remark")
        coder.encode(json, forKey: "Json")
        coder.encode(domainStrategy, forKey: "DomainStrategy")
        coder.encode(block, forKey: "Block")
        coder.encode(proxy, forKey: "Proxy")
        coder.encode(direct, forKey: "Direct")
    }

    // Store into UserDefaults
    func store() {
        let modelData = NSKeyedArchiver.archivedData(withRootObject: self)
        UserDefaults.standard.set(modelData, forKey: self.name)
    }

    func parseRule() -> V2rayRouting {
       if defaultRules.keys.contains(self.name) {
            return self.parseDefaultSettings()
       }
        let (res, err) = parseRoutingRuleJson(json: self.json)
        if err != nil {
            print("parseRule err", err)
        }
        return res
    }
    
    // parse default settings 
    func parseDefaultSettings() -> V2rayRouting {
        
        var rules: [V2rayRoutingSettingRule] = []

        let (blockDomains, blockIps) = parseDomainOrIp(domainIpStr: self.block)
        let (proxyDomains, proxyIps) = parseDomainOrIp(domainIpStr: self.proxy)
        let (directDomains, directIps) = parseDomainOrIp(domainIpStr: self.direct)

        // // rules
        var ruleProxyDomain, ruleProxyIp, ruleDirectDomain, ruleDirectIp, ruleBlockDomain, ruleBlockIp, ruleDirectIpDefault, ruleDirectDomainDefault: V2rayRoutingSettingRule?
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

        switch self.name {
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
            ruleDirectIpDefault = getRoutingRule(outTag: "direct", domain: nil, ip: ["geoip:cn","geoip:private"], port: nil)
            ruleDirectDomainDefault = getRoutingRule(outTag: "direct", domain: ["geosite:cn","localhost"], ip: nil, port: nil)
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
        if V2rayRouting.domainStrategy(rawValue: self.domainStrategy) == nil {
            settings.domainStrategy = .AsIs
        } else {
            settings.domainStrategy = V2rayRouting.domainStrategy(rawValue: self.domainStrategy) ?? .AsIs
        }
        settings.rules = rules
        return settings
    }

    func getRoutingRule(outTag: String, domain:[String]?, ip: [String]?, port:String?) -> V2rayRoutingSettingRule {
        var rule = V2rayRoutingSettingRule()
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

        print("ips", ips, "domains", domains)

        return (domains, ips)
    }

    func isIp(str: String) -> Bool {
        let pattern = "^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])(/[0-9]{2})?$"
        if ((str.count == 0) || (str.range(of: pattern, options: .regularExpression) == nil)) {
            return false
        }
        return true
    }

    func isDomain(str: String) -> Bool {
        let pattern = "[a-zA-Z0-9][-a-zA-Z0-9]{0,62}(.[a-zA-Z0-9][-a-zA-Z0-9]{0,62})+"
        if ((str.count == 0) || (str.range(of: pattern, options: .regularExpression) == nil)) {
            return false
        }
        return true
    }
    
    // static load from UserDefaults
    static func load(name: String) -> RoutingItem? {
        guard let myModelData = UserDefaults.standard.data(forKey: name) else {
            print("load userDefault not found:",name)
            return nil
        }
        do {
            // unarchivedObject(ofClass:from:)
            let result = try NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(myModelData)
            return result as? RoutingItem
        } catch let error {
            print("load userDefault error:", error)
            return nil
        }
    }

    // remove from UserDefaults
    static func remove(name: String) {
        UserDefaults.standard.removeObject(forKey: name)
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
        print("parseJson err",error)
        err = error
    }
    return (res, err)
}
