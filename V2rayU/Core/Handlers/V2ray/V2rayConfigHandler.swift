//
//  V2rayConfigHandler.swift
//  V2rayU
//
//  Created by yanue on 2024/12/14.
//

import Foundation

let defaultDomesticDns = "119.29.29.29"
let secondaryDomesticDns = "223.5.5.5"
let defaultBootstrapDns = "223.5.5.5"
let defaultDirectDns = "https://dns.alidns.com/dns-query"
let defaultRemoteDns = "https://cloudflare-dns.com/dns-query"
let defaultDnsTargetStrategy = "Default"

let defaultSingboxDns = """
{
    "servers": [
        {"tag": "local-dns", "address": "udp://223.5.5.5"},
        {"tag": "remote-dns", "address": "https://cloudflare-dns.com/dns-query", "address_resolver": "local-dns", "detour": "proxy"}
    ],
    "rules": [
        {"server": "local-dns", "domain": ["localhost", "local"]}
    ],
    "final": "remote-dns",
    "independent_cache": true
}
"""

let defaultDns = """
{
    "hosts": {
      "geosite:category-ads-all": ["127.0.0.1"]
    },
    "servers": [
      {
        "address": "https://cloudflare-dns.com/dns-query",
        "domains": ["geosite:geolocation-!cn"],
        "expectIPs": ["geoip:!cn"]
      },
      {
        "address": "https://dns.google/dns-query",
        "domains": ["geosite:geolocation-!cn"],
        "expectIPs": ["geoip:!cn"]
      },
      "1.1.1.1",
      "223.5.5.5",
      "localhost"
    ],
    "disableFallbackIfMatch": true
  }
"""

func getDefaultDnsSetting() -> String {
    let builtinDns = buildDefaultDnsSetting()
    let dnsJson = UserDefaults.get(forKey: .dnsServers, defaultValue: builtinDns)
    return isLegacyBuiltinDns(dnsJson) ? builtinDns : dnsJson
}

func getDefaultSingboxDnsSetting() -> String {
    let builtinDns = buildDefaultSingboxDnsSetting()
    let dnsJson = UserDefaults.get(forKey: .dnsJsonSingbox, defaultValue: builtinDns)
    return isLegacyBuiltinSingboxDns(dnsJson) ? builtinDns : dnsJson
}

func getDnsDirectSetting() -> String {
    UserDefaults.get(forKey: .dnsDirect, defaultValue: defaultDirectDns)
}

func getDnsRemoteSetting() -> String {
    UserDefaults.get(forKey: .dnsRemote, defaultValue: defaultRemoteDns)
}

func getDnsBootstrapSetting() -> String {
    UserDefaults.get(forKey: .dnsBootstrap, defaultValue: defaultBootstrapDns)
}

func getDnsDirectStrategySetting() -> String {
    UserDefaults.get(forKey: .dnsDirectStrategy, defaultValue: defaultDnsTargetStrategy)
}

func getDnsProxyStrategySetting() -> String {
    UserDefaults.get(forKey: .dnsProxyStrategy, defaultValue: defaultDnsTargetStrategy)
}

func buildDefaultDnsSetting() -> String {
    buildDefaultDnsSetting(
        directDns: getDnsDirectSetting(),
        remoteDns: getDnsRemoteSetting(),
        bootstrapDns: getDnsBootstrapSetting()
    )
}

func buildDefaultDnsSetting(directDns: String, remoteDns: String, bootstrapDns: String) -> String {
    let directDns = directDns.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? defaultDirectDns : directDns.trimmingCharacters(in: .whitespacesAndNewlines)
    let remoteDns = remoteDns.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? defaultRemoteDns : remoteDns.trimmingCharacters(in: .whitespacesAndNewlines)
    let bootstrapDns = bootstrapDns.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? defaultBootstrapDns : bootstrapDns.trimmingCharacters(in: .whitespacesAndNewlines)

    return """
    {
        "hosts": {
          "geosite:category-ads-all": ["127.0.0.1"]
        },
        "servers": [
          {
            "address": "\(remoteDns)",
            "domains": ["geosite:geolocation-!cn"],
            "expectIPs": ["geoip:!cn"]
          },
          {
            "address": "https://dns.google/dns-query",
            "domains": ["geosite:geolocation-!cn"],
            "expectIPs": ["geoip:!cn"]
          },
          {
            "address": "\(directDns)",
            "domains": ["geosite:cn", "geosite:private"],
            "expectIPs": ["geoip:cn", "geoip:private"],
            "skipFallback": true
          },
          "1.1.1.1",
          "\(bootstrapDns)",
          "localhost"
        ],
        "disableFallbackIfMatch": true
      }
    """
}

func buildDefaultSingboxDnsSetting() -> String {
    buildDefaultSingboxDnsSetting(
        directDns: getDnsDirectSetting(),
        remoteDns: getDnsRemoteSetting(),
        bootstrapDns: getDnsBootstrapSetting()
    )
}

func buildDefaultSingboxDnsSetting(directDns directDnsValue: String, remoteDns remoteDnsValue: String, bootstrapDns bootstrapDnsValue: String) -> String {
    let bootstrapDns = bootstrapDnsValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? defaultBootstrapDns : bootstrapDnsValue.trimmingCharacters(in: .whitespacesAndNewlines)
    let remoteDns = normalizedSingboxDoH(remoteDnsValue.trimmingCharacters(in: .whitespacesAndNewlines), defaultHost: "cloudflare-dns.com", defaultPath: "/dns-query")
    let directDns = normalizedSingboxDoH(directDnsValue.trimmingCharacters(in: .whitespacesAndNewlines), defaultHost: "dns.alidns.com", defaultPath: "/dns-query")

    return """
    {
        "servers": [
            {"tag": "local-dns", "address": "udp://\(bootstrapDns)"},
            {"tag": "remote-dns", "address": "https://\(remoteDns.host)\(remoteDns.path)", "address_resolver": "local-dns", "detour": "proxy"}
        ],
        "rules": [
            {"server": "local-dns", "domain": ["localhost", "local"]}
        ],
        "final": "remote-dns",
        "independent_cache": true
    }
    """
}

private func normalizedSingboxDoH(_ value: String, defaultHost: String, defaultPath: String) -> (host: String, path: String) {
    guard let url = URL(string: value), let host = url.host, !host.isEmpty else {
        return (value.isEmpty ? defaultHost : value, defaultPath)
    }
    let path = url.path.isEmpty ? defaultPath : url.path
    return (host, path)
}

func saveDnsBasicSettings(direct: String, remote: String, bootstrap: String, directStrategy: String, proxyStrategy: String) {
    UserDefaults.set(forKey: .dnsDirect, value: direct.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? defaultDirectDns : direct.trimmingCharacters(in: .whitespacesAndNewlines))
    UserDefaults.set(forKey: .dnsRemote, value: remote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? defaultRemoteDns : remote.trimmingCharacters(in: .whitespacesAndNewlines))
    UserDefaults.set(forKey: .dnsBootstrap, value: bootstrap.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? defaultBootstrapDns : bootstrap.trimmingCharacters(in: .whitespacesAndNewlines))
    UserDefaults.set(forKey: .dnsDirectStrategy, value: normalizeDnsTargetStrategy(directStrategy))
    UserDefaults.set(forKey: .dnsProxyStrategy, value: normalizeDnsTargetStrategy(proxyStrategy))
}

func normalizeDnsTargetStrategy(_ strategy: String) -> String {
    let allowed = ["Default", "AsIs", "UseIP", "UseIPv4", "UseIPv6"]
    return allowed.contains(strategy) ? strategy : defaultDnsTargetStrategy
}

func getFreedomDomainStrategySetting() -> String {
    let strategy = normalizeDnsTargetStrategy(getDnsDirectStrategySetting())
    return strategy == "Default" ? "AsIs" : strategy
}

func getLatencyTestURLString() -> String {
    let url = UserDefaults.get(forKey: .pingTestURL, defaultValue: defaultPingTestURL)
    return URL(string: url) == nil ? defaultPingTestURL : url
}

private func isLegacyBuiltinDns(_ dnsJson: String) -> Bool {
    guard let data = dnsJson.data(using: .utf8),
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let servers = json["servers"] as? [Any] else {
        return false
    }

    var hasGoogle = false
    var hasCloudflare = false
    var hasTencentForCN = false
    var hasAli = false

    for server in servers {
        if let server = server as? String {
            hasGoogle = hasGoogle || server == "8.8.8.8"
            hasCloudflare = hasCloudflare || server == "1.1.1.1"
            hasTencentForCN = hasTencentForCN || server == defaultDomesticDns
            hasAli = hasAli || server == secondaryDomesticDns
        } else if let server = server as? [String: Any],
                  let address = server["address"] as? String,
                  let domains = server["domains"] as? [String] {
            hasTencentForCN = hasTencentForCN || (address == defaultDomesticDns && domains.contains("geosite:cn"))
        }
    }

    return (servers.count == 3 && hasGoogle && hasCloudflare && hasTencentForCN) ||
        (servers.count == 4 && hasCloudflare && hasTencentForCN && hasAli)
}

private func isLegacyBuiltinSingboxDns(_ dnsJson: String) -> Bool {
    guard let data = dnsJson.data(using: .utf8),
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let servers = json["servers"] as? [[String: Any]] else {
        return false
    }

    let tags = Set(servers.compactMap { $0["tag"] as? String })
    return tags == Set(["default-dns", "china-dns", "fakedns"])
}

class V2rayConfigHandler {
    var v2ray: V2rayStruct = V2rayStruct()
    var isValid = false

    var error = ""
    var errors: [String] = []

    // base
    var logLevel: V2rayLogLevel = .info
    var socksPort = "1080"
    var socksHost = "127.0.0.1"
    var httpPort = "1087"
    var httpHost = "127.0.0.1"
    var enableSocks = true
    var enableUdp = false
    var enableMux = false
    var enableSniffing = false
    var enableMixedPort = false
    var mixedPort = "1080"
    var mux = 8
    var forPing = false
    var enableTun = false // (暂时不用)这里是xray的tun功能, 但需要单独设置系统路由,需要涉及到代理服务器ip,比较麻烦,因此用sing-box的tun功能->xray的socks作为替换

    // Initialization
    init(enableTun: Bool = false) {
        self.enableMux = UserDefaults.getBool(forKey: .enableMux)
        self.enableUdp = UserDefaults.getBool(forKey: .enableUdp)
        self.enableSniffing = UserDefaults.getBool(forKey: .enableSniffing)
        self.enableMixedPort = isMixedProxyPortEnabled()

        self.httpPort = String(getHttpProxyPort())
        self.socksPort = String(getSocksProxyPort())
        self.mixedPort = String(getMixedProxyPort())

        self.mux = UserDefaults.getInt(forKey: .muxConcurrent ,defaultValue: 8)
        self.enableTun = enableTun

        self.logLevel = UserDefaults.getEnum(forKey: .v2rayLogLevel, type: V2rayLogLevel.self, defaultValue: .info)

        self.socksHost = getListenAddress()
        self.httpHost = getListenAddress()
    }

    // ping配置
    func toJSON(item: ProfileEntity, httpPort: String) -> String {
        toJSON(item: item, httpPort: httpPort, apiPort: nil)
    }

    // ping配置
    func toJSON(item: ProfileEntity, httpPort: String, apiPort: String?) -> String {
        self.forPing = true
        self.enableSocks = false
        self.httpPort = String(httpPort)
        let outbound = V2rayOutboundHandler(from: ProfileModel(from: item)).getOutbound()
        self.combine(_outbounds: [outbound])
        if let apiPort {
            addPingMetrics(apiPort: apiPort)
        }
        return self.v2ray.toJSON()
    }

    // 单个配置
    func toJSON(item: ProfileEntity) -> String {
        let outbound = V2rayOutboundHandler(from: ProfileModel(from: item)).getOutbound()
        self.combine(_outbounds: [outbound])
        return self.v2ray.toJSON()
    }

    // 组合配置
    func toJSON(items: [ProfileEntity]) -> String {
        var _outbounds: [V2rayOutbound] = []
        for (_, item) in items.enumerated() {
            let outbound = V2rayOutboundHandler(from: ProfileModel(from: item)).getOutbound()
            _outbounds.append(outbound)
        }
        self.combine(_outbounds: _outbounds)
        return self.v2ray.toJSON()
    }

    func combine(_outbounds: [V2rayOutbound]) {
        // base
        self.v2ray.log.loglevel = V2rayLogLevel(rawValue: UserDefaults.get(forKey: .v2rayLogLevel)) ?? V2rayLogLevel.info
        if !self.forPing {
            self.v2ray.log.access = coreLogFilePath
            self.v2ray.log.error = coreLogFilePath
        }
        // ------------------------------------- inbound start ---------------------------------------------

        let useMixedInbound = !self.forPing && self.enableMixedPort && !self.enableTun

        var inbounds: [V2rayInbound] = []
        if useMixedInbound {
            // Xray v1.8.24+ SOCKS 入站已默认兼容 HTTP 代理请求（功能等价于 mixed），且仅 v25.3.6+ 支持 mixed 协议别名
            let inMixed = getInbound(protocol: .socks, listen: self.httpHost, port: self.mixedPort, enableSniffing: self.enableSniffing, tag: "mixed-in")
            inbounds.append(inMixed)
        } else {
            if !self.forPing && self.httpPort == self.socksPort {
                self.httpPort = String((Int(self.socksPort) ?? 1080) + 1)
            }
            let inHttp = getInbound(protocol: .http, listen: self.httpHost, port: self.httpPort , enableSniffing: self.enableSniffing, tag: "http-in")
            inbounds.append(inHttp)
        }
        // for ping just use http
        if !self.forPing {
            if self.enableTun {
                let inTun = getInbound(protocol: .tun, listen: "", port: "",enableSniffing: false)
                inbounds.append(inTun)
                let inApi = getInbound(protocol: .dokodemoDoor, listen: "127.0.0.1", port: coreApiPort, enableSniffing: false, tag: "metrics_in")
                inbounds.append(inApi)
            } else if !useMixedInbound {
                let inSocks = getInbound(protocol: .socks, listen: self.socksHost, port: self.socksPort , enableSniffing: self.enableSniffing, tag: "socks-in")
                inbounds.append(inSocks)
                let inApi = getInbound(protocol: .dokodemoDoor, listen: "127.0.0.1", port: coreApiPort, enableSniffing: false, tag: "metrics_in")
                inbounds.append(inApi)
            } else {
                let inApi = getInbound(protocol: .dokodemoDoor, listen: "127.0.0.1", port: coreApiPort, enableSniffing: false, tag: "metrics_in")
                inbounds.append(inApi)
            }
        }
        self.v2ray.inbounds = inbounds

        // ------------------------------------- inbound end ----------------------------------------------
       
        // outbounds
        var outbounds: [V2rayOutbound] = []
        outbounds.append(contentsOf: _outbounds)
        if !self.forPing {
            // outbound Freedom
            let outboundFreedom = V2rayOutbound()
            outboundFreedom.protocol = .freedom
            outboundFreedom.tag = "direct"
            outboundFreedom.settings = V2rayOutboundFreedom(domainStrategy: getFreedomDomainStrategySetting())

            // outbound Blackhole
            let outboundBlackhole = V2rayOutbound()
            outboundBlackhole.protocol = .blackhole
            outboundBlackhole.tag = "block"
            outboundBlackhole.settings = V2rayOutboundBlackhole()
            
            // 添加
            outbounds.append(outboundFreedom)
            outbounds.append(outboundBlackhole)
        }

        self.v2ray.outbounds = outbounds
        var dns = self.getDns() // dns：ping 配置也需要，避免默认海外 DNS 拖慢节点/测速域名解析
        self.applyProxyServerDnsRules(to: &dns, outbounds: _outbounds)
        self.v2ray.dns = dns
        // ------------------------------------- routing start --------------------------------------------
        if !self.forPing {
            self.v2ray.routing = RoutingManager().getRunning() // 路由
            self.v2ray.stats = V2rayStats() // 开启统计
            self.v2ray.metrics = v2rayMetrics() // 启用 metrics,用于请求统计数据
            self.v2ray.policy = V2rayPolicy() // 统计规则
            var observatory = V2rayObservatory() // 观察者
            observatory.probeUrl = getLatencyTestURLString()
            self.v2ray.observatory = observatory
        }
        // ------------------------------------- routing end ----------------------------------------------
    }

    private func addPingMetrics(apiPort: String) {
        let inApi = getInbound(protocol: .dokodemoDoor, listen: "127.0.0.1", port: apiPort, enableSniffing: false, tag: "metrics_in")
        self.v2ray.inbounds?.append(inApi)

        let outboundFreedom = V2rayOutbound()
        outboundFreedom.protocol = .freedom
        outboundFreedom.tag = "direct"
        outboundFreedom.settings = V2rayOutboundFreedom(domainStrategy: getFreedomDomainStrategySetting())
        self.v2ray.outbounds?.append(outboundFreedom)

        var apiRule = V2rayRoutingRule()
        apiRule.type = "field"
        apiRule.inboundTag = ["metrics_in"]
        apiRule.outboundTag = "metrics_out"
        apiRule.domain = nil
        apiRule.ip = nil
        self.v2ray.routing.rules = [apiRule]
        self.v2ray.stats = V2rayStats()
        self.v2ray.metrics = v2rayMetrics()
        self.v2ray.policy = V2rayPolicy()
        var observatory = V2rayObservatory()
        observatory.subjectSelector = ["proxy"]
        observatory.probeUrl = getLatencyTestURLString()
        observatory.probeInterval = "300ms"
        observatory.enableConcurrency = true
        self.v2ray.observatory = observatory
    }

    func toJSON(combination resolved: CombinedConfigResolved) -> String {
        self.v2ray.log.loglevel = V2rayLogLevel(rawValue: UserDefaults.get(forKey: .v2rayLogLevel)) ?? V2rayLogLevel.info
        self.v2ray.log.access = coreLogFilePath
        self.v2ray.log.error = coreLogFilePath

        let listenAddress = getListenAddress()
        let enableSniffing = UserDefaults.getBool(forKey: .enableSniffing)
        var inbounds: [V2rayInbound] = []
        var outbounds: [V2rayOutbound] = []
        var comboRules: [V2rayRoutingRule] = []
        var balancers: [V2rayRoutingBalancer] = []
        var subjectSelector: [String] = []

        for (groupIndex, resolvedGroup) in resolved.groups.enumerated() {
            let inboundTag = "combo-in-\(groupIndex)-\(resolvedGroup.group.inboundType.rawValue)-\(resolvedGroup.group.port)"
            // Xray v1.8.24+ SOCKS 入站已默认兼容 HTTP 代理请求，mixed 协议别名仅 v25.3.6+ 支持
            let proto: V2rayProtocolInbound = resolvedGroup.group.inboundType.v2rayProtocol == .mixed ? .socks : resolvedGroup.group.inboundType.v2rayProtocol
            let inbound = getInbound(
                protocol: proto,
                listen: listenAddress,
                port: String(resolvedGroup.group.port),
                enableSniffing: enableSniffing,
                tag: inboundTag
            )
            inbounds.append(inbound)

            var outboundTags: [String] = []
            for (profileIndex, profile) in resolvedGroup.profiles.enumerated() {
                let outboundTag = "combo-out-\(groupIndex)-\(profileIndex)-\(profile.uuid)"
                let outbound = V2rayOutboundHandler(from: ProfileModel(from: profile)).getOutbound()
                outbound.tag = outboundTag
                outbounds.append(outbound)
                outboundTags.append(outboundTag)
                subjectSelector.append(outboundTag)
            }

            var rule = V2rayRoutingRule()
            rule.type = "field"
            rule.inboundTag = [inboundTag]
            rule.domain = nil
            rule.ip = nil

            if outboundTags.count == 1 {
                rule.outboundTag = outboundTags[0]
            } else {
                let balancerTag = "combo-balancer-\(groupIndex)"
                rule.outboundTag = nil
                rule.balancerTag = balancerTag
                let strat = resolved.combination.balancerStrategy.isEmpty ? "roundRobin" : resolved.combination.balancerStrategy
                balancers.append(V2rayRoutingBalancer(
                    selector: outboundTags,
                    strategy: V2rayRoutingBalancerStrategy(type: strat),
                    tag: balancerTag,
                    fallbackTag: outboundTags.first
                ))
            }
            comboRules.append(rule)
        }

        if let firstProfile = resolved.firstProfile {
            let proxyFallback = V2rayOutboundHandler(from: ProfileModel(from: firstProfile)).getOutbound()
            proxyFallback.tag = "proxy"
            outbounds.append(proxyFallback)
        }

        // Add default proxy inbounds
        if self.enableMixedPort {
            // Xray v1.8.24+ SOCKS 入站已默认兼容 HTTP 代理请求，无需使用 mixed 协议别名
            inbounds.append(getInbound(protocol: .socks, listen: self.httpHost, port: self.mixedPort, enableSniffing: enableSniffing, tag: "mixed-in"))
        } else {
            if self.httpPort == self.socksPort {
                self.httpPort = String((Int(self.socksPort) ?? 1080) + 1)
            }
            inbounds.append(getInbound(protocol: .http, listen: self.httpHost, port: self.httpPort, enableSniffing: enableSniffing, tag: "http-in"))
            inbounds.append(getInbound(protocol: .socks, listen: self.socksHost, port: self.socksPort, enableSniffing: enableSniffing, tag: "socks-in"))
        }

        let inApi = getInbound(protocol: .dokodemoDoor, listen: "127.0.0.1", port: coreApiPort, enableSniffing: false, tag: "metrics_in")
        inbounds.append(inApi)

        let outboundFreedom = V2rayOutbound()
        outboundFreedom.protocol = .freedom
        outboundFreedom.tag = "direct"
        outboundFreedom.settings = V2rayOutboundFreedom(domainStrategy: getFreedomDomainStrategySetting())

        let outboundBlackhole = V2rayOutbound()
        outboundBlackhole.protocol = .blackhole
        outboundBlackhole.tag = "block"
        outboundBlackhole.settings = V2rayOutboundBlackhole()

        outbounds.append(outboundFreedom)
        outbounds.append(outboundBlackhole)

        self.v2ray.inbounds = inbounds
        self.v2ray.outbounds = outbounds
        var dns = self.getDns()
        self.applyProxyServerDnsRules(to: &dns, outbounds: outbounds)
        self.v2ray.dns = dns

        var routing = RoutingManager().getRunning()
        let existingRules = routing.rules.filter { $0.inboundTag != ["metrics_in"] }
        var apiRule = V2rayRoutingRule()
        apiRule.type = "field"
        apiRule.inboundTag = ["metrics_in"]
        apiRule.outboundTag = "metrics_out"
        apiRule.domain = nil
        apiRule.ip = nil
        routing.rules = [apiRule] + comboRules + existingRules
        routing.balancers = balancers.isEmpty ? routing.balancers : (routing.balancers ?? []) + balancers
        self.v2ray.routing = routing

        self.v2ray.stats = V2rayStats()
        self.v2ray.metrics = v2rayMetrics()
        self.v2ray.policy = V2rayPolicy()
        var observatory = V2rayObservatory()
        observatory.subjectSelector = subjectSelector.isEmpty ? ["proxy"] : subjectSelector
        observatory.probeUrl = getLatencyTestURLString()
        self.v2ray.observatory = observatory

        return self.v2ray.toJSON()
    }

    func getDns() -> V2rayDns {
        let dnsJson = getDefaultDnsSetting()
        if let jsonData = dnsJson.data(using: .utf8) {
            do {
                let decoder = JSONDecoder()
                let dns = try decoder.decode(V2rayDns.self, from: jsonData)
                return dns
            } catch {
                logger.info("解析 JSON 失败: \(error)")
            }
        }
        return V2rayDns()
    }

    private func applyProxyServerDnsRules(to dns: inout V2rayDns, outbounds: [V2rayOutbound]) {
        let domains = proxyServerDomains(from: outbounds)
        guard !domains.isEmpty else { return }

        var servers = dns.servers ?? []
        for domain in domains {
            let exists = servers.contains { server in
                if case .detailed(let detail) = server {
                    return detail.address == defaultDomesticDns && detail.domains?.contains(domain) == true
                }
                return false
            }
            if exists { continue }

            let detail = V2rayDns.Server.ServerDetail(
                address: defaultDomesticDns,
                port: nil,
                domains: [domain],
                expectIPs: nil,
                skipFallback: true,
                clientIP: nil,
                queryStrategy: nil
            )
            servers.append(.detailed(detail))
        }
        dns.servers = servers
    }

    private func proxyServerDomains(from outbounds: [V2rayOutbound]) -> [String] {
        var domains: [String] = []

        func appendIfDomain(_ address: String) {
            let value = address.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty, isDomain(str: value), !isIPAddressLiteral(value), !domains.contains(value) else { return }
            domains.append(value)
        }

        for outbound in outbounds where outbound.tag == "proxy" || outbound.tag?.hasPrefix("combo-out-") == true {
            switch outbound.settings {
            case let settings as V2rayOutboundTrojan:
                settings.servers.forEach { appendIfDomain($0.address) }
            case let settings as V2rayOutboundHysteria2:
                appendIfDomain(settings.address)
            case let settings as V2rayOutboundVMess:
                settings.vnext.forEach { appendIfDomain($0.address) }
            case let settings as V2rayOutboundVLess:
                settings.vnext.forEach { appendIfDomain($0.address) }
            case let settings as V2rayOutboundShadowsocks:
                settings.servers.forEach { appendIfDomain($0.address) }
            case let settings as V2rayOutboundSocks:
                settings.servers.forEach { appendIfDomain($0.address) }
            case let settings as V2rayOutboundHttp:
                settings.servers.forEach { appendIfDomain($0.address) }
            default:
                break
            }
        }

        return domains
    }

    func getInbound(`protocol`: V2rayProtocolInbound, listen: String, port: String, enableSniffing:Bool, tag: String? = nil) -> V2rayInbound {
        var inbound = V2rayInbound()
        if `protocol` != .tun {
            inbound.tag = tag
            inbound.listen = listen
            inbound.port = port
        }
        inbound.protocol = `protocol`
        if enableSniffing {
            inbound.sniffing = V2rayInboundSniffing()
        }
        return inbound
    }
}

func isIPAddressLiteral(_ value: String) -> Bool {
    if isIp(str: value) { return true }
    return value.contains(":") && value.range(of: "^[0-9a-fA-F:.]+$", options: .regularExpression) != nil
}

