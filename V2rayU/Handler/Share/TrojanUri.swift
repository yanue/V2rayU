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
        uri.queryItems = [
            URLQueryItem(name: "flow", value: profile.flow),
            URLQueryItem(name: "security", value: profile.security.rawValue),
            URLQueryItem(name: "sni", value: profile.sni),
            URLQueryItem(name: "fp", value: profile.fingerprint.rawValue),
        ]
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

        profile.host = host
        profile.port = port
        profile.password = password

        let queryItems = url.queryParams()
        for item in queryItems {
            switch item.key {
            case "sni":
                profile.sni = item.value as? String ?? ""
            case "flow":
                profile.flow = item.value as? String ?? ""
            case "security":
                profile.security = V2rayStreamSecurity(rawValue: item.value as? String ?? "") ?? .none
            case "fp":
                profile.fingerprint = V2rayStreamFingerprint(rawValue: item.value as? String ?? "") ?? .chrome
            default:
                break
            }
        }

        if profile.security == .none {
            profile.security = .tls
        }

        profile.remark = (url.fragment ?? "trojan").urlDecoded()
        return nil
    }
}
