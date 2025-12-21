import Foundation

// trojan
class TrojanUri: BaseShareUri {
    private var profile: ProfileEntity
    private var error: String?

    // 初始化
    init() {
        profile = ProfileEntity(protocol: .trojan)
    }

    // 从 ProfileModel 初始化
    required init(from model: ProfileEntity) {
        // 通过传入的 model 初始化 Profile 类的所有属性
        profile = model
    }

    func getProfile() -> ProfileEntity {
        return profile
    }

    // trojan://pass@remote_host:443?flow=xtls-rprx-origin&security=xtls&sni=sni&host=remote_host#trojan
    func encode() -> String {
        var uri = URLComponents()
        uri.scheme = "trojan"
        uri.user = self.profile.password // 因没有 user，所以这里用 password, 不然会多一个 :
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
        logger.info("Parsed URI: \(url),")

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
        if let fragment = url.fragment, !fragment.isEmpty {
            self.profile.remark = fragment.urlDecoded()
        }
        if self.profile.remark.isEmpty {
            self.profile.remark = "trojan"
        }
        // shadowrocket trojan url: trojan://%3Apassword@host:port?query#remark
        if url.absoluteString.contains("trojan://%3A") {
            // 去掉前面的 %3A,即:
            profile.password = password.replacingOccurrences(of: "%3A", with: "").replacingOccurrences(of: ":", with: "")
             // 以下是 shadowrocket 的分享参数:
            // 方式1: peer=sni.xx.xx&obfs=grpc&obfsParam=hjfjkdkdi&path=tekdjjd#yanue-trojan1
            // 方式2: ?peer=sni.xx.xx&plugin=obfs-local;obfs=websocket;obfs-host=%7B%22Host%22:%22hjfjkdkdi%22%7D;obfs-uri=tekdjjd#trojan3
            let peer = query.getString(forKey: "peer", defaultValue: "")
            if peer.count > 0 {
                profile.sni = peer
            }
            let obfs = query.getString(forKey: "obfs", defaultValue: "")
            // 方式1: 以obfs方式
            if obfs.count > 0 {
                // 这里是 obfs 的参数
                if obfs == "grpc" {
                    profile.network = .grpc
                } else if obfs == "websocket" || obfs == "ws" {
                    profile.network = .ws
                } else if obfs == "h2" {
                    profile.network = .h2
                } else {
                    profile.network = .tcp
                }
            }
            let obfsParam = query.getString(forKey: "obfs-uri", defaultValue: "")
            if  obfsParam.count > 0 {
                // 这里是 obfsParam 的参数,即 host
                profile.host = obfsParam
            }
            let path = query.getString(forKey: "path", defaultValue: "")
            if path .count > 0 {
                // 这里是 obfsParam 的参数,即 path
                profile.path = path
            }
            // 方式2: 以 plugin 方式
            let plugin = query.getString(forKey: "plugin", defaultValue: "")
            if plugin.count > 0 {
                // 这里是 plugin 的参数: obfs-local;obfs=websocket;obfs-host={"Host":"hjfjkdkdi"};obfs-uri=tekdjjd
                // 按 ; 分割
                let plugins = plugin.components(separatedBy: ";")
                for plugin in plugins {
                    let pluginParts = plugin.components(separatedBy: "=")
                    if pluginParts.count < 2 {
                        continue
                    }
                    switch pluginParts[0] {
                    case "obfs":
                        // 这里是 ws 的
                        if pluginParts[1] == "websocket" || pluginParts[1] == "ws" {
                            profile.network = .ws
                        } else if pluginParts[1] == "h2" {
                            profile.network = .h2
                        } else if pluginParts[1] == "grpc" {
                            profile.network = .grpc
                        } else {
                            profile.network = .tcp
                        }
                    case "obfs-host":
                        // 这里是 ws,h2 的 host: {"Host":"hjfjkdkdi"}
                        if let hostValue = pluginParts[1].removingPercentEncoding,let data = hostValue.data(using: .utf8) {
                            // 解析 JSON 字典:  {"Host":"hjfjkdkdi"}
                            if let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: String],
                               let host = json["Host"] {
                                profile.host = host
                            }
                        }
                    case "obfs-uri":
                        // 这里是 ws,h2 的 path
                        profile.path = pluginParts[1]
                    default:
                        break
                    }
                }
            }
        }
        return nil
    }
}
