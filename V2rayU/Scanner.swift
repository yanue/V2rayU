//
// Created by yanue on 2018/11/22.
// Copyright (c) 2018 yanue. All rights reserved.
//

import Cocoa
import CoreGraphics
import CoreImage
import SwiftyJSON

struct VmessShare: Codable {
    var v: String = "2"
    var ps: String = ""
    var add: String = ""
    var port: String = ""
    var id: String = ""
    var aid: String = ""
    var net: String = ""
    var type: String = "none"
    var host: String = ""
    var path: String = ""
    var tls: String = "none"
}

class ShareUri {
    var error = ""
    var remark = ""
    var uri: String = ""
    var v2ray = V2rayConfig()
    var share = VmessShare()

    func qrcode(item: V2rayItem) {
        v2ray.parseJson(jsonText: item.json)
        if !v2ray.isValid {
            self.error = v2ray.errors[0]
            return
        }

        self.remark = item.remark

        if v2ray.serverProtocol == V2rayProtocolOutbound.vmess.rawValue {
            self.genVmessUri()

            let encoder = JSONEncoder()
            if let data = try? encoder.encode(self.share) {
                let uri = String(data: data, encoding: .utf8)!
                self.uri = "vmess://" + uri.base64Encoded()!
            } else {
                self.error = "encode uri error"
            }
            return
        }

        if v2ray.serverProtocol == V2rayProtocolOutbound.shadowsocks.rawValue {
            self.genShadowsocksUri()
            return
        }

        self.error = "not support"
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
    private func genVmessUri() {
        self.share.add = self.v2ray.serverVmess.address
        self.share.ps = self.remark
        self.share.port = String(self.v2ray.serverVmess.port)
        self.share.id = self.v2ray.serverVmess.users[0].id
        self.share.aid = String(self.v2ray.serverVmess.users[0].alterId)
        self.share.net = self.v2ray.streamNetwork

        if self.v2ray.streamNetwork == "h2" {
            self.share.host = self.v2ray.streamH2.host[0]
            self.share.path = self.v2ray.streamH2.path
        }

        if self.v2ray.streamNetwork == "ws" {
            self.share.host = self.v2ray.streamWs.headers.host
            self.share.path = self.v2ray.streamWs.path
        }

        self.share.tls = self.v2ray.streamTlsSecurity
    }

    // Shadowsocks
    func genShadowsocksUri() {
        let ss = ShadowsockUri()
        ss.host = self.v2ray.serverShadowsocks.address
        ss.port = self.v2ray.serverShadowsocks.port
        ss.password = self.v2ray.serverShadowsocks.password
        ss.method = self.v2ray.serverShadowsocks.method
        ss.remark = self.remark
        self.uri = ss.encode()
        self.error = ss.error
    }
}

class ImportUri {
    var isValid: Bool = false
    var json: String = ""
    var remark: String = ""
    var error: String = ""
    var uri: String = ""

    static func importUri(uri: String, id: String = "", checkExist: Bool = true) -> ImportUri? {
        if checkExist && V2rayServer.exist(url: uri) {
            let importUri = ImportUri()
            importUri.isValid = false
            importUri.error = "Url already exists"
            return importUri
        }

        if uri.hasPrefix("vmess://") {
            let importUri = ImportUri()
            importUri.importVmessUri(uri: uri, id: id)
            return importUri
        } else if uri.hasPrefix("ss://") {
            let importUri = ImportUri()
            importUri.importSSUri(uri: uri)
            return importUri
        } else if uri.hasPrefix("ssr://") {
            let importUri = ImportUri()
            importUri.importSSRUri(uri: uri)
            return importUri
        }
        return nil
    }

    static func supportProtocol(uri: String) -> Bool {
        if uri.hasPrefix("ss://") || uri.hasPrefix("ssr://") || uri.hasPrefix("vmess://") {
            return true
        }
        return false
    }

    func importSSUri(uri: String) {
        var url = URL(string: uri)
        if url == nil {
            let aUri = uri.split(separator: "#")
            url = URL(string: String(aUri[0]))
            if url == nil {
                self.error = "invalid ss url"
                return
            }
            // 支持 ss://YWVzLTI1Ni1jZmI6ZjU1LmZ1bi0wNTM1NDAxNkA0NS43OS4xODAuMTExOjExMDc4#翻墙党300.16美国 格式
            self.remark = String(aUri[1])
        }

        self.uri = uri

        let ss = ShadowsockUri()
        ss.Init(url: url!)
        if ss.error.count > 0 {
            self.error = ss.error
            self.isValid = false
            return
        }
        if ss.remark.count > 0 {
            self.remark = ss.remark
        }

        let v2ray = V2rayConfig()
        var ssServer = V2rayOutboundShadowsockServer()
        ssServer.address = ss.host
        ssServer.port = ss.port
        ssServer.password = ss.password
        ssServer.method = ss.method
        v2ray.serverShadowsocks = ssServer
        v2ray.enableMux = false
        v2ray.serverProtocol = V2rayProtocolOutbound.shadowsocks.rawValue
        // check is valid
        v2ray.checkManualValid()
        if v2ray.isValid {
            self.isValid = true
            self.json = v2ray.combineManual()
        } else {
            self.error = v2ray.error
            self.isValid = false
        }
    }

    func importSSRUri(uri: String) {
        if URL(string: uri) == nil {
            self.error = "invalid ssr url"
            return
        }
        self.uri = uri

        let ssr = ShadowsockRUri()
        ssr.Init(url: URL(string: uri)!)
        if ssr.error.count > 0 {
            self.error = ssr.error
            self.isValid = false
            return
        }
        self.remark = ssr.remark

        let v2ray = V2rayConfig()
        var ssServer = V2rayOutboundShadowsockServer()
        ssServer.address = ssr.host
        ssServer.port = ssr.port
        ssServer.password = ssr.password
        ssServer.method = ssr.method
        v2ray.serverShadowsocks = ssServer
        v2ray.enableMux = false
        v2ray.serverProtocol = V2rayProtocolOutbound.shadowsocks.rawValue
        // check is valid
        v2ray.checkManualValid()
        if v2ray.isValid {
            self.isValid = true
            self.json = v2ray.combineManual()
        } else {
            self.error = v2ray.error
            self.isValid = false
        }
    }

    func importVmessUri(uri: String, id: String = "") {
        if URL(string: uri) == nil {
            self.error = "invalid vmess url"
            return
        }

        self.uri = uri

        var vmess = VmessUri()
        vmess.parseType2(url: URL(string: uri)!)
        if vmess.error.count > 0 {
            vmess = VmessUri()
            vmess.parseType1(url: URL(string: uri)!)
            if vmess.error.count > 0 {
                print("error", vmess.error)
                self.isValid = false;
                self.error = vmess.error
                return
            }
        }
        self.remark = vmess.remark

        let v2ray = V2rayConfig()

        var vmessItem = V2rayOutboundVMessItem()
        vmessItem.address = vmess.address
        vmessItem.port = vmess.port
        var user = V2rayOutboundVMessUser()
        if id.count > 0 {
//            vmess.id = id
        }
        user.id = vmess.id
        user.alterId = vmess.alterId
        user.security = vmess.security
        vmessItem.users = [user]
        v2ray.serverVmess = vmessItem
        v2ray.serverProtocol = V2rayProtocolOutbound.vmess.rawValue

        // stream
        v2ray.streamNetwork = vmess.network
        v2ray.streamTlsAllowInsecure = vmess.allowInsecure
        v2ray.streamTlsSecurity = vmess.tls
        v2ray.streamTlsServerName = vmess.tlsServer

        // tls servername for h2 or ws
        if vmess.tlsServer.count == 0 && (vmess.network == V2rayStreamSettings.network.h2.rawValue || vmess.network == V2rayStreamSettings.network.ws.rawValue) {
            v2ray.streamTlsServerName = vmess.netHost
        }

        // kcp
        v2ray.streamKcp.header.type = vmess.type
        v2ray.streamKcp.uplinkCapacity = vmess.uplinkCapacity
        v2ray.streamKcp.downlinkCapacity = vmess.downlinkCapacity

        // h2
        v2ray.streamH2.host[0] = vmess.netHost
        v2ray.streamH2.path = vmess.netPath

        // ws
        v2ray.streamWs.path = vmess.netPath
        v2ray.streamWs.headers.host = vmess.netHost

        // tcp
        v2ray.streamTcp.header.type = vmess.type

        // quic
        v2ray.streamQuic.header.type = vmess.type

        // check is valid
        v2ray.checkManualValid()
        if v2ray.isValid {
            self.isValid = true
            self.json = v2ray.combineManual()
        } else {
            self.error = v2ray.error
            self.isValid = false
        }
    }
}

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
    var allowInsecure: Bool = true
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

class Scanner {

    // scan from screen
    static func scanQRCodeFromScreen() -> String {
        var displayCount: UInt32 = 0;
        var result = CGGetActiveDisplayList(0, nil, &displayCount)
        if (Int(result.rawValue) != 0) {
            return ""
        }
        let allocated = Int(displayCount)
        let activeDisplays: UnsafeMutablePointer<UInt32> = UnsafeMutablePointer<CGDirectDisplayID>.allocate(capacity: allocated)

        result = CGGetActiveDisplayList(displayCount, activeDisplays, &displayCount)
        if (Int(result.rawValue) != 0) {
            return ""
        }

        var qrStr = ""

        for i in 0..<displayCount {
            let str = self.getQrcodeStr(displayID: activeDisplays[Int(i)])
            // support: ss:// | ssr:// | vmess://
            if ImportUri.supportProtocol(uri: str) {
                qrStr = str
                break
            }
        }

        activeDisplays.deallocate()

        return qrStr
    }

    private static func getQrcodeStr(displayID: CGDirectDisplayID) -> String {
        guard let qrcodeImg = CGDisplayCreateImage(displayID) else {
            return ""
        }

        let detector: CIDetector = CIDetector(ofType: CIDetectorTypeQRCode, context: nil, options: [CIDetectorAccuracy: CIDetectorAccuracyHigh])!
        let ciImage: CIImage = CIImage(cgImage: qrcodeImg)
        let features = detector.features(in: ciImage)

        var qrCodeLink = ""

        for feature in features as! [CIQRCodeFeature] {
            qrCodeLink += feature.messageString ?? ""
        }

        return qrCodeLink
    }
}
