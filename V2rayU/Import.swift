//
// Created by yanue on 2018/11/22.
// Copyright (c) 2018 yanue. All rights reserved.
//

import Cocoa
import CoreGraphics
import CoreImage
import SwiftyJSON

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
        }
        if uri.hasPrefix("trojan://") {
            let importUri = ImportUri()
            importUri.importTrojanUri(uri: uri)
            return importUri
        }
        if uri.hasPrefix("vless://") {
            let importUri = ImportUri()
            importUri.importVlessUri(uri: uri)
            return importUri
        }
        if uri.hasPrefix("ss://") {
            let importUri = ImportUri()
            importUri.importSSUri(uri: uri)
            return importUri
        }
        if uri.hasPrefix("ssr://") {
            let importUri = ImportUri()
            importUri.importSSRUri(uri: uri)
            return importUri
        }
        return nil
    }

    static func supportProtocol(uri: String) -> Bool {
        if uri.hasPrefix("ss://") || uri.hasPrefix("ssr://") || uri.hasPrefix("vmess://") || uri.hasPrefix("vless://") || uri.hasPrefix("trojan://") {
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
                error = "invalid ss url"
                return
            }
            // 支持 ss://YWVzLTI1Ni1jZmI6ZjU1LmZ1bi0wNTM1NDAxNkA0NS43OS4xODAuMTExOjExMDc4#翻墙党300.16美国 格式
            if aUri.count > 1 {
                remark = String(aUri[1]).urlDecoded()
            }
        }

        self.uri = uri

        let ss = ShadowsockUri()
        ss.Init(url: url!)
        if ss.error.count > 0 {
            error = ss.error
            isValid = false
            return
        }
        if ss.remark.count > 0 {
            remark = ss.remark
        }

        importSS(ss: ss)
    }

    func importSS(ss: ShadowsockUri) {
        let v2ray = V2rayConfig()
        v2ray.streamNetwork = "tcp" // 必须为tcp
        v2ray.streamSecurity = "none" // ss 必须为 none

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
            isValid = true
            json = v2ray.combineManual()
        } else {
            error = v2ray.error
            isValid = false
        }
    }

    func importSSRUri(uri: String) {
        var url = URL(string: uri)
        if url == nil {
            // 标准url不支持非url-encoded
            let aUri = uri.split(separator: "#")
            url = URL(string: String(aUri[0]))
            if url == nil {
                error = "invalid ssr url"
                return
            }
            if aUri.count > 1 {
                remark = String(aUri[1]).urlDecoded()
            }
        }
        self.uri = uri

        let ssr = ShadowsockRUri()
        ssr.Init(url: url!)
        if ssr.error.count > 0 {
            error = ssr.error
            isValid = false
            return
        }
        if ssr.remark.count > 0 {
            remark = ssr.remark
        }

        importSSR(ssr: ssr)
    }

    func importSSR(ssr: ShadowsockRUri) {
        let v2ray = V2rayConfig()
        v2ray.streamNetwork = "tcp" // 必须为tcp
        v2ray.streamSecurity = "none" // ss 必须为 none

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
            isValid = true
            json = v2ray.combineManual()
        } else {
            error = v2ray.error
            isValid = false
        }
    }

    func importVmessUri(uri: String, id: String = "") {
        var url = URL(string: uri)
        if url == nil {
            // 标准url不支持非url-encoded
            let aUri = uri.split(separator: "#")
            url = URL(string: String(aUri[0]))
            if url == nil {
                error = "invalid vmess url"
                return
            }
            if aUri.count > 1 {
                remark = String(aUri[1]).urlDecoded()
            }
        }

        self.uri = uri

        var vmess = VmessUri()
        vmess.parseType2(url: url!)
        if vmess.error.count > 0 {
            vmess = VmessUri()
            vmess.parseType1(url: url!)
            if vmess.error.count > 0 {
                print("error", vmess.error)
                isValid = false
                error = vmess.error
                return
            }
        }
        if vmess.remark.count > 0 {
            remark = vmess.remark
        }

        importVmess(vmess: vmess)
    }

    func importVmess(vmess: VmessUri) {
        let v2ray = V2rayConfig()

        var vmessItem = V2rayOutboundVMessItem()
        vmessItem.address = vmess.address
        vmessItem.port = vmess.port
        var user = V2rayOutboundVMessUser()
        user.id = vmess.id
        user.alterId = vmess.alterId
        user.security = vmess.security
        vmessItem.users = [user]
        v2ray.serverVmess = vmessItem
        v2ray.serverProtocol = V2rayProtocolOutbound.vmess.rawValue

        // stream
        v2ray.streamNetwork = vmess.network
        v2ray.streamSecurity = vmess.tls
        v2ray.securityTls.allowInsecure = vmess.allowInsecure
        v2ray.securityTls.serverName = vmess.sni

        // tls servername for h2 or ws
        if vmess.sni.count == 0 && (vmess.network == V2rayStreamSettings.network.h2.rawValue || vmess.network == V2rayStreamSettings.network.ws.rawValue) {
            v2ray.securityTls.serverName = vmess.address
        }

        // kcp
        v2ray.streamKcp.header.type = vmess.type
        v2ray.streamKcp.uplinkCapacity = vmess.uplinkCapacity
        v2ray.streamKcp.downlinkCapacity = vmess.downlinkCapacity

        // h2
        if v2ray.streamH2.host.count == 0 {
            v2ray.streamH2.host = [""]
        }
        v2ray.streamH2.host[0] = vmess.netHost
        v2ray.streamH2.path = vmess.netPath

        // ws
        v2ray.streamWs.path = vmess.netPath
        v2ray.streamWs.headers.host = vmess.netHost

        // grpc
        v2ray.streamGrpc.serviceName = vmess.netPath
        v2ray.streamGrpc.multiMode = vmess.type == "multi" // v2rayN

        // tcp
        v2ray.streamTcp.header.type = vmess.type

        // quic
        v2ray.streamQuic.header.type = vmess.type

        // check is valid
        v2ray.checkManualValid()
        if v2ray.isValid {
            isValid = true
            json = v2ray.combineManual()
        } else {
            error = v2ray.error
            isValid = false
        }
    }

    func importVlessUri(uri: String, id: String = "") {
        var url = URL(string: uri)
        if url == nil {
            // 标准url不支持非url-encoded
            let aUri = uri.split(separator: "#")
            url = URL(string: String(aUri[0]))
            if url == nil {
                error = "invalid vless url"
                return
            }
            if aUri.count > 1 {
                remark = String(aUri[1]).urlDecoded()
            }
        }
        self.uri = uri

        let vmess = VlessUri()
        vmess.Init(url: url!)
        if vmess.error.count > 0 {
            error = vmess.error
            isValid = false
            return
        }
        if vmess.remark.count > 0 {
            remark = vmess.remark
        }

        importVless(vmess: vmess)
    }

    func importVless(vmess: VlessUri) {
        let v2ray = V2rayConfig()
        v2ray.serverProtocol = V2rayProtocolOutbound.vless.rawValue

        var vmessItem = V2rayOutboundVLessItem()
        vmessItem.address = vmess.address
        vmessItem.port = vmess.port
        var user = V2rayOutboundVLessUser()
        user.id = vmess.id
        user.flow = vmess.flow
        user.encryption = vmess.encryption
        user.level = vmess.level
        vmessItem.users = [user]
        v2ray.serverVless = vmessItem

        if vmess.sni.count == 0 {
            vmess.sni = vmess.address
        }

        // stream
        v2ray.streamNetwork = vmess.type
        v2ray.streamSecurity = vmess.security
        v2ray.securityTls.serverName = vmess.sni // default tls sni
        v2ray.securityTls.fingerprint = vmess.fp

        if v2ray.streamSecurity == "reality" {
            v2ray.securityReality.publicKey = vmess.pbk
            v2ray.securityReality.fingerprint = vmess.fp
            v2ray.securityReality.shortId = vmess.sid
            v2ray.securityReality.serverName = vmess.sni
        }

        // kcp
        v2ray.streamKcp.header.type = vmess.type

        // h2
        if v2ray.streamH2.host.count == 0 {
            v2ray.streamH2.host = [""]
        }
        v2ray.streamH2.host[0] = vmess.host
        v2ray.streamH2.path = vmess.path

        // ws
        v2ray.streamWs.path = vmess.path
        v2ray.streamWs.headers.host = vmess.host

        // grpc
        v2ray.streamGrpc.serviceName = vmess.path
        v2ray.streamGrpc.multiMode = vmess.type == "multi" // v2rayN

        // tcp
        v2ray.streamTcp.header.type = vmess.type

        // quic
        v2ray.streamQuic.header.type = vmess.type

        // check is valid
        v2ray.checkManualValid()
        if v2ray.isValid {
            isValid = true
            json = v2ray.combineManual()
        } else {
            error = v2ray.error
            isValid = false
        }
    }

    func importTrojanUri(uri: String) {
        var url = URL(string: uri)
        if url == nil {
            // 标准url不支持非url-encoded
            let aUri = uri.split(separator: "#")
            url = URL(string: String(aUri[0]))
            if url == nil {
                error = "invalid trojan url"
                return
            }
            if aUri.count > 1 {
                remark = String(aUri[1]).urlDecoded()
            }
        }
        self.uri = uri

        let trojan = TrojanUri()
        trojan.Init(url: url!)
        if trojan.error.count > 0 {
            error = trojan.error
            isValid = false
            return
        }
        if trojan.remark.count > 0 {
            remark = trojan.remark
        }
        // import
        importTrojan(trojan: trojan)
    }

    func importTrojan(trojan: TrojanUri) {
        let v2ray = V2rayConfig()
        var svr = V2rayOutboundTrojanServer()
        svr.address = trojan.host
        svr.port = trojan.port
        svr.password = trojan.password
        svr.flow = trojan.flow

        v2ray.serverTrojan = svr
        v2ray.enableMux = false
        // tcp
        v2ray.streamNetwork = "tcp"
        v2ray.streamSecurity = trojan.security
        v2ray.securityTls.allowInsecure = true
        v2ray.securityTls.serverName = trojan.sni // default tls sni
        v2ray.securityTls.fingerprint = trojan.fp

        v2ray.serverProtocol = V2rayProtocolOutbound.trojan.rawValue
        // check is valid
        v2ray.checkManualValid()
        if v2ray.isValid {
            isValid = true
            json = v2ray.combineManual()
        } else {
            error = v2ray.error
            isValid = false
        }
    }
}

func importByClash(clash: clashProxy) -> ImportUri? {
    if clash.type == "trojan" {
        // var name: String
        let item = TrojanUri()
        item.remark = clash.name
        item.host = clash.server
        item.port = clash.port
        item.password = clash.password ?? ""
        item.sni = clash.sni ?? clash.server
        item.security = "tls"
        item.fp = clash.fp ?? ""
        let uri = ImportUri()
        uri.remark = clash.name
        uri.importTrojan(trojan: item)
        return uri
    }

    if clash.type == "vmess" {
        let item = VmessUri()
        item.remark = clash.name
        item.address = clash.server
        item.port = clash.port
        item.id = clash.uuid ?? ""
        item.security = clash.cipher ?? "auto"
        item.alterId = Int(clash.alterId ?? 0)
        item.allowInsecure = clash.skipCERTVerify ?? true
        item.network = clash.network ?? "tcp"
        item.sni = clash.sni ?? item.address
        if clash.tls ?? true {
            item.tls = "tls"
        }
        // network ws
        if item.network == "ws" {
            item.netHost = clash.servername ?? clash.server
            item.netPath = "/"
            if clash.wsOpts != nil {
                item.netPath = clash.wsOpts?.path ?? "/"
            }
        }
        // network h2
        if item.network == "h2" {
            item.netHost = clash.servername ?? clash.server
            item.netPath = "/"
            if clash.h2Opts != nil {
                item.netPath = clash.h2Opts?.path ?? "/"
                let h2hosts = clash.h2Opts?.host
                if h2hosts != nil && h2hosts!.count > 0 {
                    item.netHost = h2hosts![0]
                }
            }
        }
        // network grpc
        if item.network == "grpc" {
            item.netHost = clash.servername ?? clash.server
            if clash.grpcOpts != nil {
                item.netPath = clash.grpcOpts?.grpcServiceName ?? "/"
            }
        }
        let uri = ImportUri()
        uri.remark = clash.name
        uri.importVmess(vmess: item)
        return uri
    }

    if clash.type == "vless" {
        let item = VlessUri()
        item.remark = clash.name
        item.address = clash.server
        item.port = clash.port
        item.id = clash.uuid ?? ""
        item.security = clash.cipher ?? "auto"
        item.type = clash.network ?? "tcp"
        item.sni = clash.sni ?? clash.server
        if clash.security == "reality" {
            item.sni = clash.servername ?? clash.server
            item.fp = clash.clientFingerprint ?? "chrome"
            if clash.realityOpts != nil {
                item.pbk = clash.realityOpts!.publicKey ?? ""
                item.sid = clash.realityOpts!.shortId ?? ""
            }
        }
        // network ws
        if item.type == "ws" {
            item.host = clash.servername ?? clash.server
            item.path = "/"
            if clash.wsOpts != nil {
                item.path = clash.wsOpts?.path ?? "/"
            }
        }
        // network h2
        if item.type == "h2" {
            item.host = clash.servername ?? clash.server
            item.path = "/"
            if clash.h2Opts != nil {
                item.path = clash.h2Opts?.path ?? "/"
                let h2hosts = clash.h2Opts?.host
                if h2hosts != nil && h2hosts!.count > 0 {
                    item.host = h2hosts![0]
                }
            }
        }
        // network grpc
        if item.type == "grpc" {
            item.host = clash.servername ?? clash.server
            if clash.grpcOpts != nil {
                item.path = clash.grpcOpts?.grpcServiceName ?? "/"
            }
        }
        let uri = ImportUri()
        uri.remark = clash.name
        uri.importVless(vmess: item)
        return uri
    }

    if clash.type == "http" {
    }

    if clash.type == "socks5" {
    }

    if clash.type == "ss" || clash.type == "ssr" {
        let item = ShadowsockUri()
        item.remark = clash.name
        item.host = clash.server
        item.port = clash.port
        item.method = clash.cipher ?? ""
        item.password = clash.password ?? ""
        let uri = ImportUri()
        uri.remark = clash.name
        uri.importSS(ss: item)
        return uri
    }
    return nil
}

class Scanner {
    // scan from screen
    static func scanQRCodeFromScreen() -> String {
        var displayCount: UInt32 = 0
        var result = CGGetActiveDisplayList(0, nil, &displayCount)
        if Int(result.rawValue) != 0 {
            return ""
        }
        let allocated = Int(displayCount)
        let activeDisplays: UnsafeMutablePointer<UInt32> = UnsafeMutablePointer<CGDirectDisplayID>.allocate(capacity: allocated)

        result = CGGetActiveDisplayList(displayCount, activeDisplays, &displayCount)
        if Int(result.rawValue) != 0 {
            return ""
        }

        var qrStr = ""

        for i in 0 ..< displayCount {
            let str = getQrcodeStr(displayID: activeDisplays[Int(i)])
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
