import Foundation

enum TunConfigHandler {
    private enum IPAddressKind {
        case ipv4
        case ipv6

        var routePrefix: Int {
            switch self {
            case .ipv4: return 32
            case .ipv6: return 128
            }
        }

        var maximumPrefix: Int { routePrefix }
    }

    static func resolveRouteExcludeAddresses(from rawValue: String) -> [String] {
        resolveRouteExcludeAddresses(from: rawValue, resolver: resolveServerIps)
    }

    static func resolveRouteExcludeAddresses(
        from rawValue: String,
        resolver: (String) -> [String]
    ) -> [String] {
        let separators = CharacterSet.whitespacesAndNewlines
            .union(CharacterSet(charactersIn: ",;"))
        let entries = rawValue.components(separatedBy: separators).filter { !$0.isEmpty }

        var result: [String] = []
        var seen = Set<String>()

        func append(_ address: String) {
            guard let normalized = normalizeRouteAddress(address), seen.insert(normalized).inserted else {
                return
            }
            result.append(normalized)
        }

        for entry in entries {
            if entry.contains("/") || normalizedIPAddress(entry) != nil {
                append(entry)
                continue
            }
            // getaddrinfo also accepts legacy numeric forms that sing-box rejects.
            guard !isNonCanonicalNumericAddress(entry) else { continue }
            resolver(entry).forEach(append)
        }

        return result
    }

    private static func normalizeRouteAddress(_ address: String) -> String? {
        let parts = address.split(separator: "/", omittingEmptySubsequences: false)
        guard parts.count == 1 || parts.count == 2 else { return nil }

        let host = String(parts[0])
        guard let normalizedIP = normalizedIPAddress(host) else { return nil }

        if parts.count == 2 {
            guard let prefix = Int(parts[1]), (0 ... normalizedIP.kind.maximumPrefix).contains(prefix) else {
                return nil
            }
            return "\(normalizedIP.address)/\(prefix)"
        }
        return "\(normalizedIP.address)/\(normalizedIP.kind.routePrefix)"
    }

    private static func normalizedIPAddress(_ address: String) -> (address: String, kind: IPAddressKind)? {
        guard !address.contains("%") else { return nil }

        var ipv4 = in_addr()
        let ipv4Status = address.withCString { inet_pton(AF_INET, $0, &ipv4) }
        if ipv4Status == 1 {
            var buffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
            guard inet_ntop(AF_INET, &ipv4, &buffer, socklen_t(INET_ADDRSTRLEN)) != nil else {
                return nil
            }
            return (string(from: buffer), .ipv4)
        }

        var ipv6 = in6_addr()
        let ipv6Status = address.withCString { inet_pton(AF_INET6, $0, &ipv6) }
        if ipv6Status == 1 {
            var buffer = [CChar](repeating: 0, count: Int(INET6_ADDRSTRLEN))
            guard inet_ntop(AF_INET6, &ipv6, &buffer, socklen_t(INET6_ADDRSTRLEN)) != nil else {
                return nil
            }
            return (string(from: buffer), .ipv6)
        }

        return nil
    }

    private static func isNonCanonicalNumericAddress(_ address: String) -> Bool {
        var hints = addrinfo(
            ai_flags: AI_NUMERICHOST,
            ai_family: AF_UNSPEC,
            ai_socktype: SOCK_STREAM,
            ai_protocol: 0,
            ai_addrlen: 0,
            ai_canonname: nil,
            ai_addr: nil,
            ai_next: nil
        )
        var result: UnsafeMutablePointer<addrinfo>?
        let status = getaddrinfo(address, nil, &hints, &result)
        if let result { freeaddrinfo(result) }
        return status == 0
    }

    private static func string(from buffer: [CChar]) -> String {
        String(decoding: buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }

    private static func resolveServerIps(from address: String) -> [String] {
        guard !address.isEmpty else { return [] }
        var hints = addrinfo(
            ai_flags: 0,
            ai_family: AF_UNSPEC,
            ai_socktype: SOCK_STREAM,
            ai_protocol: 0,
            ai_addrlen: 0,
            ai_canonname: nil,
            ai_addr: nil,
            ai_next: nil
        )
        var result: UnsafeMutablePointer<addrinfo>?
        guard getaddrinfo(address, nil, &hints, &result) == 0, let first = result else {
            if let result { freeaddrinfo(result) }
            return []
        }
        defer { freeaddrinfo(first) }

        var addresses: [String] = []
        var seen = Set<String>()
        for ptr in sequence(first: first, next: { $0.pointee.ai_next }) {
            guard let addr = ptr.pointee.ai_addr else { continue }
            var ip: String?
            if addr.pointee.sa_family == AF_INET {
                addr.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { sin in
                    var str = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
                    inet_ntop(AF_INET, &sin.pointee.sin_addr, &str, socklen_t(INET_ADDRSTRLEN))
                    ip = string(from: str)
                }
            } else if addr.pointee.sa_family == AF_INET6 {
                addr.withMemoryRebound(to: sockaddr_in6.self, capacity: 1) { sin6 in
                    var str = [CChar](repeating: 0, count: Int(INET6_ADDRSTRLEN))
                    inet_ntop(AF_INET6, &sin6.pointee.sin6_addr, &str, socklen_t(INET6_ADDRSTRLEN))
                    ip = string(from: str)
                }
            }
            if let ip, seen.insert(ip).inserted {
                addresses.append(ip)
            }
        }
        return addresses
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
        let tunRouteExcludeHosts = UserDefaults.get(forKey: .tunRouteExcludeHosts)
        let routeExcludeAddresses = resolveRouteExcludeAddresses(from: tunRouteExcludeHosts)
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
            route_exclude_address: routeExcludeAddresses.isEmpty ? nil : routeExcludeAddresses,
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
