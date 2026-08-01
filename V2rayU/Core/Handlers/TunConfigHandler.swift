import Foundation

/// TUN 配置生成器。
///
/// ## 流量路径
///
/// ```
/// 应用 → TUN → 路由分流
///              ├─ process_name (xray/sing-box) → direct（绕过 TUN）
///              ├─ hijack-dns → DNS 分流（代理域名/cn → 直连，其他 → 代理）
///              ├─ sniff → 协议检测（提取 SNI/Host，使域名路由生效）
///              └─ default → SOCKS proxy
/// ```
///
/// ## DNS 死锁防护
///
/// 代理核心（xray）用域名连远端时需要 DNS。若 DNS 被 hijack-dns 劫持走代理
/// （remote-dns），而 xray 就是那个代理 → 循环死锁。
///
/// 防护（包级为主，不依赖 macOS 上不可靠的 process_name 匹配）：
/// 1. route_exclude_address 自动排除代理服务器 IP + bootstrap DNS IP
///    （xray 的 DNS 查询与到服务器的数据连接都在路由表层面绕过 TUN，从根上避免死锁）
/// 2. route.process_name → direct（核心进程直连，兜底）
/// 3. DNS.proxyServerDomains → local-dns 直连（兜底）
/// 4. 系统 DNS 1.1.1.1（绕过 TUN 的流量）
enum TunConfigHandler {
    /// 核心进程名（xray/sing-box），始终走 direct 出站。
    /// 这些进程的流量必须绕过 TUN，否则其 DNS 查询会被 hijack-dns 劫持形成死锁。
    private static let coreDirectProcessNames = [
        "xray", "xray-64", "xray-arm64",
        "v2ray", "v2ray-core",
        "sing-box", "sing-box-arm64", "sing-box-64",
    ]

    // MARK: - Address defaults

    static let defaultTunAddress = "172.19.0.1/30"
    static let defaultTunIPv6 = "fdfe:dcba:9876::1/126"

    // MARK: - Legacy default migration

    /// Check for old default TUN addresses and replace with safe defaults.
    /// Returns true if any address was migrated.
    static func migrateLegacyDefaults() -> Bool {
        var migrated = false

        // IPv4: old default 10.0.0.1/30 → new default 172.19.0.1/30
        let ipv4 = UserDefaults.get(forKey: .tunAddress, defaultValue: defaultTunAddress)
        if ipv4 == "10.0.0.1/30" {
            UserDefaults.set(forKey: .tunAddress, value: defaultTunAddress)
            migrated = true
        }

        // IPv6: old default fd00::1/64 → new default fdfe:dcba:9876::1/126
        let ipv6 = UserDefaults.get(forKey: .tunAddressIPv6, defaultValue: defaultTunIPv6)
        if ipv6 == "fd00::1/64" {
            UserDefaults.set(forKey: .tunAddressIPv6, value: defaultTunIPv6)
            migrated = true
        }

        return migrated
    }

    // MARK: - Existing helpers

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

    static func parseProcessNames(_ rawValue: String) -> [String] {
        let separators = CharacterSet.newlines.union(CharacterSet(charactersIn: ",;"))
        var processNames: [String] = []
        var seen = Set<String>()

        for entry in rawValue.components(separatedBy: separators) {
            let processName = entry.trimmingCharacters(in: .whitespaces)
            guard !processName.isEmpty, seen.insert(processName).inserted else { continue }
            processNames.append(processName)
        }

        return processNames
    }

    static func normalizeApplicationPaths(_ paths: [String]) -> [String] {
        var normalizedPaths: [String] = []
        var seen = Set<String>()

        for path in paths where !path.isEmpty {
            let normalizedPath = URL(fileURLWithPath: path).standardizedFileURL.path
            guard normalizedPath.hasPrefix("/"), seen.insert(normalizedPath).inserted else { continue }
            normalizedPaths.append(normalizedPath)
        }

        return normalizedPaths
    }

    static func applicationProcessPathRegex(for path: String) -> String {
        "^\(NSRegularExpression.escapedPattern(for: path))/"
    }

    /// 构建进程级路由规则。
    ///
    /// 规则顺序：
    ///   1. coreDirectProcessNames → direct（核心进程始终直连，防 DNS 死锁）
    ///   2. directApplicationPaths → direct（用户指定直连的应用路径）
    ///   3. directProcessNames → direct（用户指定直连的进程名）
    ///   4. proxyApplicationPaths → proxy（用户指定走代理的应用路径）
    ///   5. proxyProcessNames → proxy（用户指定走代理的进程名）
    ///
    /// 注意：coreDirectProcessNames 会自动排除用户在 direct 列表中重复配置的进程名。
    static func buildProcessRouteRules(
        directRawValue: String,
        proxyRawValue: String,
        directApplicationPaths: [String] = [],
        proxyApplicationPaths: [String] = []
    ) -> [RouteRule] {
        let coreProcessKeys = Set(coreDirectProcessNames)
        let directProcessNames = parseProcessNames(directRawValue).filter {
            !coreProcessKeys.contains($0)
        }
        let directProcessKeys = Set(directProcessNames)
        let proxyProcessNames = parseProcessNames(proxyRawValue).filter {
            !coreProcessKeys.contains($0) && !directProcessKeys.contains($0)
        }

        let normalizedDirectApplicationPaths = normalizeApplicationPaths(directApplicationPaths)
        let directApplicationPathKeys = Set(normalizedDirectApplicationPaths)
        let normalizedProxyApplicationPaths = normalizeApplicationPaths(proxyApplicationPaths).filter {
            !directApplicationPathKeys.contains($0)
        }

        var rules = [RouteRule(outbound: "direct", process_name: coreDirectProcessNames)]
        if !normalizedDirectApplicationPaths.isEmpty {
            rules.append(RouteRule(
                outbound: "direct",
                process_path_regex: normalizedDirectApplicationPaths.map(applicationProcessPathRegex)
            ))
        }
        if !directProcessNames.isEmpty {
            rules.append(RouteRule(outbound: "direct", process_name: directProcessNames))
        }
        if !normalizedProxyApplicationPaths.isEmpty {
            rules.append(RouteRule(
                outbound: "proxy",
                process_path_regex: normalizedProxyApplicationPaths.map(applicationProcessPathRegex)
            ))
        }
        if !proxyProcessNames.isEmpty {
            rules.append(RouteRule(outbound: "proxy", process_name: proxyProcessNames))
        }
        return rules
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

    /// 收集所有 profile 的代理服务器域名（排除 IP 地址），用于 TUN DNS 分流。
    ///
    /// 这些域名会被添加到 DNS 规则中，优先走 local-dns（直连解析），
    /// 确保代理核心的 DNS 查询不被 hijack-dns 劫持走 remote-dns（通过代理），避免循环死锁。
    ///
    /// 规则顺序：proxyServerDomains > geosite:cn > localhost > final:remote-dns
    static func proxyServerDomains() -> [String] {
        let profiles = ProfileStore.shared.fetchAll()
        var domains: [String] = []
        var seen = Set<String>()
        for profile in profiles {
            let server = profile.address.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !server.isEmpty,
                  !isIPAddressLiteral(server),
                  seen.insert(server).inserted else { continue }
            domains.append(server)
        }
        return domains
    }

    /// 收集所有 profile 的代理服务器 IP，用于 TUN route_exclude_address。
    ///
    /// 包级死锁防护：xray 连远端的数据连接若被 TUN 劫持并路由回 SOCKS（xray 自己），
    /// 会无限循环。把代理服务器 IP 从 TUN 的路由表排除后，xray 的数据连接在
    /// 包级绕过 TUN（不依赖 process_name 匹配），从根上打破数据死锁。
    ///
    /// 优先级：
    ///   1. IP 字面量地址直接使用
    ///   2. 优先使用 ping 检测缓存的 serverIp（已解析的稳定结果）
    ///   3. 域名实时解析：当前运行的 profile 必解析；其余唯一域名最多解析
    ///      `maxDomainResolutions` 个，避免大量订阅 profile 拖慢 TUN 启动。
    static func proxyServerIpAddresses(maxDomainResolutions: Int = 32) -> [String] {
        proxyServerIpAddresses(maxDomainResolutions: maxDomainResolutions, resolver: resolveServerIps)
    }

    static func proxyServerIpAddresses(maxDomainResolutions: Int, resolver: (String) -> [String]) -> [String] {
        let profiles = ProfileStore.shared.fetchAll()
        let runningAddress = ProfileStore.shared.getRunning()?.address
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        var addresses: [String] = []
        var seen = Set<String>()
        var domainsToResolve: [String] = []
        var seenDomains = Set<String>()

        func append(_ address: String) {
            guard let normalized = normalizeRouteAddress(address), seen.insert(normalized).inserted else { return }
            addresses.append(normalized)
        }

        for profile in profiles {
            let server = profile.address.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !server.isEmpty else { continue }
            if isIPAddressLiteral(server) {
                append(server)
            } else if !profile.serverIp.isEmpty {
                append(profile.serverIp)
            } else if seenDomains.insert(server).inserted {
                domainsToResolve.append(server)
            }
        }

        // 当前运行的 profile 域名必解析，排在其余域名之前
        domainsToResolve.sort { $0 == runningAddress && $1 != runningAddress }
        let resolvedCount = min(domainsToResolve.count, maxDomainResolutions)
        for domain in domainsToResolve[..<resolvedCount] {
            resolver(domain).forEach(append)
        }
        return addresses
    }

    /// 合并 TUN 的 route_exclude_address：
    /// 用户手动配置的 host + 自动排除的代理服务器 IP + bootstrap DNS IP。
    /// 自动排除项让 xray 的 DNS 查询与到服务器的数据连接都在路由表层面绕过 TUN，
    /// 避免 tun+xray 死锁，无需用户手动维护 IP 列表。
    static func mergedRouteExcludeAddresses(userConfigured: [String]) -> [String] {
        var addresses: [String] = []
        var seen = Set<String>()

        func append(_ address: String) {
            guard let normalized = normalizeRouteAddress(address), seen.insert(normalized).inserted else { return }
            addresses.append(normalized)
        }

        userConfigured.forEach(append)
        proxyServerIpAddresses().forEach(append)

        // bootstrap DNS IP：xray 用它解析代理服务器域名，必须绕过 TUN。
        // 排除 sing-box TUN 的 local-dns（tunDnsChina）与 xray 的 bootstrap DNS 两处。
        let bootstrapHosts = [
            UserDefaults.get(forKey: .tunDnsChina, defaultValue: defaultBootstrapDns),
            getDnsBootstrapSetting(),
        ]
        for host in bootstrapHosts where !host.isEmpty {
            let trimmed = host.trimmingCharacters(in: .whitespacesAndNewlines)
            if isIPAddressLiteral(trimmed) {
                append(trimmed)
            } else {
                resolveServerIps(from: trimmed).forEach(append)
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

        let tunAddr = UserDefaults.get(forKey: .tunAddress, defaultValue: defaultTunAddress)
        let tunAddrIPv6 = UserDefaults.get(forKey: .tunAddressIPv6, defaultValue: defaultTunIPv6)
        let tunMtu = UserDefaults.getInt(forKey: .tunMtu, defaultValue: 1500)
        let tunStack = UserDefaults.getEnum(forKey: .tunStack, type: TunStack.self, defaultValue: .system)
        let tunStrictRoute = UserDefaults.getBool(forKey: .tunStrictRoute, default: true)
        let tunRouteExcludeHosts = UserDefaults.get(forKey: .tunRouteExcludeHosts)
        let userExcludeAddresses = resolveRouteExcludeAddresses(from: tunRouteExcludeHosts)
        let routeExcludeAddresses = mergedRouteExcludeAddresses(userConfigured: userExcludeAddresses)
        let tunEnableIPv6 = UserDefaults.getBool(forKey: .tunEnableIPv6, default: true)
        let useSniffRuleAction = SingboxVersionCheck.supportsSniffRuleAction()

        var addresses = [tunAddr]
        if tunEnableIPv6 {
            addresses.append(tunAddrIPv6)
        }
        // sing-box >= 1.14.0 新增 dns_mode，默认 hijack 会劫持系统 DNS 并安装平台级规则，
        // 在 macOS 上可能与系统安全策略冲突。设为 disabled 保持 1.13.x 的行为。
        let tunDnsMode: String? = SingboxVersionCheck.supportsTunDnsMode() ? "disabled" : nil
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
            sniff_override_destination: useSniffRuleAction ? nil : true,
            dns_mode: tunDnsMode
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

        // MARK: - DNS 配置
        //
        // TUN 捕获所有 DNS 查询（UDP:53），hijack-dns 交给 sing-box DNS 引擎分流：
        //   代理服务器域名 → local-dns（直连，防死锁）
        //   geosite:cn     → local-dns（国内域名，低延迟）
        //   其他            → remote-dns（通过代理，海外域名）
        //
        // 系统 DNS 设为 1.1.1.1，仅对绕过 TUN 的流量生效（process_name direct 匹配的流量）。
        let dnsChina = UserDefaults.get(forKey: .tunDnsChina, defaultValue: defaultBootstrapDns)
        let dnsRemote = UserDefaults.get(forKey: .tunDnsRemote, defaultValue: "1.1.1.1")
        let useNewDns = SingboxVersionCheck.supportsNewDnsFormat()
        let proxyDomains = TunConfigHandler.proxyServerDomains()

        if useNewDns {
            let isIP = isIPAddressLiteral(dnsRemote)
            var remoteDns = DNSServer(tag: "remote-dns", type: "tcp", server: dnsRemote, detour: "proxy")
            if !isIP { remoteDns.domain_resolver = "local-dns" }
            var dnsRules = [DNSRule]()
            // DNS 规则按优先级从高到低排列（顺序匹配，第一条命中即停）：
            // 1. 代理服务器域名 → local-dns：防死锁（即使被 hijack-dns 劫持也能直连解析）
            // 2. geosite:cn → local-dns：国内域名直连，低延迟
            // 3. localhost/local → local-dns：本地域名直连
            // 4. final: remote-dns：其他域名走代理（海外域名）
            if !proxyDomains.isEmpty {
                dnsRules.append(DNSRule(server: "local-dns", domain: proxyDomains))
            }
            dnsRules.append(DNSRule(server: "local-dns", geosite: ["cn"], strategy: "prefer_ipv4"))
            dnsRules.append(DNSRule(server: "local-dns", domain: ["localhost", "local"]))
            singbox.dns = DNSConfig(
                servers: [
                    remoteDns,
                    DNSServer(tag: "local-dns", type: "udp", server: dnsChina),
                ],
                rules: dnsRules,
                final: "remote-dns",
                independent_cache: true,
                strategy: "prefer_ipv4"
            )
        } else {
            let isIP = isIPAddressLiteral(dnsRemote)
            var remoteDns = DNSServer(tag: "remote-dns", detour: "proxy", address: "tcp://\(dnsRemote)")
            if !isIP { remoteDns.address_resolver = "local-dns" }
            var dnsRules = [DNSRule]()
            if !proxyDomains.isEmpty {
                dnsRules.append(DNSRule(server: "local-dns", domain: proxyDomains))
            }
            dnsRules.append(DNSRule(server: "local-dns", geosite: ["cn"]))
            dnsRules.append(DNSRule(server: "local-dns", domain: ["localhost", "local"]))
            singbox.dns = DNSConfig(
                servers: [
                    remoteDns,
                    DNSServer(tag: "local-dns", address: "udp://\(dnsChina)"),
                ],
                rules: dnsRules,
                final: "remote-dns",
                independent_cache: true
            )
        }

        // MARK: - Route 规则(这里主要针对tun)
        //
        // 路由规则按顺序匹配，第一条命中即停：
        //   1. process_name → direct：核心进程（xray/sing-box）的流量绕过 TUN，避免 DNS 死锁
        //   2. sniff：协议检测（TLS/HTTP），为后续 protocol 规则提供匹配依据
        //   3. hijack-dns：劫持所有 DNS 查询，交给 sing-box DNS 引擎按上述 DNS rules 分流
        //   4. default：其余流量走 SOCKS proxy（默认出站）
        //
        // 为什么 process_name 必须在 hijack-dns 之前？
        //   如果顺序反过来，xray 的 DNS 查询会被 hijack-dns 劫持 → 走 remote-dns (via proxy) →
        //   但 xray 就是那个 proxy，还没连上远端，无法转发 → 死锁。
        //
        // 为什么 sniff 必须在 hijack-dns 之前？
        //   hijack-dns 通过 protocol: ["dns"] 匹配，而 sing-box 只有 sniff 之后才能知道连接
        //   的协议类型。若 sniff 在 hijack-dns 之后，protocol 永远匹配不上，DNS 查询会落到
        //   default → SOCKS → xray，导致解析失败（core.log 中出现大量 udp:1.1.1.1:53
        //   accepted [mixed-in >> proxy] 与 read/write on closed pipe）。
        //
        // 包级兜底（route_exclude_address，本文件上方）：
        //   macOS 上 process_name 对 UDP DNS 包的匹配不可靠，xray 的 DNS 查询可能跳过
        //   process_name 规则直接命中 hijack-dns。因此代理服务器 IP 与 bootstrap DNS IP 已被
        //   加入 route_exclude_address，xray 的 DNS 查询与数据连接都在包级绕过 TUN，
        //   不依赖 process_name 匹配。
        //
        // 为什么还需要 DNS.proxyServerDomains 兜底？
        //   覆盖服务器 IP 变化（CDN/轮询）后 route_exclude_address 过期的场景：
        //   即使被劫持，代理服务器域名也能走 local-dns 直连解析，打破循环。
        var tunRules: [RouteRule] = []
        let directProcessNames = UserDefaults.get(forKey: .tunDirectProcessNames)
        let proxyProcessNames = UserDefaults.get(forKey: .tunProxyProcessNames)
        let directApplicationPaths = UserDefaults.getStringArray(forKey: .tunDirectApplicationPaths)
        let proxyApplicationPaths = UserDefaults.getStringArray(forKey: .tunProxyApplicationPaths)
        tunRules.append(contentsOf: buildProcessRouteRules(
            directRawValue: directProcessNames,
            proxyRawValue: proxyProcessNames,
            directApplicationPaths: directApplicationPaths,
            proxyApplicationPaths: proxyApplicationPaths
        ))
        // 协议检测必须先于 hijack-dns：protocol: ["dns"] 依赖 sniff 结果才能匹配
        if useSniffRuleAction {
            tunRules.append(RouteRule(action: "sniff"))
        }
        // 劫持 DNS 流量，使 dns.servers/rules 对应用流量生效（仅影响非核心进程）
        tunRules.append(RouteRule(action: "hijack-dns", protocol: ["dns"]))
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
