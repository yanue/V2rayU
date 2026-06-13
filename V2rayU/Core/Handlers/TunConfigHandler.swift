import Foundation

enum TunConfigHandler {
    static func buildTunConfig(item: ProfileEntity) -> String {
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
        let useSniffRuleAction = SingboxVersionCheck.supportsSniffRuleAction()

        let tunInbound = SingboxInbound(
            type: "tun",
            tag: "tun-in",
            address: [tunAddr],
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
        singbox.outbounds = [socksOutbound, directOutbound]

        let dnsDefault = UserDefaults.get(forKey: .tunDnsDefault, defaultValue: defaultBootstrapDns)
        let useNewFormat = SingboxVersionCheck.supportsNewDnsFormat()
        if useNewFormat {
            singbox.dns = DNSConfig(
                servers: [
                    DNSServer(tag: "local-dns", type: "udp", server: dnsDefault),
                    DNSServer(tag: "china-dns", type: "udp", server: "119.29.29.29"),
                    DNSServer(tag: "fakedns", type: "fakeip", inet4_range: "198.18.0.0/15", inet6_range: "fc00::/18"),
                ],
                rules: [
                    DNSRule(server: "china-dns", geosite: ["cn"]),
                    DNSRule(server: "fakedns", geosite: ["geolocation-!cn"]),
                ],
                final: nil
            )
        } else {
            singbox.dns = DNSConfig(
                servers: [
                    DNSServer(tag: "local-dns", address: "udp://\(dnsDefault)"),
                    DNSServer(tag: "china-dns", address: "udp://119.29.29.29"),
                    DNSServer(tag: "fakedns", type: "fakeip", inet4_range: "198.18.0.0/15", inet6_range: "fc00::/18"),
                ],
                rules: [
                    DNSRule(server: "china-dns", geosite: ["cn"]),
                    DNSRule(server: "fakedns", geosite: ["geolocation-!cn"]),
                ],
                final: nil
            )
        }

        var tunRules: [RouteRule] = []
        if useSniffRuleAction {
            tunRules.append(RouteRule(action: "sniff"))
        }
        tunRules.append(RouteRule(outbound: "direct", process_name: ["xray", "xray-64", "xray-arm64", "v2ray", "v2ray-core", "sing-box", "sing-box-arm64", "sing-box-64"]))
        singbox.route = RouteConfig(
            auto_detect_interface: true,
            default_domain_resolver: "local-dns",
            rules: tunRules
        )
        singbox.applyBundledRuleSets()

        return singbox.toJSON()
    }
}
