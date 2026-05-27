//
//  SingBoxConfigHandler.swift
//  V2rayU
//
//  Created by yanue on 2026/1/7.
//

import Foundation

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
    var domain_resolver = "default-dns"
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
            let outbound = SingboxOutboundHandler(from: ProfileModel(from: item)).getOutbound()
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

            let routeOutbound: String
            if outboundTags.count == 1 {
                routeOutbound = outboundTags[0]
            } else {
                routeOutbound = "combo-selector-\(groupIndex)"
                outbounds.append(SingboxOutbound(
                    type: "selector",
                    tag: routeOutbound,
                    outbounds: outboundTags,
                    default: outboundTags.first
                ))
            }
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
        self.singbox.dns = getDnsConfig()
        self.singbox.route.rules = comboRules + RoutingManager().getSingboxRoutingRules()
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

        // TUN模式配置
        if enableTun {
            // tun模式下,是独立的LaunchDaemon,转发流量到socks(xray|sing-box)
            if self.singbox.log.disabled != true {
                self.singbox.log.level = "warn"
                self.singbox.log.output = tunLogFilePath
            }
            /**
             {
               "type": "tun",
               "tag": "tun-in",
               "address": ["10.0.0.1/30"],
               "auto_route": true,
               "strict_route": true,
               "mtu": 9000,
               "stack": "system",
               "sniff": true,
               "sniff_override_destination": true
             }
             */
            let tunAddr = UserDefaults.get(forKey: .tunAddress, defaultValue: "10.0.0.1/30")
            let tunMtu = UserDefaults.getInt(forKey: .tunMtu, defaultValue: 1500)
            let tunStack = UserDefaults.getEnum(forKey: .tunStack, type: TunStack.self, defaultValue: .system)
            let tunInbound = SingboxInbound(
                type: "tun",
                tag: "tun-in",
                address: [tunAddr],
                auto_route: true,
                strict_route: true,
                mtu: tunMtu,
                stack: tunStack.rawValue,
                sniff: true,
                sniff_override_destination: true // 很重要
            )
            inbounds.append(tunInbound)

            // TUN模式: outbound使用socks代理到本地
            let socksOutbound = SingboxOutbound(
                type: "socks",
                tag: "proxy",
                server: "127.0.0.1",
                server_port: Int(getEffectiveSocksProxyPort())
            )
            let directOutbound = SingboxOutbound(type: "direct", tag: "direct")

            self.singbox.outbounds = [socksOutbound, directOutbound]

            // DNS配置
            let dnsDefault = UserDefaults.get(forKey: .tunDnsDefault, defaultValue: defaultDomesticDns)
            let dnsChina = UserDefaults.get(forKey: .tunDnsChina, defaultValue: secondaryDomesticDns)
            let fakeipRange = UserDefaults.get(forKey: .tunFakeipRange, defaultValue: "198.18.0.0/15")
            self.singbox.dns.servers = [
                DNSServer(type: "udp", tag: "default-dns", server: dnsDefault),
                DNSServer(type: "udp", tag: "china-dns", server: dnsChina),
                DNSServer(type: "fakeip", tag: "fakedns", inet4_range: fakeipRange, inet6_range: "fc00::/18")
            ]
            self.singbox.dns.rules = [
                DNSRule(server: "china-dns", domain: ["geosite:cn"]),
                DNSRule(server: "fakedns", domain: ["geosite:geolocation-!cn"])
            ]

            // TUN模式路由配置 - 所有流量转发到SOCKS，由SOCKS端处理路由
            self.singbox.route = RouteConfig(
                auto_detect_interface: true,
                default_domain_resolver: "default-dns",
                rules: [
                    RouteRule(outbound: "direct", process_name: ["xray", "xray-64", "xray-arm64", "v2ray", "v2ray-core"]),
                ]
            )

            self.singbox.inbounds = inbounds
            return
        }

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
            self.singbox.dns.servers = [
                DNSServer(type: "udp", tag: "default-dns", server: defaultDomesticDns),
            ]
        } else {
            self.singbox.dns = getDnsConfig()
            self.singbox.route.rules = RoutingManager().getSingboxRoutingRules()
        }
        logger.debug("_outbounds: \(self.forPing) \(self.singbox.toJSON())")
    }

    private func getDnsConfig() -> DNSConfig {
        let jsonStr = UserDefaults.get(forKey: .dnsJsonSingbox, defaultValue: defaultSingboxDns)
        guard let data = jsonStr.data(using: .utf8) else {
            return defaultDnsConfig()
        }
        do {
            let config = try JSONDecoder().decode(DNSConfig.self, from: data)
            return config
        } catch {
            logger.error("Failed to parse sing-box DNS config: \(error)")
            return defaultDnsConfig()
        }
    }

    private func defaultDnsConfig() -> DNSConfig {
        DNSConfig(
            servers: [
                DNSServer(type: "udp", tag: "default-dns", server: defaultDomesticDns),
                DNSServer(type: "udp", tag: "china-dns", server: secondaryDomesticDns),
                DNSServer(type: "fakeip", tag: "fakedns", inet4_range: "198.18.0.0/15", inet6_range: "fc00::/18")
            ],
            rules: [
                DNSRule(server: "china-dns", domain: ["geosite:cn"]),
                DNSRule(server: "fakedns", domain: ["geosite:geolocation-!cn"])
            ]
        )
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
