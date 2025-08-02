//
//  V2rayConfigHandler.swift
//  V2rayU
//
//  Created by yanue on 2024/12/14.
//

import Foundation

let defaultDns = """
{
    "servers": [
      "8.8.8.8",
      "1.1.1.1",
      {
        "address": "119.29.29.29",
        "domains": ["geosite:cn"]  
      }
    ],
    "queryStrategy": "UseIPv4"
  }
"""

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
    var mux = 8
    var forPing = false

    // Initialization
    init() {
        self.enableMux = UserDefaults.getBool(forKey: .enableMux)
        self.enableUdp = UserDefaults.getBool(forKey: .enableUdp)
        self.enableSniffing = UserDefaults.getBool(forKey: .enableSniffing)

        self.httpPort = String(getHttpProxyPort())
        self.socksPort = String(getSocksProxyPort())

        self.mux = UserDefaults.getInt(forKey: .muxConcurrent ,defaultValue: 8)

        self.logLevel = UserDefaults.getEnum(forKey: .v2rayLogLevel, type: V2rayLogLevel.self, defaultValue: .info)
    }

    // ping配置
    func toJSON(item: ProfileModel, httpPort: String) -> String {
        self.forPing = true
        self.enableSocks = false
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
        if !self.forPing {
            self.v2ray.log.access = v2rayLogFilePath
            self.v2ray.log.error = v2rayLogFilePath
        }
        // ------------------------------------- inbound start ---------------------------------------------

        // check same
        if self.httpPort == self.socksPort {
            self.httpPort = String((Int(self.socksPort) ?? 1080) + 1)
        }
        let inHttp = getInbound(protocol: .http, listen: self.httpHost, port: self.httpPort , enableSniffing: self.enableSniffing)
        // inbounds
        var inbounds: [V2rayInbound] = [inHttp]
        // for ping just use http
        if !self.forPing {
            let inSocks = getInbound(protocol: .socks, listen: self.socksHost, port: self.socksPort , enableSniffing: self.enableSniffing)
            inbounds.append(inSocks)
            let inApi = getInbound(protocol: .dokodemoDoor, listen: "127.0.0.1", port: "11111", enableSniffing: false, tag: "metrics_in")
            inbounds.append(inApi)
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
            outboundFreedom.settings = V2rayOutboundFreedom()

            // outbound Blackhole
            let outboundBlackhole = V2rayOutbound()
            outboundBlackhole.protocol = .blackhole
            outboundBlackhole.tag = "block"
            outboundBlackhole.settings = V2rayOutboundBlackhole()
            
            // outbound Dns
            let outboundDns = V2rayOutbound()
            outboundBlackhole.protocol = .dns
            outboundBlackhole.tag = "dns_out"
            outboundBlackhole.settings = V2rayOutboundDns()
            
            // 添加
            outbounds.append(outboundFreedom)
            outbounds.append(outboundBlackhole)
            outbounds.append(outboundDns)
        }

        self.v2ray.outbounds = outbounds
        // ------------------------------------- routing start --------------------------------------------
        if !self.forPing {
            self.v2ray.routing = RoutingManager().getRunning() // 路由
            self.v2ray.stats = V2rayStats() // 开启统计
            self.v2ray.metrics = v2rayMetrics() // 启用 metrics,用于请求统计数据
            self.v2ray.policy = V2rayPolicy() // 统计规则
            self.v2ray.observatory = V2rayObservatory() // 观察者
            self.v2ray.dns = self.getDns() // dns
        }
        // ------------------------------------- routing end ----------------------------------------------
    }
    
    func getDns() -> V2rayDns {
        let dnsJson = UserDefaults.get(forKey: .dnsServers, defaultValue: defaultDns)
        if let jsonData = dnsJson.data(using: .utf8) {
            do {
                let decoder = JSONDecoder()
                let dns = try decoder.decode(V2rayDns.self, from: jsonData)
                return dns
            } catch {
                print("解析 JSON 失败: \(error)")
            }
        }
        return V2rayDns()
    }
    
    func getInbound(`protocol`: V2rayProtocolInbound, listen: String, port: String, enableSniffing:Bool, tag: String? = nil) -> V2rayInbound {
        var inbound = V2rayInbound()
        inbound.tag = tag
        inbound.listen = listen
        inbound.port = port
        inbound.protocol = `protocol`
        if enableSniffing {
            inbound.sniffing = V2rayInboundSniffing()
        }
        return inbound
    }
}
