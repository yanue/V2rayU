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
        self.profile = ProfileModel(remark: "vless",`protocol`: .vless)
    }

    // 从 ProfileModel 初始化
    init(from model: ProfileModel) {
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
        uri.user = self.id
        uri.host = self.address
        uri.port = self.port
        uri.queryItems = [
            URLQueryItem(name: "flow", value: self.flow),
            URLQueryItem(name: "security", value: self.security),
            URLQueryItem(name: "encryption", value: self.encryption),
            URLQueryItem(name: "type", value: self.network), // 网络类型: tcp,http,kcp,h2,ws,quic,grpc,domainsocket
            URLQueryItem(name: "host", value: self.host),
            URLQueryItem(name: "path", value: self.path),
            URLQueryItem(name: "sni", value: self.sni),
            URLQueryItem(name: "fp", value: self.fingerprint),
            URLQueryItem(name: "pbk", value: self.publicKey),
            URLQueryItem(name: "sid", value: self.shortId),
            URLQueryItem(name: "serviceName", value: self.path),
            URLQueryItem(name: "headerType", value: self.headerType),
            URLQueryItem(name: "seed", value: self.path)
        ]

        return (uri.url?.absoluteString ?? "") + "#" + self.remark
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
        let queryItems = url.queryParams()
        for item in queryItems {
            switch item.key {
            case "flow":
                self.profile.flow = item.value as! String
                break
            case "encryption":
                self.profile.encryption = item.value as! String
                if self.profile.encryption.count == 0 {
                    self.profile.encryption = "none"
                }
                break
            case "security":
                self.profile.security = item.value as! String
                break
            case "type":
                self.profile.network = item.value as! String
                break
            case "host":
                self.profile.host = item.value as! String
                break
            case "sni":
                self.profile.sni = item.value as! String
                break
            case "path":
                self.profile.path = item.value as! String
                break
            case "fp":
                self.profile.fingerprint = item.value as! String
                break
            case "pbk":
                self.profile.publicKey = item.value as! String
                break
            case "sid":
                self.profile.shortId = item.value as! String
                break
            case "headerType":
                self.profile.headerType = item.value as! String
                break
            case "seed":
                self.profile.path = item.value as! String
                break
            case "serviceName":
                self.profile.path = item.value as! String
                break
            default:
                break
            }
        }

        if self.profile.sni.count == 0 {
            self.profile.sni = address
        }

        self.remark = (url.fragment ?? "vless").urlDecoded()
    }
}
