import Foundation

// TUIC v5 (Sing-Box tuic outbound)
// 字段复用: UUID 存 host, 拥塞控制存 encryption, UDP 转发模式存 path
class TuicUri: BaseShareUri {
    private var profile: ProfileEntity

    static let congestionControls = ["bbr", "cubic", "new_reno"]
    static let udpRelayModes = ["native", "quic"]

    init() {
        profile = ProfileEntity(protocol: .tuic)
    }

    required init(from model: ProfileEntity) {
        profile = model
    }

    func getProfile() -> ProfileEntity {
        return profile
    }

    // tuic://uuid:password@host:port?congestion_control=bbr&udp_relay_mode=native&alpn=h3&sni=example.com&allow_insecure=1#remark
    func encode() -> String {
        var uri = URLComponents()
        uri.scheme = "tuic"
        uri.user = profile.host
        uri.password = profile.password
        // IPv6 必须加方括号, 否则 URL 生成失败(nil)
        uri.host = profile.address.contains(":") ? "[\(profile.address)]" : profile.address
        uri.port = profile.port

        var queryItems = [
            URLQueryItem(name: "sni", value: profile.sni),
            URLQueryItem(name: "alpn", value: profile.alpn.rawValue.replacingOccurrences(of: "http1.1", with: "http/1.1")),
            URLQueryItem(name: "allow_insecure", value: profile.allowInsecure ? "1" : "0"),
        ]
        if !profile.encryption.isEmpty {
            queryItems.append(URLQueryItem(name: "congestion_control", value: profile.encryption))
        }
        if !profile.path.isEmpty {
            queryItems.append(URLQueryItem(name: "udp_relay_mode", value: profile.path))
        }
        uri.queryItems = queryItems

        return (uri.url?.absoluteString ?? "") + "#" + profile.remark.urlEncoded()
    }

    func parse(url: URL) -> Error? {
        guard let host = url.host else {
            return NSError(domain: "TuicUriError", code: 1001, userInfo: [NSLocalizedDescriptionKey: "Missing host"])
        }
        guard let port = url.port else {
            return NSError(domain: "TuicUriError", code: 1002, userInfo: [NSLocalizedDescriptionKey: "Missing port"])
        }
        // 只支持 v5 (uuid:password), v4 的 token 形式 sing-box 不支持
        // URL.user 已经解码过, URL.password 没有, 只对 password 解码一次
        guard let uuid = url.user, !uuid.isEmpty, let password = url.password?.urlDecoded() else {
            return NSError(domain: "TuicUriError", code: 1003, userInfo: [NSLocalizedDescriptionKey: "Missing uuid or password (only TUIC v5 is supported)"])
        }

        logger.info("Parsed TUIC URI: \(url)")

        let query = url.queryParams()
        profile.protocol = .tuic
        profile.address = host
        profile.port = port
        profile.host = uuid
        profile.password = password
        profile.network = .tcp
        profile.security = .tls
        profile.sni = query.getString(forKey: "sni", defaultValue: query.getString(forKey: "peer", defaultValue: host))
        profile.allowInsecure = query.getBool(forKey: "allow_insecure",
                                              defaultValue: query.getBool(forKey: "insecure", defaultValue: query.getBool(forKey: "allowInsecure", defaultValue: false)))
        profile.fingerprint = .none
        profile.encryption = Self.normalizedCongestionControl(query.getString(forKey: "congestion_control", defaultValue: query.getString(forKey: "congestion", defaultValue: "")))
        profile.path = Self.normalizedUdpRelayMode(query.getString(forKey: "udp_relay_mode", defaultValue: ""))

        profile.alpn = Self.normalizedAlpn(query.getString(forKey: "alpn", defaultValue: ""))

        if let fragment = url.fragment, !fragment.isEmpty {
            profile.remark = fragment.urlDecoded()
        }
        if profile.remark.isEmpty {
            profile.remark = "tuic"
        }

        return nil
    }

    /// 不认识的值留空, 由 sing-box 用默认值 (cubic)
    static func normalizedCongestionControl(_ value: String) -> String {
        let lower = value.lowercased().replacingOccurrences(of: "-", with: "_")
        return congestionControls.contains(lower) ? lower : ""
    }

    /// TUIC 必须带 ALPN, 没写或不认识时用 h3
    static func normalizedAlpn(_ value: String) -> V2rayStreamAlpn {
        let alpn = V2rayStreamAlpn(rawValue: value.replacingOccurrences(of: "http/1.1", with: "http1.1")) ?? .h3
        return alpn == .none ? .h3 : alpn
    }

    static func normalizedUdpRelayMode(_ value: String) -> String {
        let lower = value.lowercased()
        return udpRelayModes.contains(lower) ? lower : ""
    }
}
