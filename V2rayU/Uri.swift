//
// Created by yanue on 2021/6/5.
// Copyright (c) 2021 yanue. All rights reserved.
//

import Foundation
import SwiftyJSON

// see: https://github.com/v2ray/v2ray-core/issues/1139
class VmessUri {
    var error: String = ""
    var remark: String = ""

    var address: String = ""
    var port: Int = 8379
    var id: String = ""
    var alterId: Int = 0
    var security: String = "aes-128-gcm"

    var network: String = "tcp"
    var netHost: String = ""
    var netPath: String = ""
    var tls: String = ""
    var type: String = "none"
    var uplinkCapacity: Int = 50
    var downlinkCapacity: Int = 20
    var allowInsecure: Bool = false
    var tlsServer: String = ""
    var mux: Bool = true
    var muxConcurrency: Int = 8

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
    mux - 是否启用 mux，为 0 或 1
    muxConcurrency - mux 的 最大并发连接数
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
            var param = item.components(separatedBy: "=")
            switch param[0] {
            case "network":
                self.network = param[1]
                break
            case "h2path":
                self.netPath = param[1]
                break
            case "h2host":
                self.netHost = param[1]
                break
            case "aid":
                self.alterId = Int(param[1]) ?? 0
                break
            case "tls":
                self.tls = param[1] == "1" ? "tls" : "none"
                break
            case "allowInsecure":
                self.allowInsecure = param[1] == "1" ? true : false
                break
            case "tlsServer":
                self.tlsServer = param[1]
                break
            case "mux":
                self.mux = param[1] == "1" ? true : false
                break
            case "muxConcurrency":
                self.muxConcurrency = Int(param[1]) ?? 8
                break
            case "kcpHeader":
                // type 是所有传输方式的伪装类型
                self.type = param[1]
                break
            case "uplinkCapacity":
                self.uplinkCapacity = Int(param[1]) ?? 50
                break
            case "downlinkCapacity":
                self.downlinkCapacity = Int(param[1]) ?? 20
                break
            case "remark":
                self.remark = param[1].urlDecoded()
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

        self.remark = json["ps"].stringValue
        self.address = json["add"].stringValue
        self.port = json["port"].intValue
        self.id = json["id"].stringValue
        self.alterId = json["aid"].intValue
        self.network = json["net"].stringValue
        self.netHost = json["host"].stringValue
        self.netPath = json["path"].stringValue
        self.tls = json["tls"].stringValue
        // type:伪装类型（none\http\srtp\utp\wechat-video）
        self.type = json["type"].stringValue
        print("json", json)
    }
}

// link: https://github.com/shadowsocks/ShadowsocksX-NG
// file: ServerProfile.swift
class ShadowsockUri {
    var host: String = ""
    var port: Int = 8379
    var method: String = "aes-128-gcm"
    var password: String = ""
    var remark: String = ""

    var error: String = ""

    // ss://bf-cfb:test@192.168.100.1:8888#remark
    func encode() -> String {
        let base64 = self.method + ":" + self.password + "@" + self.host + ":" + String(self.port)
        let ss = base64.base64Encoded()
        if ss != nil {
            return "ss://" + ss! + "#" + self.remark
        }
        self.error = "encode base64 fail"
        return ""
    }

    func Init(url: URL) {
        let (_decodedUrl, _tag) = self.decodeUrl(url: url)
        guard let decodedUrl = _decodedUrl else {
            self.error = "error: decodeUrl"
            return
        }
        guard let parsedUrl = URLComponents(string: decodedUrl) else {
            self.error = "error: parsedUrl"
            return
        }
        guard let host = parsedUrl.host else {
            self.error = "error:missing host"
            return
        }
        guard let port = parsedUrl.port else {
            self.error = "error:missing port"
            return
        }
        guard let user = parsedUrl.user else {
            self.error = "error:missing user"
            return
        }

        self.host = host
        self.port = Int(port)

        // This can be overriden by the fragment part of SIP002 URL
        self.remark = parsedUrl.queryItems?.filter({ $0.name == "Remark" }).first?.value ?? ""

        if let password = parsedUrl.password {
            self.method = user.lowercased()
            self.password = password
            if let tag = _tag {
                remark = tag
            }
        } else {
            // SIP002 URL have no password section
            guard let data = Data(base64Encoded: self.padBase64(string: user)), let userInfo = String(data: data, encoding: .utf8) else {
                self.error = "URL: have no password section"
                return
            }

            let parts = userInfo.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
            if parts.count != 2 {
                self.error = "error:url userInfo"
                return
            }

            self.method = String(parts[0]).lowercased()
            self.password = String(parts[1])

            // SIP002 defines where to put the profile name
            if let profileName = parsedUrl.fragment {
                self.remark = profileName
            }
        }
    }

    func decodeUrl(url: URL) -> (String?, String?) {
        let urlStr = url.absoluteString
        let base64Begin = urlStr.index(urlStr.startIndex, offsetBy: 5)
        let base64End = urlStr.firstIndex(of: "#")
        let encodedStr = String(urlStr[base64Begin..<(base64End ?? urlStr.endIndex)])

        guard let decoded = encodedStr.base64Decoded() else {
            self.error = "decode ss error"
            return (url.absoluteString, nil)
        }

        let s = decoded.trimmingCharacters(in: .whitespacesAndNewlines)

        if let index = base64End {
            let i = urlStr.index(index, offsetBy: 1)
            let fragment = String(urlStr[i...]).removingPercentEncoding
            return ("ss://\(s)", fragment)
        }
        return ("ss://\(s)", nil)
    }

    func padBase64(string: String) -> String {
        var length = string.utf8.count
        if length % 4 == 0 {
            return string
        } else {
            length = 4 - length % 4 + length
            return string.padding(toLength: length, withPad: "=", startingAt: 0)
        }
    }
}

// link: https://coderschool.cn/2498.html
class ShadowsockRUri: ShadowsockUri {

    override func Init(url: URL) {
        let (_decodedUrl, _tag) = self.decodeUrl(url: url)
        guard let decodedUrl = _decodedUrl else {
            self.error = "error: decodeUrl"
            return
        }

        let parts: Array<Substring> = decodedUrl.split(separator: ":")
        if parts.count != 6 {
            self.error = "error:url"
            return
        }

        let host: String = String(parts[0])
        let port = String(parts[1])
        let method = String(parts[3])
        let passwordBase64 = String(parts[5])

        self.host = host
        if let aPort = Int(port) {
            self.port = aPort
        }

        self.method = method.lowercased()
        if let tag = _tag {
            self.remark = tag
        }

        guard let data = Data(base64Encoded: self.padBase64(string: passwordBase64)), let password = String(data: data, encoding: .utf8) else {
            self.error = "URL: password decode error"
            return
        }
        self.password = password
    }

    override func decodeUrl(url: URL) -> (String?, String?) {
        let urlStr = url.absoluteString
        // remove left ssr://
        let base64Begin = urlStr.index(urlStr.startIndex, offsetBy: 6)
        let encodedStr = String(urlStr[base64Begin...])

        guard let decoded = encodedStr.base64Decoded() else {
            self.error = "decode ssr error"
            return (url.absoluteString, nil)
        }

        let raw = decoded.trimmingCharacters(in: .whitespacesAndNewlines)

        let sep = raw.range(of: "/?")
        let s = String(raw[..<(sep?.lowerBound ?? raw.endIndex)])
        if let iBeg = raw.range(of: "remarks=")?.upperBound {
            let fragment = String(raw[iBeg...])
            let iEnd = fragment.firstIndex(of: "&")
            let aRemarks = String(fragment[..<(iEnd ?? fragment.endIndex)])
            guard let tag = aRemarks.base64Decoded() else {
                return (s, aRemarks)
            }
            return (s, tag)
        }

        return (s, nil)
    }
}

// trojan
class TrojanUri {
    var host: String = ""
    var port: Int = 443
    var password: String = ""
    var remark: String = ""

    var error: String = ""

    // trojan://password@remote_host:remote_port
    func encode() -> String {
        let uri = self.password + "@" + self.host + ":" + String(self.port)
        return "trojan://" + uri + "#" + self.remark
    }

    func Init(url: URL) {
        guard let host = url.host else {
            self.error = "error:missing host"
            return
        }
        guard let port = url.port else {
            self.error = "error:missing port"
            return
        }
        guard let password = url.user else {
            self.error = "error:missing password"
            return
        }
        self.host = host
        self.port = Int(port)
        self.password = password
        self.remark = url.fragment ?? "trojan"
    }
}
