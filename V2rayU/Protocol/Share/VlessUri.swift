import Foundation

// 待定标准方案: https://github.com/XTLS/Xray-core/issues/91
//# VMess + TCP，不加密（仅作示例，不安全）
//vmess://99c80931-f3f1-4f84-bffd-6eed6030f53d@qv2ray.net:31415?encryption=none#VMessTCPNaked
//# VMess + TCP，自动选择加密。编程人员特别注意不是所有的 URL 都有问号，注意处理边缘情况。
//vmess://f08a563a-674d-4ffb-9f02-89d28aec96c9@qv2ray.net:9265#VMessTCPAuto
//# VMess + TCP，手动选择加密
//vmess://5dc94f3a-ecf0-42d8-ae27-722a68a6456c@qv2ray.net:35897?encryption=aes-128-gcm#VMessTCPAES
//# VMess + TCP + TLS，内层不加密
//vmess://136ca332-f855-4b53-a7cc-d9b8bff1a8d7@qv2ray.net:9323?encryption=none&security=tls#VMessTCPTLSNaked
//# VMess + TCP + TLS，内层也自动选择加密
//vmess://be5459d9-2dc8-4f47-bf4d-8b479fc4069d@qv2ray.net:8462?security=tls#VMessTCPTLS
//# VMess + TCP + TLS，内层不加密，手动指定 SNI
//vmess://c7199cd9-964b-4321-9d33-842b6fcec068@qv2ray.net:64338?encryption=none&security=tls&sni=fastgit.org#VMessTCPTLSSNI
//# VLESS + TCP + XTLS
//vless://b0dd64e4-0fbd-4038-9139-d1f32a68a0dc@qv2ray.net:3279?security=xtls&flow=rprx-xtls-splice#VLESSTCPXTLSSplice
//# VLESS + mKCP + Seed
//vless://399ce595-894d-4d40-add1-7d87f1a3bd10@qv2ray.net:50288?type=kcp&seed=69f04be3-d64e-45a3-8550-af3172c63055#VLESSmKCPSeed
//# VLESS + mKCP + Seed，伪装成 Wireguard
//vless://399ce595-894d-4d40-add1-7d87f1a3bd10@qv2ray.net:41971?type=kcp&headerType=wireguard&seed=69f04be3-d64e-45a3-8550-af3172c63055#VLESSmKCPSeedWG
//# VMess + WebSocket + TLS
//vmess://44efe52b-e143-46b5-a9e7-aadbfd77eb9c@qv2ray.net:6939?type=ws&security=tls&host=qv2ray.net&path=%2Fsomewhere#VMessWebSocketTLS
//# VLESS + TCP + reality
//vless://44efe52b-e143-46b5-a9e7-aadbfd77eb9c@qv2ray.net:443?encryption=none&flow=xtls-rprx-vision&security=reality&sni=sni.yahoo.com&fp=chrome&pbk=xxx&sid=88&type=tcp&headerType=none&host=hk.yahoo.com#reality

class VlessUri: BaseShareUri {

    private var profile: ProfileModel
    private var error: String?

    // 初始化
    init() {
        self.profile = ProfileModel(remark: "vless", protocol: .vless)
    }

    // 从 ProfileModel 初始化
    required init(from model: ProfileModel) {
        // 通过传入的 model 初始化 Profile 类的所有属性
        self.profile = model
    }

    func getProfile() -> ProfileModel {
        return self.profile
    }

    // vless://f2a5064a-fabb-43ed-a2b6-8ffeb970df7f@00.com:443?flow=xtls-rprx-splite&encryption=none&security=xtls&sni=aaaaa&type=http&host=00.com&path=%2fvl#vless1
    func encode() -> String {
        var uri = URLComponents()
        uri.scheme = "vless"
        uri.user = self.profile.id
        uri.host = self.profile.address
        uri.port = self.profile.port
        var queryItems = [
            URLQueryItem(name: "flow", value: self.profile.flow),
            URLQueryItem(name: "security", value: self.profile.security.rawValue),
            URLQueryItem(name: "encryption", value: self.profile.encryption),
            URLQueryItem(name: "type", value: self.profile.network.rawValue), // 网络类型: tcp,http,kcp,h2,ws,quic,grpc,domainsocket
            URLQueryItem(name: "sni", value: self.profile.sni),
            URLQueryItem(name: "fp", value: self.profile.fingerprint.rawValue),
            URLQueryItem(name: "pbk", value: self.profile.publicKey),
            URLQueryItem(name: "sid", value: self.profile.shortId),
        ]
        switch self.profile.network {
        case .tcp:
            queryItems.append(URLQueryItem(name: "headerType", value: self.profile.headerType.rawValue))
            break
        case .xhttp:
            queryItems.append(URLQueryItem(name: "path", value: self.profile.path))
            queryItems.append(URLQueryItem(name: "host", value: self.profile.host))
            break
        case .ws:
            queryItems.append(URLQueryItem(name: "path", value: self.profile.path))
            queryItems.append(URLQueryItem(name: "host", value: self.profile.host))
            break
        case .h2:
            queryItems.append(URLQueryItem(name: "host", value: self.profile.host))
            queryItems.append(URLQueryItem(name: "path", value: self.profile.path))
            break
        case .grpc:
            queryItems.append(URLQueryItem(name: "serviceName", value: self.profile.path))
            break
        case .domainsocket:
            queryItems.append(URLQueryItem(name: "path", value: self.profile.path))
            break
        case .kcp:
            queryItems.append(URLQueryItem(name: "seed", value: self.profile.path))
            queryItems.append(URLQueryItem(name: "headerType", value: self.profile.headerType.rawValue))
            break
        case .quic:
            queryItems.append(URLQueryItem(name: "path", value: self.profile.path))
            break
        }
        uri.queryItems = queryItems

        return (uri.url?.absoluteString ?? "") + "#" + self.profile.remark.urlEncoded()
    }

    func parse(url: URL) -> Error? {
        guard let host = url.host else {
            return NSError(domain: "VlessUriError", code: 1001, userInfo: [NSLocalizedDescriptionKey: "Missing host"])
        }
        guard let port = url.port else {
            return NSError(domain: "VlessUriError", code: 1002, userInfo: [NSLocalizedDescriptionKey: "Missing port"])
        }
        guard let password = url.user else {
            return NSError(domain: "VlessUriError", code: 1003, userInfo: [NSLocalizedDescriptionKey: "Missing id"])
        }
        self.profile.address = host
        self.profile.port = Int(port)
        self.profile.password = password
        let query = url.queryParams()
        self.profile.network = query.getEnum(forKey: "type",type: V2rayStreamNetwork.self, defaultValue: .tcp)
        self.profile.security = query.getEnum(forKey: "security", type: V2rayStreamSecurity.self, defaultValue: .xtls)
        self.profile.sni = query.getString(forKey: "sni", defaultValue: host)
        self.profile.fingerprint = query.getEnum(forKey: "fp", type: V2rayStreamFingerprint.self, defaultValue: .chrome)

        switch self.profile.network {
        case .tcp:
            self.profile.headerType = query.getEnum(forKey: "headerType", type: V2rayHeaderType.self, defaultValue: .none)
            break
        case .xhttp:
            self.profile.path = query.getString(forKey: "path", defaultValue: "/")
            self.profile.host = query.getString(forKey: "host", defaultValue: host)
            break
        case .ws:
            self.profile.path = query.getString(forKey: "path", defaultValue: "/")
            self.profile.host = query.getString(forKey: "host", defaultValue: host)
            break
        case .h2:
            self.profile.host = query.getString(forKey: "host", defaultValue: host)
            self.profile.path = query.getString(forKey: "path", defaultValue: "/")
            break
        case .grpc:
            self.profile.path = query.getString(forKey: "serviceName", defaultValue: "/")
            break
        case .domainsocket:
            self.profile.path = query.getString(forKey: "path", defaultValue: "/")
            break
        case .kcp:
            self.profile.path = query.getString(forKey: "seed", defaultValue: "")
            self.profile.headerType = query.getEnum(forKey: "headerType",type: V2rayHeaderType.self, defaultValue: .none)
            break
        case .quic:
            self.profile.path = query.getString(forKey: "path", defaultValue: "/")
            break
        default:
            break
        }

        if self.profile.security == .none {
            self.profile.security = .tls
        }

        if self.profile.sni.count == 0 {
            self.profile.sni = host
        }

        switch self.profile.security {
        case .reality: // reality
            self.profile.publicKey = query.getString(forKey: "pbk", defaultValue: "")
            self.profile.shortId = query.getString(forKey: "sid", defaultValue: "")
        default:
            break
        }

        self.profile.remark = (url.fragment ?? "vless").urlDecoded()
        return nil
    }
}
