//
// Created by yanue on 2021/6/5.
// Copyright (c) 2021 yanue. All rights reserved.
//

import Foundation

// see: https://github.com/v2ray/v2ray-core/issues/1139
class VmessUri {

    var error: String = ""
    var remark: String = ""

    var v: String = "2" // version
    var ps: String = "" // remark
    var add: String = "" // address
    var port: String = "" // port
    var id: String = "" // UUID
    var aid: String = "" // alterId
    var net: String = "" // network type: (tcp\kcp\ws\h2\quic\ds\grpc)
    var type: String = "none" // 伪装类型(none\http\srtp\utp\wechat-video) *tcp or kcp or QUIC
    var host: String = "" // host: 1)http(tcp)->host中间逗号(,)隔开,2)ws->host,3)h2->host,4)QUIC->securty
    var path: String = "" // path: 1)ws->path,2)h2->path,3)QUIC->key/Kcp->seed,4)grpc->serviceName
    var tls: String = "tls" //
    var security: String = "auto" // 加密方式(security),没有时值默认auto
    var scy: String = "auto" // 同security
    var alpn: String = "" // h2,http/1.1
    var sni: String = ""
    var fp: String = ""

    // 分享链接
    func encode() -> String {
        var json = JSON()
        json["v"].stringValue = v
        json["ps"].stringValue = ps
        json["add"].stringValue = add
        json["port"].stringValue = port
        json["id"].stringValue = id
        json["aid"].stringValue = aid
        json["net"].stringValue = net
        json["type"].stringValue = type
        json["host"].stringValue = host
        json["path"].stringValue = path
        json["tls"].stringValue = tls
        json["security"].stringValue = security
        json["scy"].stringValue = scy
        json["alpn"].stringValue = alpn
        json["sni"].stringValue = sni
        json["fp"].stringValue = fp

        let encoder = JSONEncoder()
        if let data = try? encoder.encode(self.share) {
            let uri = String(data: data, encoding: .utf8)!
            return "vmess://" + uri.base64Encoded()!
        } else {
            self.error = "encode uri error"
        }
    }

    func parse(url: URL) -> Error? {
        // 先尝试解析类型2
        self.parseType2(url: url)
        if self.error.count > 0 {
            // 再尝试解析类型1
            self.parseType1(url: url)
        }
        if self.error.count > 0 {
            return NSError(domain: "VlessUriError", code: 1001, userInfo: [NSLocalizedDescriptionKey: vmess.error])
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
        let encodedStr = String(urlStr[base64Begin..<(base64End ?? urlStr.endIndex)])

        var paramsStr: String = ""
        if base64End != nil {
            let paramsAll = urlStr.components(separatedBy: "?")
            paramsStr = paramsAll[1]
        }

        guard let decodeStr = encodedStr.base64Decoded() else {
            self.error = "error decode Str"
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
            self.security = uuid_security[0]
            self.id = uuid_security[1]
        }

        let host_port = host_.components(separatedBy: ":")
        if host_port.count > 1 {
            self.address = host_port[0]
            self.port = Int(host_port[1]) ?? 0
        }
        print("VmessUri self", self)

        // params
        let params = paramsStr.components(separatedBy: "&")
        for item in params {
            let param = item.components(separatedBy: "=")
            if param.count < 2 {
                continue
            }
            switch param[0] {
            case "network":
                self.profile.network = param[1]
                break
            case "h2path":
                self.profile.path = param[1]
                break
            case "h2host":
                self.profile.host = param[1]
                break
            case "aid":
                self.profile.alterId = Int(param[1]) ?? 0
                break
            case "tls":
                self.profile.security = param[1] == "1" ? "tls" : "none"
                break
            case "allowInsecure":
                self.profile.allowInsecure = param[1] == "1" ? true : false
                break
            case "tlsServer":
                self.profile.sni = param[1]
                break
            case "sni":
                self.profile.sni = param[1]
                break
            case "fp":
                self.profile.fp = param[1]
                break
            case "type":
                self.profile.headerType = param[1]
                break
            case "alpn":
                self.profile.alpn = param[1]
                break
            case "encryption":
                self.profile.encryption = param[1]
                break
            case "kcpHeader":
                // type 是所有传输方式的伪装类型
                self.profile.headerType = param[1]
                break
            case "remark":
                self.remark = param[1].urlDecoded()
                break
            case "serviceName":
                self.profile.path = param[1]
                break
            case "seed":
                self.profile.path = param[1]
                break
            default:
                break
            }
        }
    }

    /**s
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
        let encodedStr = String(urlStr[base64Begin..<(base64End ?? urlStr.endIndex)])
        guard let decodeStr = encodedStr.base64Decoded() else {
            self.error = "decode vmess error"
            return
        }

        guard let json = try? JSON(data: decodeStr.data(using: String.Encoding.utf8, allowLossyConversion: false)!) else {
            self.error = "invalid json"
            return
        }

        if !json.exists() {
            self.error = "invalid json"
            return
        }

        self.profile.remark = json["ps"].stringValue.urlDecoded()
        self.profile.address = json["add"].stringValue
        self.profile.port = json["port"].intValue
        self.profile.password = json["id"].stringValue
        self.profile.alterId = json["aid"].intValue
        self.profile.encryption = json["security"].stringValue
        if self.profile.encryption.count == 0 {
            self.profile.encryption = json["scy"].stringValue
        }
        if self.profile.encryption.count == 0 {
            self.profile.encryption = "auto"
        }
        self.profile.alpn = json["alpn"].stringValue
        self.profile.sni = json["sni"].stringValue
        self.profile.network = json["net"].stringValue
        self.profile.host = json["host"].stringValue
        self.profile.path = json["path"].stringValue
        self.profile.security = json["tls"].stringValue
        self.profile.fp = json["fp"].stringValue
        // type:伪装类型（none\http\srtp\utp\wechat-video）
        self.profile.headerType = json["type"].stringValue
        if self.profile.headerType.count == 0 {
            self.profile.headerType = "none"
        }
        if self.profile.network == "grpc" {
            self.profile.path = json["serviceName"].stringValue
        }
        if self.profile.network == "kcp" {
            self.profile.path = json["seed"].stringValue
        }
    }
}
