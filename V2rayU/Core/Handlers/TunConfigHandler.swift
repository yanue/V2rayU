import Foundation

enum TunConfigHandler {
    /// 同步 DNS 解析域名到 IP，空则返回 nil
    static func resolveServerIp(from address: String) -> String? {
        guard !address.isEmpty else { return nil }
        var hints = addrinfo(
            ai_flags: AI_NUMERICHOST, // 先试是否为 IP
            ai_family: AF_UNSPEC,
            ai_socktype: SOCK_STREAM,
            ai_protocol: 0,
            ai_addrlen: 0,
            ai_canonname: nil,
            ai_addr: nil,
            ai_next: nil
        )
        // 如果是合法 IP，直接返回
        var res: UnsafeMutablePointer<addrinfo>?
        if getaddrinfo(address, nil, &hints, &res) == 0 {
            freeaddrinfo(res)
            return address
        }
        // 否则做 DNS 解析
        hints.ai_flags = 0
        guard getaddrinfo(address, nil, &hints, &res) == 0, let first = res else {
            freeaddrinfo(res)
            return nil
        }
        defer { freeaddrinfo(first) }
        var ip: String?
        for ptr in sequence(first: first, next: { $0.pointee.ai_next }) {
            guard let addr = ptr.pointee.ai_addr else { continue }
            if addr.pointee.sa_family == AF_INET {
                addr.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { sin in
                    var str = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
                    inet_ntop(AF_INET, &sin.pointee.sin_addr, &str, socklen_t(INET_ADDRSTRLEN))
                    ip = String(cString: str)
                }
                break
            } else if addr.pointee.sa_family == AF_INET6 {
                addr.withMemoryRebound(to: sockaddr_in6.self, capacity: 1) { sin6 in
                    var str = [CChar](repeating: 0, count: Int(INET6_ADDRSTRLEN))
                    inet_ntop(AF_INET6, &sin6.pointee.sin6_addr, &str, socklen_t(INET6_ADDRSTRLEN))
                    ip = String(cString: str)
                }
                break
            }
        }
        return ip
    }

    static func buildTunConfig() -> String {
        var singbox = SingboxStruct()

        let tunLevel = UserDefaults.getEnum(forKey: .tunLogLevel, type: V2rayLogLevel.self, defaultValue: .warning)
        switch tunLevel {
        case .none:
            singbox.log.disabled = true
        case .warning:
            singbox.log.disabled = nil
            singbox.log.level = "warn"
            singbox.log.output = tunLogFilePath
            singbox.log.timestamp = true
        default:
            singbox.log.disabled = nil
            singbox.log.level = tunLevel.rawValue
            singbox.log.output = tunLogFilePath
            singbox.log.timestamp = true
        }

        let tunAddr = UserDefaults.get(forKey: .tunAddress, defaultValue: "10.0.0.1/30")
        let tunMtu = UserDefaults.getInt(forKey: .tunMtu, defaultValue: 1500)
        let tunStack = UserDefaults.getEnum(forKey: .tunStack, type: TunStack.self, defaultValue: .system)
        let tunStrictRoute = UserDefaults.getBool(forKey: .tunStrictRoute, default: true)
        let tunEnableIPv6 = UserDefaults.getBool(forKey: .tunEnableIPv6, default: true)
        let useSniffRuleAction = SingboxVersionCheck.supportsSniffRuleAction()

        var addresses = [tunAddr]
        if tunEnableIPv6 {
            addresses.append("fd00::1/64")
        }
        let tunInbound = SingboxInbound(
            type: "tun",
            tag: "tun-in",
            address: addresses,
            auto_route: true,
            strict_route: tunStrictRoute,
            mtu: tunMtu,
            stack: tunStack.rawValue,
            sniff: useSniffRuleAction ? nil : true,
            sniff_override_destination: useSniffRuleAction ? nil : true
        )
        singbox.inbounds = [tunInbound]

        let socksOutbound = SingboxOutbound(
            type: "socks",
            tag: "proxy",
            server: "127.0.0.1",
            server_port: Int(getEffectiveSocksProxyPort())
        )
        let directOutbound = SingboxOutbound(type: "direct", tag: "direct")
        // sing-box < 1.13.0 需要 block outbound 来拒绝流量
        if !SingboxVersionCheck.blockOutboundRemoved() {
            let blockOutbound = SingboxOutbound(type: "block", tag: "block")
            singbox.outbounds = [socksOutbound, directOutbound, blockOutbound]
        } else {
            singbox.outbounds = [socksOutbound, directOutbound]
        }

        // DNS 分流: 国内域名走 local-dns, 海外域名走 remote-dns（通过代理）
        let dnsChina = UserDefaults.get(forKey: .tunDnsChina, defaultValue: defaultBootstrapDns)
        let dnsRemote = UserDefaults.get(forKey: .tunDnsRemote, defaultValue: "1.1.1.1")
        let useNewDns = SingboxVersionCheck.supportsNewDnsFormat()

        if useNewDns {
            let isIP = isIPAddressLiteral(dnsRemote)
            var remoteDns = DNSServer(tag: "remote-dns", type: "tcp", server: dnsRemote, detour: "proxy")
            if !isIP { remoteDns.domain_resolver = "local-dns" }
            singbox.dns = DNSConfig(
                servers: [
                    remoteDns,
                    DNSServer(tag: "local-dns", type: "udp", server: dnsChina),
                ],
                rules: [
                    DNSRule(server: "local-dns", geosite: ["cn"], strategy: "prefer_ipv4"),
                    DNSRule(server: "local-dns", domain: ["localhost", "local"]),
                ],
                final: "remote-dns",
                independent_cache: true,
                strategy: "prefer_ipv4"
            )
        } else {
            let isIP = isIPAddressLiteral(dnsRemote)
            var remoteDns = DNSServer(tag: "remote-dns", detour: "proxy", address: "tcp://\(dnsRemote)")
            if !isIP { remoteDns.address_resolver = "local-dns" }
            singbox.dns = DNSConfig(
                servers: [
                    remoteDns,
                    DNSServer(tag: "local-dns", address: "udp://\(dnsChina)"),
                ],
                rules: [
                    DNSRule(server: "local-dns", geosite: ["cn"]),
                    DNSRule(server: "local-dns", domain: ["localhost", "local"]),
                ],
                final: "remote-dns",
                independent_cache: true
            )
        }

        var tunRules: [RouteRule] = []
        if useSniffRuleAction {
            tunRules.append(RouteRule(action: "sniff"))
        }
        // 代理核心（xray/sing-box）直连，避免回路
        tunRules.append(RouteRule(outbound: "direct", process_name: ["xray", "xray-64", "xray-arm64", "v2ray", "v2ray-core", "sing-box", "sing-box-arm64", "sing-box-64"]))
        // 其余全部走 SOCKS（默认第一条出站就是 proxy）
        singbox.route = RouteConfig(
            auto_detect_interface: true,
            default_domain_resolver: "local-dns",
            rules: tunRules
        )

        // 将 geosite/geoip 规则转为 rule_set 引用（附带 .srs 文件注册）
        singbox.applyBundledRuleSets()

        return singbox.toJSON()
    }
}
