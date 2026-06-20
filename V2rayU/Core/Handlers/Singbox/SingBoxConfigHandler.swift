//
//  SingBoxConfigHandler.swift
//  V2rayU
//
//  Created by yanue on 2026/1/7.
//

import Foundation

enum SingboxVersionCheck {
    static func supportsSniffRuleAction() -> Bool {
        guard let version = SingboxVersion(getSingboxVersion()) else { return true }
        return version >= SingboxVersion(1, 11, 0)
    }

    static func supportsNewDnsFormat() -> Bool {
        guard let version = SingboxVersion(getSingboxVersion()) else { return true }
        return version >= SingboxVersion(1, 12, 0)
    }

    static func geositeRemoved() -> Bool {
        guard let version = SingboxVersion(getSingboxVersion()) else { return true }
        return version >= SingboxVersion(1, 12, 0)
    }

    static func supportsRuleSet() -> Bool {
        guard let version = SingboxVersion(getSingboxVersion()) else { return true }
        return version >= SingboxVersion(1, 8, 0)
    }

    static func blockOutboundRemoved() -> Bool {
        guard let version = SingboxVersion(getSingboxVersion()) else { return true }
        return version >= SingboxVersion(1, 13, 0)
    }
}

class SingboxConfigHandler {
    var singbox: SingboxStruct = SingboxStruct()
    var isValid = false

    var error = ""
    var errors: [String] = []

    // base
    var socksPort = "1080"
    var socksHost = "127.0.0.1"
    var httpPort = "1087"
    var httpHost = "127.0.0.1"
    var enableMixedPort = false
    var mixedPort = "1080"
    var enableTun = false
    var forPing = false
    var domain_resolver = "direct-dns"
    var logLevel: V2rayLogLevel = .info

    init(enableTun: Bool = false) {
        self.enableTun = enableTun
        self.httpPort = String(getHttpProxyPort())
        self.socksPort = String(getSocksProxyPort())
        self.enableMixedPort = isMixedProxyPortEnabled()
        self.mixedPort = String(getMixedProxyPort())
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
        self.httpPort = httpPort
        var outbound = SingboxOutboundHandler(from: ProfileModel(from: item)).getOutbound()
        outbound.domain_resolver = domain_resolver
        self.combine(_outbounds: [outbound])
        if let apiPort {
            self.singbox.experimental = ExperimentalConfig(
                clash_api: ClashAPIConfig(
                    external_controller: "127.0.0.1:\(apiPort)",
                    secret: ""
                )
            )
        }
        return self.singbox.toJSON()
    }

    // 单个配置
    func toJSON(item: ProfileEntity) -> String {
        var outbound = SingboxOutboundHandler(from: ProfileModel(from: item)).getOutbound()
        outbound.domain_resolver = domain_resolver
        // outbound Freedom
        let outboundDirect = SingboxOutbound(type: "direct", tag: "direct")
        // outbound Blackhole
        let outboundBlock = SingboxOutbound(type: "block", tag: "block")
        self.combine(_outbounds: [outbound, outboundDirect, outboundBlock])
        return self.singbox.toJSON()
    }

    // 多个配置
    func toJSON(items: [ProfileEntity]) -> String {
        var _outbounds: [SingboxOutbound] = []
        for item in items {
            var outbound = SingboxOutboundHandler(from: ProfileModel(from: item)).getOutbound()
            outbound.domain_resolver = domain_resolver
            _outbounds.append(outbound)
        }
        self.combine(_outbounds: _outbounds)
        return self.singbox.toJSON()
    }

    func toJSON(combination resolved: CombinedConfigResolved) -> String {
        applyLogConfig(level: V2rayLogLevel(rawValue: UserDefaults.get(forKey: .v2rayLogLevel)) ?? V2rayLogLevel.info)
        self.singbox.log.timestamp = true
        if self.singbox.log.disabled != true {
            self.singbox.log.output = coreLogFilePath
        }

        let listenAddress = getListenAddress()
        var inbounds: [SingboxInbound] = []
        var outbounds: [SingboxOutbound] = []
        var comboRules: [RouteRule] = []

        for (groupIndex, resolvedGroup) in resolved.groups.enumerated() {
            let inboundTag = "combo-in-\(groupIndex)-\(resolvedGroup.group.inboundType.rawValue)-\(resolvedGroup.group.port)"
            inbounds.append(SingboxInbound(
                type: resolvedGroup.group.inboundType.rawValue,
                tag: inboundTag,
                listen: listenAddress,
                listen_port: resolvedGroup.group.port
            ))

            var outboundTags: [String] = []
            for (profileIndex, profile) in resolvedGroup.profiles.enumerated() {
                var outbound = SingboxOutboundHandler(from: ProfileModel(from: profile)).getOutbound()
                let outboundTag = "combo-out-\(groupIndex)-\(profileIndex)-\(profile.uuid)"
                outbound.tag = outboundTag
                outbound.domain_resolver = domain_resolver
                outbounds.append(outbound)
                outboundTags.append(outboundTag)
            }

            let routeOutbound = "combo-selector-\(groupIndex)"
            let isMultiOutbound = outboundTags.count > 1
            let balancerStrategy = resolved.combination.balancerStrategy
            let groupType: String
            if isMultiOutbound, balancerStrategy == "leastPing" || balancerStrategy == "leastLoad" {
                groupType = "urltest"
            } else {
                groupType = "selector"
            }
            outbounds.append(SingboxOutbound(
                type: groupType,
                tag: routeOutbound,
                outbounds: outboundTags
            ))
            comboRules.append(RouteRule(outbound: routeOutbound, domain: nil, process_name: nil, inbound: [inboundTag]))
        }

        if let firstProfile = resolved.firstProfile {
            var proxyFallback = SingboxOutboundHandler(from: ProfileModel(from: firstProfile)).getOutbound()
            proxyFallback.tag = "proxy"
            proxyFallback.domain_resolver = domain_resolver
            outbounds.append(proxyFallback)
        }

        outbounds.append(SingboxOutbound(type: "direct", tag: "direct"))
        outbounds.append(SingboxOutbound(type: "block", tag: "block"))

        // Add default SOCKS/HTTP proxy inbounds
        if !self.enableMixedPort && self.httpPort == self.socksPort {
            self.httpPort = String((Int(self.socksPort) ?? 1080) + 1)
        }
        if self.enableMixedPort {
            inbounds.append(SingboxInbound(type: "mixed", tag: "mixed-in", listen: self.httpHost, listen_port: Int(self.mixedPort)))
        } else {
            inbounds.append(SingboxInbound(type: "http", tag: "http-in", listen: self.httpHost, listen_port: Int(self.httpPort)))
            inbounds.append(SingboxInbound(type: "socks", tag: "socks-in", listen: self.socksHost, listen_port: Int(self.socksPort)))
        }

        self.singbox.inbounds = inbounds
        self.singbox.outbounds = outbounds
        self.singbox.dns = dnsConfigWithProxyServerRules(outbounds: outbounds)
        self.singbox.route.default_domain_resolver = "direct-dns"
        var routeRules = comboRules + RoutingManager().getSingboxRoutingRules()
        if SingboxVersionCheck.blockOutboundRemoved() {
            migrateBlockOutboundToAction(&routeRules)
            self.singbox.outbounds.removeAll { $0.type == "block" }
        }
        routeRules.append(RouteRule(outbound: "proxy", rule_set: ["geoip-cn"], invert: true))
        self.singbox.route.rules = routeRules
        self.singbox.applyBundledRuleSets()
        self.singbox.experimental = ExperimentalConfig(
            clash_api: ClashAPIConfig(
                external_controller: "127.0.0.1:\(coreApiPort)",
                secret: ""
            )
        )

        return self.singbox.toJSON()
    }

    func combine(_outbounds: [SingboxOutbound]) {
        // base
        applyLogConfig(level: V2rayLogLevel(rawValue: UserDefaults.get(forKey: .v2rayLogLevel)) ?? V2rayLogLevel.info)
        self.singbox.log.timestamp = true
        if !self.forPing && self.singbox.log.disabled != true {
            self.singbox.log.output = coreLogFilePath
        }
        var inbounds: [SingboxInbound] = []

        // 非TUN模式配置
        // 默认 inbound: socks + http
        if !self.enableMixedPort && self.httpPort == self.socksPort {
            self.httpPort = String((Int(self.socksPort) ?? 1080) + 1)
        }

        if !self.forPing && self.enableMixedPort {
            let mixedInbound = SingboxInbound(
                type: "mixed",
                tag: "mixed-in",
                listen: self.httpHost,
                listen_port: Int(self.mixedPort)
            )
            inbounds.append(mixedInbound)
        } else {
            let httpInbound = SingboxInbound(
                type: "http",
                tag: "http-in",
                listen: self.httpHost,
                listen_port: Int(self.httpPort),
            )
            inbounds.append(httpInbound)
        }

        if !self.forPing {
            if !self.enableMixedPort {
                let socksInbound = SingboxInbound(
                    type: "socks",
                    tag: "socks-in",
                    listen: self.socksHost,
                    listen_port: Int(self.socksPort),
                )
                inbounds.append(socksInbound)
            }

            let clashConfig = ExperimentalConfig(
                clash_api: ClashAPIConfig(
                    external_controller: "127.0.0.1:\(coreApiPort)",
                    secret: ""
                )
            )

            singbox.experimental = clashConfig
        }

        self.singbox.inbounds = inbounds
        self.singbox.outbounds = _outbounds

        if self.forPing {
            if singboxSupportsNewDnsFormat() {
                self.singbox.dns.servers = [
                    DNSServer(tag: "direct-dns", type: "udp", server: defaultBootstrapDns),
                ]
            } else {
                self.singbox.dns.servers = [
                    DNSServer(tag: "direct-dns", address: "udp://\(defaultBootstrapDns)"),
                ]
            }
        } else {
            self.singbox.dns = dnsConfigWithProxyServerRules(outbounds: _outbounds)
            self.singbox.route.default_domain_resolver = "local-dns"
            var routeRules = RoutingManager().getSingboxRoutingRules()
            if singboxBlockOutboundRemoved() {
                migrateBlockOutboundToAction(&routeRules)
                self.singbox.outbounds.removeAll { $0.type == "block" }
            }
            routeRules.append(RouteRule(outbound: "proxy", rule_set: ["geoip-cn"], invert: true))
            self.singbox.route.rules = routeRules
            self.singbox.applyBundledRuleSets()
        }
        logger.debug("_outbounds: \(self.forPing) \(self.singbox.toJSON())")
    }

    private func migrateBlockOutboundToAction(_ rules: inout [RouteRule]) {
        for i in rules.indices {
            if rules[i].outbound == "block" {
                rules[i].outbound = nil
                rules[i].action = "reject"
            }
        }
    }

    private func singboxBlockOutboundRemoved() -> Bool {
        guard let version = SingboxVersion(getSingboxVersion()) else {
            return true
        }
        return version >= SingboxVersion(1, 13, 0)
    }

    private func singboxSupportsSniffRuleAction() -> Bool {
        guard let version = SingboxVersion(getSingboxVersion()) else {
            return true
        }
        return version >= SingboxVersion(1, 11, 0)
    }

    private func singboxGeositeRemoved() -> Bool {
        guard let version = SingboxVersion(getSingboxVersion()) else {
            return true
        }
        return version >= SingboxVersion(1, 12, 0)
    }

    private func singboxSupportsRuleSet() -> Bool {
        guard let version = SingboxVersion(getSingboxVersion()) else {
            return true
        }
        return version >= SingboxVersion(1, 8, 0)
    }

    private func singboxSupportsNewDnsFormat() -> Bool {
        guard let version = SingboxVersion(getSingboxVersion()) else {
            return true
        }
        return version >= SingboxVersion(1, 12, 0)
    }

    private func getDnsConfig() -> DNSConfig {
        let jsonStr = getDefaultSingboxDnsSetting()
        guard let data = jsonStr.data(using: .utf8) else {
            return defaultDnsConfig()
        }
        do {
            var config = try JSONDecoder().decode(DNSConfig.self, from: data)
            if config.strategy == nil {
                config.strategy = "prefer_ipv4"
            }
            if singboxSupportsNewDnsFormat() {
                config = migratingDnsServerIfNeeded(config)
            } else {
                config = migratingDnsServerToOldFormat(config)
            }
            return config
        } catch {
            logger.error("Failed to parse sing-box DNS config: \(error)")
            return defaultDnsConfig()
        }
    }

    private func defaultDnsConfig() -> DNSConfig {
        if singboxSupportsNewDnsFormat() {
            return DNSConfig(
                servers: [
                    DNSServer(tag: "local-dns", type: "udp", server: defaultBootstrapDns),
                    DNSServer(tag: "direct-dns", type: "udp", server: defaultBootstrapDns),
                    DNSServer(tag: "remote-dns", type: "https", server: "cloudflare-dns.com", domain_resolver: "local-dns", path: "/dns-query", detour: "proxy"),
                ],
                rules: [
                    DNSRule(server: "local-dns", domain: ["localhost", "local"]),
                ],
                final: "remote-dns",
                strategy: "prefer_ipv4"
            )
        }

        if let data = defaultSingboxDns.data(using: .utf8),
           let config = try? JSONDecoder().decode(DNSConfig.self, from: data) {
            return config
        }

        return DNSConfig(
            servers: [
                DNSServer(tag: "local-dns", address: "udp://\(defaultBootstrapDns)"),
                DNSServer(tag: "direct-dns", address: "udp://\(defaultBootstrapDns)"),
            ],
            rules: [],
            final: "local-dns"
        )
    }

    private func migratingDnsServerIfNeeded(_ config: DNSConfig) -> DNSConfig {
        var config = config
        for i in config.servers.indices {
            let server = config.servers[i]
            guard let address = server.address, server.type == nil else { continue }
            if address == "local" {
                config.servers[i].type = "local"
            } else if address == "fakeip" {
                config.servers[i].type = "fakeip"
            } else if address.hasPrefix("dhcp://") {
                config.servers[i].type = "dhcp"
                let iface = String(address.dropFirst("dhcp://".count))
                if iface != "auto" {
                    config.servers[i].interface = iface.isEmpty ? nil : iface
                }
            } else if let url = URL(string: address), let scheme = url.scheme {
                guard let host = url.host, !host.isEmpty else { continue }
                switch scheme {
                case "udp", "tcp", "tls", "quic":
                    config.servers[i].type = scheme
                    if let port = url.port {
                        config.servers[i].server = "\(host):\(port)"
                    } else {
                        config.servers[i].server = host
                    }
                case "https":
                    config.servers[i].type = "https"
                    config.servers[i].server = host
                    config.servers[i].path = url.path.isEmpty || url.path == "/" ? nil : url.path
                case "h3":
                    config.servers[i].type = "h3"
                    config.servers[i].server = host
                    config.servers[i].path = url.path.isEmpty || url.path == "/" ? nil : url.path
                default:
                    continue
                }
            } else {
                continue
            }
            config.servers[i].domain_resolver = server.address_resolver
            config.servers[i].address = nil
            config.servers[i].address_resolver = nil
        }
        return config
    }

    private func migratingDnsServerToOldFormat(_ config: DNSConfig) -> DNSConfig {
        var config = config
        for i in config.servers.indices {
            let server = config.servers[i]
            guard server.address == nil, let type = server.type, let srv = server.server else { continue }
            switch type {
            case "local":
                config.servers[i].address = "local"
            case "fakeip":
                config.servers[i].address = "fakeip"
            case "dhcp":
                let iface = server.interface ?? ""
                config.servers[i].address = iface.isEmpty ? "dhcp://auto" : "dhcp://\(iface)"
            case "udp", "tcp", "tls", "quic":
                config.servers[i].address = "\(type)://\(srv)"
            case "https":
                let path = server.path ?? "/dns-query"
                config.servers[i].address = "https://\(srv)\(path)"
            case "h3":
                let path = server.path ?? "/dns-query"
                config.servers[i].address = "h3://\(srv)\(path)"
            default:
                continue
            }
            config.servers[i].address_resolver = server.domain_resolver
            config.servers[i].type = nil
            config.servers[i].server = nil
            config.servers[i].path = nil
            config.servers[i].domain_resolver = nil
        }
        return config
    }

    private func dnsConfigWithProxyServerRules(outbounds: [SingboxOutbound]) -> DNSConfig {
        var config = getDnsConfig()

        if !config.servers.contains(where: { $0.tag == "direct-dns" }) {
            let directDnsServer: DNSServer
            if singboxSupportsNewDnsFormat() {
                directDnsServer = DNSServer(tag: "direct-dns", type: "udp", server: defaultBootstrapDns)
            } else {
                directDnsServer = DNSServer(tag: "direct-dns", address: "udp://\(defaultBootstrapDns)")
            }
            config.servers.insert(directDnsServer, at: 0)
        }

        let domains = proxyServerDomains(from: outbounds)
        guard !domains.isEmpty else { return config }

        let dnsTag = config.servers.contains { $0.tag == "direct-dns" } ? "direct-dns" :
            (config.servers.contains { $0.tag == "local-dns" } ? "local-dns" : "direct-dns")

        for domain in domains.reversed() {
            let exists = config.rules.contains { $0.server == dnsTag && $0.domain?.contains(domain) == true }
            if !exists {
                config.rules.insert(DNSRule(server: dnsTag, domain: [domain]), at: min(1, config.rules.count))
            }
        }

        return config
    }

    private func proxyServerDomains(from outbounds: [SingboxOutbound]) -> [String] {
        var domains: [String] = []
        for outbound in outbounds where outbound.tag == "proxy" || outbound.tag?.hasPrefix("combo-out-") == true {
            guard let server = outbound.server?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !server.isEmpty,
                  isDomain(str: server),
                  !isIPAddressLiteral(server),
                  !domains.contains(server) else {
                continue
            }
            domains.append(server)
        }
        return domains
    }

    private func applyLogConfig(level: V2rayLogLevel) {
        self.singbox.log.disabled = nil
        self.singbox.log.output = nil

        switch level {
        case .warning:
            self.singbox.log.level = "warn"
        case .none:
            self.singbox.log.disabled = true
            self.singbox.log.level = "info"
        default:
            self.singbox.log.level = level.rawValue
        }
    }
}
