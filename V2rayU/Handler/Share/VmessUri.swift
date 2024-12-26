//
// Created by yanue on 2021/6/5.
// Copyright (c) 2021 yanue. All rights reserved.
//

import Foundation

struct VmessShare: Codable {
    var v: String = "2"
    var ps: String = ""
    var add: String = ""
    var port: String = ""
    var id: String = "" // UUID
    var aid: String = "" // alterId
    var net: String = "" // network type: (tcp\kcp\ws\h2\quic\ds\grpc)
    var type: String = "none" // 伪装类型(none\http\srtp\utp\wechat-video) *tcp or kcp or QUIC
    var host: String = "" // host: 1)http(tcp)->host中间逗号(,)隔开,2)ws->host,3)h2->host,4)QUIC->securty
    var path: String = "" // path: 1)ws->path,2)h2->path,3)QUIC->key/Kcp->seed,4)grpc->serviceName
    var tls: String = "tls"
    var security: String = "auto" // 加密方式(security),没有时值默认auto
    var scy: String = "auto" // 同security
    var alpn: String = "" // h2,http/1.1
    var sni: String = ""
    var fp: String = ""
    var serviceName: String = "" // grpc
    var seed: String = "" // kcp

    // 自定义解码以处理可能的不同类型
    enum CodingKeys: String, CodingKey {
        case v, ps, add, port, id, aid, net, type, host, path, tls, alpn, sni, security, scy, fp, serviceName, seed
    }
    
    init(from model: ProfileModel) {
        self.ps = model.remark
        self.add = model.address
        self.port = String(model.port) // 转为字符串形式
        self.id = model.password
        self.aid = String(model.alterId) // 转为字符串形式
        self.net = model.network.rawValue
        self.type = model.headerType.rawValue
        self.host = model.host
        self.path = model.path
        self.tls = model.security.rawValue
        self.security = model.encryption
        self.scy = model.encryption
        self.alpn = model.alpn.rawValue
        self.sni = model.sni
        self.fp = model.fingerprint.rawValue
        self.serviceName = model.network == .grpc ? model.path : ""
        self.seed = model.network == .kcp ? model.path : ""
    }


    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        v = try container.decode(String.self, forKey: .v)
        ps = try container.decode(String.self, forKey: .ps)
        add = try container.decode(String.self, forKey: .add)
        id = try container.decode(String.self, forKey: .id)
        aid = try container.decode(String.self, forKey: .aid)
        net = try container.decode(String.self, forKey: .net)
        type = try container.decode(String.self, forKey: .type)
        host = try container.decode(String.self, forKey: .host)
        path = try container.decode(String.self, forKey: .path)
        tls = try container.decode(String.self, forKey: .tls)
        alpn = try container.decode(String.self, forKey: .alpn)
        sni = try container.decode(String.self, forKey: .sni)
        scy = try container.decode(String.self, forKey: .scy)
        fp = try container.decode(String.self, forKey: .fp)
        serviceName = try container.decode(String.self, forKey: .serviceName)
        seed = try container.decode(String.self, forKey: .seed)

        // 处理 port 字段的类型不确定性
        if let portValue = try? container.decode(Int.self, forKey: .port) {
            port = String(portValue)
        } else if let portValue = try? container.decode(String.self, forKey: .port) {
            port = portValue
        } else {
        }
        // 处理 aid
        if let aidValue = try? container.decode(Int.self, forKey: .aid) {
            aid = String(aidValue)
        } else if let aidValue = try? container.decode(String.self, forKey: .aid) {
            aid = aidValue
        } else {
        }
    }
}

// see: https://github.com/v2ray/v2ray-core/issues/1139
class VmessUri: BaseShareUri {
    private var profile: ProfileModel
    private var error: String = ""

    // 初始化
    init() {
        profile = ProfileModel(remark: "vless", protocol: .vless)
    }

    // 从 ProfileModel 初始化
    required init(from model: ProfileModel) {
        // 通过传入的 model 初始化 Profile 类的所有属性
        profile = model
    }

    func getProfile() -> ProfileModel {
        return profile
    }

    // 分享链接
    func encode() -> String {
        let share = VmessShare(from: self.profile)
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(share) {
            let uri = String(data: data, encoding: .utf8)!
            return "vmess://" + uri.base64Encoded()!
        } else {
            error = "encode uri error"
        }
        return ""
    }

    func parse(url: URL) -> Error? {
        // 先尝试解析类型2
        parseType2(url: url)
        if error.count > 0 {
            // 再尝试解析类型1
            parseType1(url: url)
        }
        if error.count > 0 {
            return NSError(domain: "VlessUriError", code: 1001, userInfo: [NSLocalizedDescriptionKey: "vmess error"])
        }
        return nil
    }

    /**
     vmess://base64(security:uuid@host:port)?[urlencode(parameters)]
     其中 base64、urlencode 为函数，security 为加密方式，parameters 是以 & 为分隔符的参数列表，例如：network=kcp&aid=32&remark=服务器1 经过 urlencode 后为 network=kcp&aid=32&remark=%E6%9C%8D%E5%8A%A1%E5%99%A81
     可选参数（参数名称不区分大小写）：
     network - 可选的值为 "tcp"、 "kcp"、"ws"、"h2" 等
     wsPath - WebSocket 的协议路径
     wsHost - WebSocket HTTP 头里面的 Host 字段值
     kcpHeader - kcp 的伪装类型
     uplinkCapacity - kcp 的上行容量
     downlinkCapacity - kcp 的下行容量
     h2Path - h2 的路径
     h2Host - h2 的域名
     aid - AlterId
     tls - 是否启用 TLS，为 0 或 1
     allowInsecure - TLS 的 AllowInsecure，为 0 或 1
     tlsServer - TLS 的服务器端证书的域名
     remark - 备注名称
     导入配置时，不在列表中的参数一般会按照 Core 的默认值处理。
     */
    func parseType1(url: URL) {
        let urlStr = url.absoluteString
        // vmess://
        let base64Begin = urlStr.index(urlStr.startIndex, offsetBy: 8)
        let base64End = urlStr.firstIndex(of: "?")
        let encodedStr = String(urlStr[base64Begin ..< (base64End ?? urlStr.endIndex)])

        guard let decodeStr = encodedStr.base64Decoded() else {
            error = "error decode Str"
            return
        }
        print("decodeStr", decodeStr)
        // main
        var uuid_ = ""
        var host_ = ""
        let mainArr = decodeStr.components(separatedBy: "@")
        if mainArr.count > 1 {
            uuid_ = mainArr[0]
            host_ = mainArr[1]
        }

        let uuid_security = uuid_.components(separatedBy: ":")
        if uuid_security.count > 1 {
            profile.encryption = uuid_security[0]
            profile.password = uuid_security[1]
        }

        let host_port = host_.components(separatedBy: ":")
        if host_port.count > 1 {
            profile.address = host_port[0]
            profile.port = Int(host_port[1]) ?? 0
        }
        print("VmessUri self", self)

        // params
        let queryItems = url.queryParams()
        for item in queryItems {
            let value = item.value as? String ?? ""
            switch item.key {
            case "network":
                profile.network = V2rayStreamNetwork(rawValue: value) ?? .tcp
                break
            case "h2path":
                profile.path = value
                break
            case "h2host":
                profile.host = value
                break
            case "aid":
                profile.alterId = Int(value) ?? 0
                break
            case "tls":
                profile.security = V2rayStreamSecurity(rawValue: value) ?? .tls
                break
            case "allowInsecure":
                profile.allowInsecure = value == "1" ? true : false
                break
            case "tlsServer":
                profile.sni = value
                break
            case "sni":
                profile.sni = value
                break
            case "fp":
                profile.fingerprint = V2rayStreamFingerprint(rawValue: value) ?? .none
                break
            case "type":
                profile.headerType = V2rayHeaderType(rawValue: value) ?? .none
                break
            case "alpn":
                profile.alpn = V2rayStreamAlpn(rawValue: value) ?? .none
                break
            case "encryption":
                profile.encryption = value
                break
            case "kcpHeader":
                // type 是所有传输方式的伪装类型
                profile.headerType = V2rayHeaderType(rawValue: value) ?? .none
                break
            case "remark":
                profile.remark = value
                break
            case "serviceName":
                profile.path = value
                break
            case "seed":
                profile.path = value
                break
            default:
                break
            }
        }
    }

    /**
     分享的链接（二维码）格式：vmess://(Base64编码的json格式服务器数据
     json数据如下
     {
     "v": "2",
     "ps": "备注别名",
     "add": "111.111.111.111",
     "port": "32000",
     "id": "1386f85e-657b-4d6e-9d56-78badb75e1fd",
     "aid": "100",
     "net": "tcp",
     "type": "none",
     "host": "www.bbb.com",
     "path": "/",
     "tls": "tls"
     }
     v:配置文件版本号,主要用来识别当前配置
     net ：传输协议（tcp\kcp\ws\h2)
     type:伪装类型（none\http\srtp\utp\wechat-video）
     host：伪装的域名
     1)http host中间逗号(,)隔开
     2)ws host
     3)h2 host
     path:path(ws/h2)
     tls：底层传输安全（tls)
     */
    func parseType2(url: URL) {
        let urlStr = url.absoluteString
        // vmess://
        let base64Begin = urlStr.index(urlStr.startIndex, offsetBy: 8)
        let base64End = urlStr.firstIndex(of: "?")
        let encodedStr = String(urlStr[base64Begin ..< (base64End ?? urlStr.endIndex)])
        guard let decodeStr = encodedStr.base64Decoded() else {
            error = "decode vmess error"
            return
        }
        let jsonData = decodeStr.data(using: String.Encoding.utf8, allowLossyConversion: false)!
        let decoder = JSONDecoder()
        do {
            let vmess = try decoder.decode(VmessShare.self, from: jsonData)
            // 将解析结果赋值到 profile
            profile.remark = vmess.ps.urlDecoded()
            profile.address = vmess.add
            profile.port = Int(vmess.port) ?? 0
            profile.password = vmess.id
            profile.alterId = Int(vmess.aid) ?? 0
            profile.encryption = vmess.scy == "auth" && vmess.security != "auto" ? vmess.security : vmess.scy
            profile.alpn = V2rayStreamAlpn(rawValue: vmess.alpn) ?? .none
            profile.sni = vmess.sni
            profile.network = V2rayStreamNetwork(rawValue: vmess.net) ?? .tcp
            profile.host = vmess.host
            profile.path = vmess.path
            profile.security = V2rayStreamSecurity(rawValue: vmess.tls) ?? .none
            profile.fingerprint = V2rayStreamFingerprint(rawValue: vmess.fp) ?? .none
            profile.headerType = V2rayHeaderType(rawValue: vmess.type) ?? .none

            if profile.network == .grpc {
                profile.path = vmess.serviceName
            }
            if profile.network == .kcp {
                profile.path = vmess.seed
            }
        } catch {
            self.error = error.localizedDescription
            return
        }
    }
}
