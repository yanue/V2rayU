import Foundation

// trojan
class TrojanUri: BaseShareUri {

    private var profile: ProfileModel
    private var error: String?

    // 初始化
    init() {
        self.profile = ProfileModel(remark: "trojan",`protocol`: .trojan)
    }

    // 从 ProfileModel 初始化
    init(from model: ProfileModel) {
        // 通过传入的 model 初始化 Profile 类的所有属性
        self.profile = model
    }

    func getProfile() -> ProfileModel {
        return self.profile
    }

    // trojan://pass@remote_host:443?flow=xtls-rprx-origin&security=xtls&sni=sni&host=remote_host#trojan
    func encode() -> String {
        var uri = URLComponents()
        uri.scheme = "trojan"
        uri.password = self.password
        uri.host = self.host
        uri.port = self.port
        uri.queryItems = [
            URLQueryItem(name: "flow", value: self.flow),
            URLQueryItem(name: "security", value: self.security),
            URLQueryItem(name: "sni", value: self.sni),
            URLQueryItem(name: "fp", value: self.fingerprint),
        ]
        return (uri.url?.absoluteString ?? "") + "#" + self.remark
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

        self.profile.host = host
        self.profile.port = port
        self.profile.password = password

        let queryItems = url.queryParams()
        for item in queryItems {
            switch item.key {
            case "sni":
                self.profile.sni = item.value as? String ?? ""
            case "flow":
               self.profile.flow = item.value as? String ?? ""
            case "security":
               self.profile.security = item.value as? String ?? ""
            case "fp":
               self.profile.fingerprint = item.value as? String ?? ""
            default:
                break
            }
        }

        if self.profile.security.isEmpty {
            self.profile.security = "tls"
        }

        self.profile.remark = (url.fragment ?? "trojan").urlDecoded()
        return nil
    }
}