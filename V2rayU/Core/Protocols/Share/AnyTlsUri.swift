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
        profile.host = query.getString(forKey: "host", defaultValue: "")
        profile.path = query.getString(forKey: "path", defaultValue: "")

        let alpnString = query.getString(forKey: "alpn", defaultValue: "")
        if let alpn = V2rayStreamAlpn(rawValue: alpnString) {
            profile.alpn = alpn
        } else {
            profile.alpn = .h2h1
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

