//
//  V2rayConfigHandler.swift
//  V2rayU
//
//  Created by yanue on 2024/12/14.
//

import Foundation

class V2rayConfigHandler {
    var v2ray: V2rayStruct = V2rayStruct()
    var isValid = false

    var error = ""
    var errors: [String] = []

    // base
    var logLevel = "info"
    var socksPort = "1080"
    var socksHost = "127.0.0.1"
    var httpPort = "1087"
    var httpHost = "127.0.0.1"
    var enableSocks = true
    var enableUdp = false
    var enableMux = false
    var enableSniffing = false
    var mux = 8
    var dnsJson = UserDefaults.get(forKey: .v2rayDnsJson) ?? ""
    var forPing = false

    // Initialization
    init() {
        self.enableMux = UserDefaults.getBool(forKey: .enableMux)
        self.enableUdp = UserDefaults.getBool(forKey: .enableUdp)
        self.enableSniffing = UserDefaults.getBool(forKey: .enableSniffing)

        self.httpPort = UserDefaults.get(forKey: .localHttpPort,defaultValue: "1087") ?? "1087"
        self.httpHost = UserDefaults.get(forKey: .localHttpHost) ?? "127.0.0.1"
        self.socksPort = UserDefaults.get(forKey: .localSockPort) ?? "1080"
        self.socksHost = UserDefaults.get(forKey: .localSockHost) ?? "127.0.0.1"

        self.mux = Int(UserDefaults.get(forKey: .muxConcurrent) ?? "8") ?? 8

        self.logLevel = UserDefaults.get(forKey: .v2rayLogLevel) ?? "info"
    }

    // ping配置
    func toJSON(item: ProfileModel,ping: Bool) -> String {
        if ping {
            self.forPing = true
            self.enableSocks = false
        }
        self.httpPort = String(httpPort)
        let outbound = V2rayOutboundHandler(from: item).getOutbound()
        self.combine(_outbounds: [outbound])
        return self.v2ray.toJSON()
    }

    // 单个配置
    func toJSON(item: ProfileModel) -> String {
        let outbound = V2rayOutboundHandler(from: item).getOutbound()
        self.combine(_outbounds: [outbound])
        return self.v2ray.toJSON()
    }

    // 组合配置
    func toJSON(items: [ProfileModel]) -> String {
        var _outbounds: [V2rayOutbound] = []
        for (_, item) in items.enumerated() {
            let outbound = V2rayOutboundHandler(from: item).getOutbound()
            _outbounds.append(outbound)
        }
        self.combine(_outbounds: _outbounds)
        return self.v2ray.toJSON()
    }

    func combine(_outbounds: [V2rayOutbound]) {
        // base
        self.v2ray.log.loglevel = V2rayLogLevel(rawValue: UserDefaults.get(forKey: .v2rayLogLevel)) ?? V2rayLogLevel.info

        // ------------------------------------- inbound start ---------------------------------------------
        var inSocks = V2rayInbound()
        inSocks.port = self.socksPort
        inSocks.listen = self.socksHost
        inSocks.protocol = V2rayProtocolInbound.socks
        inSocks.settingSocks.udp = self.enableUdp
        if self.enableSniffing {
            inSocks.sniffing = V2rayInboundSniffing()
        }

        // check same
        if self.httpPort == self.socksPort {
            self.httpPort = String((Int(self.socksPort) ?? 1080) + 1)
        }
        var inHttp = V2rayInbound()
        inHttp.port = self.httpPort
        inHttp.listen = self.httpHost
        inHttp.protocol = V2rayProtocolInbound.http
        if self.enableSniffing {
            inHttp.sniffing = V2rayInboundSniffing()
        }

        // inbounds
        var inbounds: [V2rayInbound] = []
        // for ping just use http
        if self.enableSocks {
            inbounds.append(inSocks)
        }
        inbounds.append(inHttp)
        self.v2ray.inbounds = inbounds

        // ------------------------------------- inbound end ----------------------------------------------
        // outbound Freedom
        let outboundFreedom = V2rayOutbound()
        outboundFreedom.protocol = V2rayProtocolOutbound.freedom
        outboundFreedom.tag = "direct"
        outboundFreedom.settings = V2rayOutboundFreedom()

        // outbound Blackhole
        let outboundBlackhole = V2rayOutbound()
        outboundBlackhole.protocol = V2rayProtocolOutbound.blackhole
        outboundBlackhole.tag = "block"
        outboundBlackhole.settings = V2rayOutboundBlackhole()
        
        // outbounds
        var outbounds: [V2rayOutbound] = []
        outbounds.append(contentsOf: _outbounds)
        outbounds.append(outboundFreedom)
        outbounds.append(outboundBlackhole)

        self.v2ray.outbounds = outbounds
        // ------------------------------------- routing start --------------------------------------------
        if !self.forPing {
            self.v2ray.routing = RoutingManager().getRunning()
        }
        // ------------------------------------- routing end ----------------------------------------------
    }
}
