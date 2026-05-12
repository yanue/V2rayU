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
            
            // TUN模式: outbound使用socks代理到本地
            let socksOutbound = SingboxOutbound(
                type: "socks",
                tag: "proxy",
                server: "127.0.0.1",
                server_port: Int(getSocksProxyPort())
            )
            let directOutbound = SingboxOutbound(type: "direct", tag: "direct")

            self.singbox.outbounds = [socksOutbound, directOutbound]
            
            // DNS配置
            self.singbox.dns.servers = [
                DNSServer(type: "udp", tag: "default-dns", server: "1.1.1.1"),
                DNSServer(type: "udp", tag: "china-dns", server: "119.29.29.29"),
                DNSServer(type: "fakeip", tag: "fakedns", inet4_range: "198.18.0.0/15", inet6_range: "fc00::/18")
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
            // 路由配置
            self.singbox.route.rules = RoutingManager().getSingboxRoutingRules()
        }
        logger.debug("_outbounds: \(self.forPing) \(self.singbox.toJSON())")
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
