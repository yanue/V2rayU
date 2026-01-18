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
    var enableTun = false
    var forPing = false
    var domain_resolver = "default-dns"
    var logLevel: V2rayLogLevel = .info

    init(enableTun: Bool = false) {
        self.enableTun = enableTun
        self.httpPort = String(getHttpProxyPort())
        self.socksPort = String(getSocksProxyPort())
        self.logLevel = UserDefaults.getEnum(forKey: .v2rayLogLevel, type: V2rayLogLevel.self, defaultValue: .info)
    }
    
    // ping配置
    func toJSON(item: ProfileEntity, httpPort: String) -> String {
        self.forPing = true
        self.httpPort = httpPort
        var outbound = SingboxOutboundHandler(from: ProfileModel(from: item)).getOutbound()
        outbound.domain_resolver = domain_resolver
        // outbound Freedom
        let outboundDirect = SingboxOutbound(type: "direct", tag: "direct")
        // outbound Blackhole
        let outboundBlock = SingboxOutbound(type: "block", tag: "block")
        self.combine(_outbounds: [outbound, outboundDirect, outboundBlock])
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
    
    func combine(_outbounds: [SingboxOutbound]) {
        // base
        self.singbox.log.level = (V2rayLogLevel(rawValue: UserDefaults.get(forKey: .v2rayLogLevel)) ?? V2rayLogLevel.info).rawValue
        if !self.forPing {
            self.singbox.log.output = coreLogFilePath
        }
        var inbounds: [SingboxInbound] = []
        // 默认 inbound: tun
        if enableTun {
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
            let tunInbound = SingboxInbound(
                type: "tun",
                tag: "tun-in",
                address: ["10.0.0.1/30"],
                auto_route: true,
                strict_route: true,
                mtu: 1500,
                stack: "system", // system 需要 root 权限
                sniff: true,
                sniff_override_destination: true // 很重要
            )
            inbounds.append(tunInbound)
        } else {
            // 避免 httpPort 与 socksPort 冲突
            if self.httpPort == self.socksPort {
                self.httpPort = String((Int(self.socksPort) ?? 1080) + 1)
            }
            
            let httpInbound = SingboxInbound(
                type: "http",
                tag: "http-in",
                listen: self.httpHost,
                listen_port: Int(self.httpPort),
            )
            inbounds.append(httpInbound)

            if !self.forPing {
                let socksInbound = SingboxInbound(
                    type: "socks",
                    tag: "socks-in",
                    listen: self.socksHost,
                    listen_port: Int(self.socksPort),
                )
                inbounds.append(socksInbound)
            }
        }

        if !self.forPing {
            let clashConfig = ExperimentalConfig(
                clash_api: ClashAPIConfig(
                    external_controller: "127.0.0.1:11111",
                    secret: ""
                )
            )

            singbox.experimental = clashConfig
        }
        
        self.singbox.inbounds = inbounds
    
        self.singbox.outbounds = _outbounds
        
        if self.forPing {
            // 默认 DNS
            self.singbox.dns.servers = [
                DNSServer(type: "udp", tag: "default-dns", server: "1.1.1.1"),
            ]
        } else {
            // dns
            self.singbox.dns.servers = [
                DNSServer(type: "udp", tag: "default-dns", server: "1.1.1.1"),
                DNSServer(type: "udp", tag: "china-dns", server: "119.29.29.29"),
                DNSServer(type: "fakeip", tag: "fakedns", inet4_range: "198.18.0.0/15", inet6_range: "fc00::/18")
            ]
            self.singbox.dns.rules = [
                DNSRule(server: "china-dns", domain: ["geosite:cn"]),
                DNSRule(server: "fakedns", domain: ["geosite:geolocation-!cn"])
            ]
            // 默认路由
            self.singbox.route.rules = [
                RouteRule(
                    outbound: "direct",
                    domain: ["geosite:cn", "localhost", "127.0.0.1", "::1"]
                ),
                RouteRule(
                    outbound: "direct",
                    domain: ["geosite:private"] // 可选：内网域名直连
                ),
                RouteRule(
                    outbound: "proxy",
                    domain: ["geosite:geolocation-!cn"]
                )
            ]
        }
        logger.debug("_outbounds: \(self.forPing) \(self.singbox.toJSON())")
    }
}
