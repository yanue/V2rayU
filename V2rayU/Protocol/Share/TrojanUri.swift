import Foundation

// trojan
class TrojanUri: BaseShareUri {
    private var profile: ProfileModel
    private var error: String?

    // 初始化
    init() {
        profile = ProfileModel(remark: "trojan", protocol: .trojan)
    }

    // 从 ProfileModel 初始化
    required init(from model: ProfileModel) {
        // 通过传入的 model 初始化 Profile 类的所有属性
        profile = model
    }

    func getProfile() -> ProfileModel {
        return profile
    }

    // trojan://pass@remote_host:443?flow=xtls-rprx-origin&security=xtls&sni=sni&host=remote_host#trojan
    func encode() -> String {
        var uri = URLComponents()
        uri.scheme = "trojan"
        uri.password = profile.password
        uri.host = profile.address
        uri.port = profile.port
        var queryItems = [
            URLQueryItem(name: "type", value: profile.network.rawValue),
            URLQueryItem(name: "security", value: profile.security.rawValue),
            URLQueryItem(name: "sni", value: profile.sni),
            URLQueryItem(name: "fp", value: profile.fingerprint.rawValue),
        ]
        // 判断 network 类型
        switch profile.network {
        case .tcp:
            queryItems.append(URLQueryItem(name: "headerType", value: profile.headerType.rawValue))
            break
        case .ws:
            queryItems.append(URLQueryItem(name: "path", value: profile.path))
            queryItems.append(URLQueryItem(name: "host", value: profile.host))
            break
        case .h2:
            queryItems.append(URLQueryItem(name: "host", value: profile.host))
            queryItems.append(URLQueryItem(name: "path", value: profile.path))
            break
        case .grpc:
            queryItems.append(URLQueryItem(name: "serviceName", value: profile.path))
            break
        default:
            break
        }
        uri.queryItems = queryItems
        return (uri.url?.absoluteString ?? "") + "#" + profile.remark.urlEncoded()
    }

    func parse(url: URL) -> Error? {
        guard let host = url.host else {
            return NSError(domain: "TrojanUriError", code: 1001, userInfo: [NSLocalizedDescriptionKey: "Missing host"])
        }
        guard let port = url.port else {
            return NSError(domain: "TrojanUriError", code: 1002, userInfo: [NSLocalizedDescriptionKey: "Missing port"])
        }
        guard let password = url.user else {
            return NSError(domain: "TrojanUriError", code: 1003, userInfo: [NSLocalizedDescriptionKey: "Missing password"])
        }

        profile.address = host
        profile.port = port
        profile.password = password

        let query = url.queryParams()
        profile.network = query.getEnum(forKey: "type", type: V2rayStreamNetwork.self, defaultValue: .tcp)
        profile.security = query.getEnum(forKey: "security", type: V2rayStreamSecurity.self, defaultValue: .tls)
        profile.sni = query.getString(forKey: "sni", defaultValue: profile.address)
        profile.fingerprint = query.getEnum(forKey: "fp", type: V2rayStreamFingerprint.self, defaultValue: .chrome)
        // security 不能为 none
        if profile.security == .none {
            profile.security = .tls
        }
        // 如果 sni 为空，则将 host 赋值给 sni
        if self.profile.sni.count == 0 {
            self.profile.sni = host
        }
        // 判断 network 类型
        switch profile.network {
        case .tcp:
            profile.headerType = query.getEnum(forKey: "headerType", type: V2rayHeaderType.self, defaultValue: .none)
            break
        case .ws, .h2:
            profile.host = query.getString(forKey: "host", defaultValue: profile.address)
            profile.path = query.getString(forKey: "path", defaultValue: "/")
            break
        case .grpc:
            // grpcServiceName: 先从 query 中获取 serviceName，如果没有则获取 path，如果都没有则默认为 "/"
            profile.path = query.getString(forKey: "serviceName", defaultValue: query.getString(forKey: "path", defaultValue: "/"))
            break
        default:
            break
        }
        profile.remark = (url.fragment ?? "trojan").urlDecoded()
        return nil
    }
}
