//
//  V2rayConfig.swift
//  V2rayU
//
//  Created by yanue on 2018/10/25.
//  Copyright © 2018 yanue. All rights reserved.
//

import Foundation
import SwiftyJSON

class V2rayConfig: NSObject {

    var v2ray: V2rayStruct = V2rayStruct()

    // import by url
    static func importByUrl(jsonUrl: String) {

    }

    func output() {
    }

    func saveByJson(jsonText: String) -> String {
        guard let json = try? JSON(data: jsonText.data(using: String.Encoding.utf8, allowLossyConversion: false)!) else {
            return "invalid json"
        }

        if !json.exists() {
            return "invalid json"
        }

        // get dns data
        if json["dns"].exists() && json["dns"]["servers"].exists() {
            let dnsServers = json["dns"]["servers"].array?.compactMap({ $0.string })
            if ((dnsServers?.count) != nil) {
                self.v2ray.dns?.servers = dnsServers
            }
        }
        var errmsg: String
        if !json["inbound"].exists() {
            return "missing inbound"
        }

        errmsg = self.parseInbound(json: json)
        if errmsg != "" {
            return errmsg
        }

        if !json["outbound"].exists() {
            return "missing outbound"
        }

        errmsg = self.parseOutbound(json: json)
        if errmsg != "" {
            return errmsg
        }

        if !json["routing"].exists() {
            return "missing routing"
        }

        return ""
    }

    // parse inbound from json
    func parseInbound(json: JSON) -> String {
        let jsonParams = json["inbound"]

        var v2rayInbound = V2rayInbound()

        if !(jsonParams["protocol"].exists()) {
            return "missing inbound.protocol"
        }

        if (V2rayProtocolInbound(rawValue: jsonParams["protocol"].stringValue) == nil) {
            return "invalid inbound.protocol"
        }

        // set protocol
        v2rayInbound.protocol = V2rayProtocolInbound(rawValue: jsonParams["protocol"].stringValue)!

        if !jsonParams["port"].exists() {
            return "missing inbound.port"
        }

        if !(jsonParams["port"].intValue > 1024 && jsonParams["port"].intValue < 65535) {
            return "invalid inbound.port"
        }

        // set port
        v2rayInbound.port = String(jsonParams["port"].intValue)

        if jsonParams["listen"].exists() && jsonParams["listen"].stringValue.count > 0 {
            // set listen
            // todo valid
            v2rayInbound.listen = jsonParams["listen"].stringValue
        }

        if jsonParams["tag"].exists() && jsonParams["tag"].stringValue.count > 0 {
            // set tag
            v2rayInbound.tag = jsonParams["tag"].stringValue
        }

        // settings depends on protocol
        if jsonParams["settings"].exists() {

            switch v2rayInbound.protocol {

            case .http:
                var settingHttp = V2rayInboundHttp()

                if jsonParams["settings"]["timeout"].exists() {
                    settingHttp.timeout = jsonParams["settings"]["timeout"].intValue
                }

                if jsonParams["settings"]["allowTransparent"].exists() {
                    settingHttp.allowTransparent = jsonParams["settings"]["allowTransparent"].boolValue
                }

                if jsonParams["settings"]["userLevel"].exists() {
                    settingHttp.userLevel = jsonParams["settings"]["userLevel"].intValue
                }

                // set into inbound
                v2rayInbound.settingHttp = settingHttp
                break

            case .shadowsocks:
                var settingShadowsocks = V2rayInboundShadowsocks()
                settingShadowsocks.email = jsonParams["settings"]["timeout"].stringValue
                settingShadowsocks.password = jsonParams["settings"]["password"].stringValue
                settingShadowsocks.method = jsonParams["settings"]["method"].stringValue
                settingShadowsocks.udp = jsonParams["settings"]["udp"].boolValue
                settingShadowsocks.level = jsonParams["settings"]["level"].intValue
                settingShadowsocks.ota = jsonParams["settings"]["ota"].boolValue

                // set into inbound
                v2rayInbound.settingShadowsocks = settingShadowsocks
                break

            case .socks:
                var settingSocks = V2rayInboundSocks()
                settingSocks.auth = jsonParams["settings"]["auth"].stringValue
                if settingSocks.auth == "password" {
                    // todo
                }
                settingSocks.udp = jsonParams["settings"]["udp"].boolValue
                settingSocks.ip = jsonParams["settings"]["ip"].stringValue
                settingSocks.timeout = jsonParams["settings"]["timeout"].intValue
                settingSocks.userLevel = jsonParams["settings"]["userLevel"].intValue

                // set into inbound
                v2rayInbound.settingSocks = settingSocks
                break

            case .vmess:
                var settingVMess = V2rayInboundVMess()
                settingVMess.disableInsecureEncryption = jsonParams["settings"]["disableInsecureEncryption"].boolValue
                // todo
                // set into inbound
                v2rayInbound.settingVMess = settingVMess
                break
            }
        }

        // stream settings
        // todo
        if jsonParams["streamSettings"].exists() {

        }

        // set into v2ray
        v2ray.inbound = v2rayInbound
        return ""
    }

    // parse inbound from json
    func parseOutbound(json: JSON) -> String {
        let jsonParams = json["outbound"]

        var v2rayOutbound = V2rayOutbound()

        if !(jsonParams["protocol"].exists()) {
            return "missing outbound.protocol"
        }

        if (V2rayProtocolOutbound(rawValue: jsonParams["protocol"].stringValue) == nil) {
            return "invalid outbound.protocol"
        }

        // set protocol
        v2rayOutbound.protocol = V2rayProtocolOutbound(rawValue: jsonParams["protocol"].stringValue)!

        // settings depends on protocol
        if jsonParams["settings"].exists() {
            switch v2rayOutbound.protocol {
            case .blackhole:
                var settingBlackhole = V2rayOutboundBlackhole()
                // todo
                // set into outbound
                v2rayOutbound.settingBlackhole = settingBlackhole
                break
            case .freedom:
                var settingFreedom = V2rayOutboundFreedom()
                // todo
                // set into outbound
                v2rayOutbound.settingFreedom = settingFreedom
                break
            case .shadowsocks:
                var settingShadowsocks = V2rayOutboundShadowsocks()
                // todo
                // set into outbound
                v2rayOutbound.settingShadowsocks = settingShadowsocks
                break
            case .socks:
                var settingSocks = V2rayOutboundSocks()
                // todo
                // set into outbound
                v2rayOutbound.settingSocks = settingSocks
                break
            case .vmess:
                var settingVMess = V2rayOutboundVMess()
                // todo
                // set into outbound
                v2rayOutbound.settingVMess = settingVMess
                break
            }
        }

        // set into v2ray
        v2ray.outbound = v2rayOutbound
        return ""
    }

    // create current v2ray server json file
    static func createJsonFile(item: v2rayItem) {
        let jsonText = item.json

        // path: /Application/V2rayU.app/Contents/Resources/config.json
        guard let jsonFile = V2rayServer.getJsonFile() else {
            NSLog("unable get config file path")
            return
        }

        do {
            let jsonFilePath = URL.init(fileURLWithPath: jsonFile)

            // delete before config
            if FileManager.default.fileExists(atPath: jsonFile) {
                try? FileManager.default.removeItem(at: jsonFilePath)
            }

            try jsonText.write(to: jsonFilePath, atomically: true, encoding: String.Encoding.utf8)
        } catch let error {
            // failed to write file – bad permissions, bad filename, missing permissions, or more likely it can't be converted to the encoding
            NSLog("save json file fail: \(error)")
        }
    }

    func valid() {

    }

    func replaceRegular() {

    }

}
