import Foundation

// AnyTLS
class AnyTlsUri: BaseShareUri {
    private var profile: ProfileEntity
    private var error: String?

    init() {
        profile = ProfileEntity(protocol: .anytls)
    }

    required init(from model: ProfileEntity) {
        profile = model
    }

    func getProfile() -> ProfileEntity {
        return profile
    }

    // anytls://password@host:port?sni=example.com&insecure=1&alpn=h2,http/1.1&fp=chrome#remark
    func encode() -> String {
        var uri = URLComponents()
        uri.scheme = "anytls"
        uri.user = profile.password
        uri.host = profile.address
        uri.port = profile.port

        var queryItems = [
            URLQueryItem(name: "security", value: profile.security.rawValue),
            URLQueryItem(name: "sni", value: profile.sni),
            URLQueryItem(name: "insecure", value: profile.allowInsecure ? "1" : "0"),
            URLQueryItem(name: "alpn", value: profile.alpn.rawValue),
            URLQueryItem(name: "fp", value: profile.fingerprint.rawValue),
            URLQueryItem(name: "pcks", value: profile.pinnedPeerCertSha256),
        ]
        if !profile.host.isEmpty {
            queryItems.append(URLQueryItem(name: "host", value: profile.host))
        }
        if !profile.path.isEmpty {
            queryItems.append(URLQueryItem(name: "path", value: profile.path))
        }
        uri.queryItems = queryItems

        return (uri.url?.absoluteString ?? "") + "#" + profile.remark.urlEncoded()
    }

    func parse(url: URL) -> Error? {
        guard let host = url.host else {
            return NSError(domain: "AnyTlsUriError", code: 1001, userInfo: [NSLocalizedDescriptionKey: "Missing host"])
        }
        guard let port = url.port else {
            return NSError(domain: "AnyTlsUriError", code: 1002, userInfo: [NSLocalizedDescriptionKey: "Missing port"])
        }
        guard let password = url.user, !password.isEmpty else {
            return NSError(domain: "AnyTlsUriError", code: 1003, userInfo: [NSLocalizedDescriptionKey: "Missing password"])
        }

        logger.info("Parsed AnyTLS URI: \(url)")

        profile.protocol = .anytls
        profile.address = host
        profile.port = port
        profile.password = password
        profile.network = .tcp

        let query = url.queryParams()
        profile.security = query.getEnum(forKey: "security", type: V2rayStreamSecurity.self, defaultValue: .tls)
        if profile.security == .none {
            profile.security = .tls
        }
        profile.sni = query.getString(forKey: "sni", defaultValue: query.getString(forKey: "peer", defaultValue: host))
        profile.allowInsecure = query.getBool(forKey: "insecure", defaultValue: query.getBool(forKey: "allowInsecure", defaultValue: false))
        profile.fingerprint = query.getEnum(forKey: "fp", type: V2rayStreamFingerprint.self, defaultValue: .chrome)
        profile.pinnedPeerCertSha256 = query.getString(forKey: "pcks", defaultValue: "")
        profile.host = query.getString(forKey: "host", defaultValue: "")
        profile.path = query.getString(forKey: "path", defaultValue: "")

        let alpnString = query.getString(forKey: "alpn", defaultValue: "")
        let normalizedAlpn = alpnString.replacingOccurrences(of: "http/1.1", with: "http1.1")
        if let alpn = V2rayStreamAlpn(rawValue: normalizedAlpn) {
            profile.alpn = alpn
        }

        if let fragment = url.fragment, !fragment.isEmpty {
            profile.remark = fragment.urlDecoded()
        }
        if profile.remark.isEmpty {
            profile.remark = "anytls"
        }

        return nil
    }
}

// NaiveProxy over HTTPS (Sing-Box naive outbound)
class NaiveUri: BaseShareUri {
    private var profile: ProfileEntity

    init() {
        profile = ProfileEntity(protocol: .naive)
    }

    required init(from model: ProfileEntity) {
        profile = model
    }

    func getProfile() -> ProfileEntity {
        return profile
    }

    // naive://username:password@host:port?sni=example.com&insecure=1&alpn=h2,http/1.1&fp=chrome#remark
    // 无 username 时退化为 naive://password@host:port
    func encode() -> String {
        var uri = URLComponents()
        uri.scheme = "naive"
        if profile.host.isEmpty {
            uri.user = profile.password
        } else {
            uri.user = profile.host
            uri.password = profile.password
        }
        uri.host = profile.address
        uri.port = profile.port

        uri.queryItems = [
            URLQueryItem(name: "sni", value: profile.sni),
            URLQueryItem(name: "insecure", value: profile.allowInsecure ? "1" : "0"),
            URLQueryItem(name: "alpn", value: profile.alpn.rawValue),
            URLQueryItem(name: "fp", value: profile.fingerprint.rawValue),
            URLQueryItem(name: "pcks", value: profile.pinnedPeerCertSha256),
        ]

        return (uri.url?.absoluteString ?? "") + "#" + profile.remark.urlEncoded()
    }

    func parse(url: URL) -> Error? {
        guard let host = url.host else {
            return NSError(domain: "NaiveUriError", code: 1001, userInfo: [NSLocalizedDescriptionKey: "Missing host"])
        }
        guard let port = url.port else {
            return NSError(domain: "NaiveUriError", code: 1002, userInfo: [NSLocalizedDescriptionKey: "Missing port"])
        }
        guard let password = url.password ?? url.user, !password.isEmpty else {
            return NSError(domain: "NaiveUriError", code: 1003, userInfo: [NSLocalizedDescriptionKey: "Missing password"])
        }

        logger.info("Parsed Naive URI: \(url)")

        let query = url.queryParams()
        profile.protocol = .naive
        profile.address = host
        profile.port = port
        // 仅当 URI 形态是 user:password@host 时把 user 当 username 存入 profile.host
        if let pwd = url.password, !pwd.isEmpty, let user = url.user, !user.isEmpty {
            profile.host = user
        } else {
            profile.host = ""
        }
        profile.password = password
        profile.network = .tcp
        profile.security = .tls
        profile.sni = query.getString(forKey: "sni", defaultValue: query.getString(forKey: "peer", defaultValue: host))
        profile.allowInsecure = query.getBool(forKey: "insecure", defaultValue: query.getBool(forKey: "allowInsecure", defaultValue: false))
        // uTLS is not supported on naive outbound
        profile.fingerprint = .none
        profile.pinnedPeerCertSha256 = query.getString(forKey: "pcks", defaultValue: "")

        let alpnString = query.getString(forKey: "alpn", defaultValue: "")
        let normalizedAlpn = alpnString.replacingOccurrences(of: "http/1.1", with: "http1.1")
        if let alpn = V2rayStreamAlpn(rawValue: normalizedAlpn) {
            profile.alpn = alpn
        }

        if let fragment = url.fragment, !fragment.isEmpty {
            profile.remark = fragment.urlDecoded()
        }
        if profile.remark.isEmpty {
            profile.remark = "naive"
        }

        return nil
    }
}

