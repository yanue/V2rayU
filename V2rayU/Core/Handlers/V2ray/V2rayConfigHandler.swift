//
//  V2rayConfigHandler.swift
//  V2rayU
//
//  Created by yanue on 2024/12/14.
//

import Foundation

let defaultDomesticDns = "119.29.29.29"
let secondaryDomesticDns = "223.5.5.5"

let defaultDns = """
{
    "servers": [
      {
        "address": "119.29.29.29",
        "domains": ["geosite:cn"]  
      },
      "119.29.29.29",
      "223.5.5.5",
      "1.1.1.1"
    ],
    "queryStrategy": "UseIPv4",
    "disableFallbackIfMatch": true
  }
"""

func getDefaultDnsSetting() -> String {
    let dnsJson = UserDefaults.get(forKey: .dnsServers, defaultValue: defaultDns)
    return isLegacyBuiltinDns(dnsJson) ? defaultDns : dnsJson
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

    for server in servers {
        if let server = server as? String {
            hasGoogle = hasGoogle || server == "8.8.8.8"
            hasCloudflare = hasCloudflare || server == "1.1.1.1"
        } else if let server = server as? [String: Any],
                  let address = server["address"] as? String,
                  let domains = server["domains"] as? [String] {
            hasTencentForCN = hasTencentForCN || (address == defaultDomesticDns && domains.contains("geosite:cn"))
        }
    }

    return servers.count == 3 && hasGoogle && hasCloudflare && hasTencentForCN
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
        self.forPing = true
        self.enableSocks = false
        self.httpPort = String(httpPort)
        let outbound = V2rayOutboundHandler(from: ProfileModel(from: item)).getOutbound()
        self.combine(_outbounds: [outbound])
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

        let useMixedInbound = self.enableMixedPort && !self.forPing && !self.enableTun
        // check same
        if !useMixedInbound && !self.forPing && self.httpPort == self.socksPort {
            self.httpPort = String((Int(self.socksPort) ?? 1080) + 1)
        }
        let httpInboundPort = useMixedInbound ? self.mixedPort : self.httpPort
        let socksInboundPort = useMixedInbound ? self.mixedPort : self.socksPort
        let inHttp = getInbound(protocol: .http, listen: self.httpHost, port: httpInboundPort , enableSniffing: self.enableSniffing, tag: "http-in")
        // inbounds
        var inbounds: [V2rayInbound] = [inHttp]
        // for ping just use http
        if !self.forPing {
            if self.enableTun {
                let inTun = getInbound(protocol: .tun, listen: "", port: "",enableSniffing: false)
                inbounds.append(inTun)
                let inApi = getInbound(protocol: .dokodemoDoor, listen: "127.0.0.1", port: coreApiPort, enableSniffing: false, tag: "metrics_in")
                inbounds.append(inApi)
            } else {
                let inSocks = getInbound(protocol: .socks, listen: self.socksHost, port: socksInboundPort , enableSniffing: self.enableSniffing, tag: "socks-in")
                inbounds.append(inSocks)
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
            outboundFreedom.settings = V2rayOutboundFreedom(domainStrategy: "UseIP")

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
        self.v2ray.dns = self.getDns() // dns：ping 配置也需要，避免默认海外 DNS 拖慢节点/测速域名解析
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
