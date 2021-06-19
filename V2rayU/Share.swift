//
// Created by yanue on 2021/6/5.
// Copyright (c) 2021 yanue. All rights reserved.
//

import Foundation
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
            self.error = v2ray.errors.count > 0 ? v2ray.errors[0] : ""
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

        if v2ray.serverProtocol == V2rayProtocolOutbound.vless.rawValue {
            self.genVlessUri()
            return
        }

        if v2ray.serverProtocol == V2rayProtocolOutbound.shadowsocks.rawValue {
            self.genShadowsocksUri()
            return
        }

        if v2ray.serverProtocol == V2rayProtocolOutbound.trojan.rawValue {
            self.genTrojanUri()
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
        if self.v2ray.serverVmess.users.count > 0 {
            self.share.id = self.v2ray.serverVmess.users[0].id
            self.share.aid = String(self.v2ray.serverVmess.users[0].alterId)
        }
        self.share.net = self.v2ray.streamNetwork

        if self.v2ray.streamNetwork == "h2" {
            if self.v2ray.streamH2.host.count > 0 {
                self.share.host = self.v2ray.streamH2.host[0]
            }
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

    // trojan
    func genTrojanUri() {
        let ss = TrojanUri()
        ss.host = self.v2ray.serverTrojan.address
        ss.port = self.v2ray.serverTrojan.port
        ss.password = self.v2ray.serverTrojan.password
        ss.remark = self.remark
        self.uri = ss.encode()
        self.error = ss.error
    }

    func genVlessUri() {
        let ss = VlessUri()
        ss.address = self.v2ray.serverVless.address
        ss.port = self.v2ray.serverVless.port

        if self.v2ray.serverVless.users.count > 0 {
            ss.id = self.v2ray.serverVless.users[0].id
            ss.level = self.v2ray.serverVless.users[0].level
            ss.flow = self.v2ray.serverVless.users[0].flow
            ss.encryption = self.v2ray.serverVless.users[0].encryption
        }
        ss.remark = self.remark

        ss.security = self.v2ray.streamTlsSecurity
        ss.host = self.v2ray.streamXtlsServerName

        ss.type = self.v2ray.streamNetwork

        if self.v2ray.streamNetwork == "h2" {
            if self.v2ray.streamH2.host.count > 0 {
                ss.host = self.v2ray.streamH2.host[0]
            }
            ss.path = self.v2ray.streamH2.path
        }

        if self.v2ray.streamNetwork == "ws" {
            ss.host = self.v2ray.streamWs.headers.host
            ss.path = self.v2ray.streamWs.path
        }

        self.uri = ss.encode()
        self.error = ss.error
    }

}