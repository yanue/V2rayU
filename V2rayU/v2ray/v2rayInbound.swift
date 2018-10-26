//
//  v2rayInbound.swift
//  V2rayU
//
//  Created by yanue on 2018/10/26.
//  Copyright © 2018 yanue. All rights reserved.
//

import Foundation

// Inbound
struct v2rayInbound: Codable  {
    var port:String = "1080"
    var listen:String = "127.0.0.1"
    var `protocol`:v2rayProtocol = .socks
    var tag:String? = ""
    var streamSettings:v2rayStreamSettings?
    var sniffing:v2rayInboundSniffing?
    var settingHttp:v2rayInboundHttp?
    var settingSocks:v2rayInboundSock?
    var settingShadowsocks:v2rayInboundShandowsocks?
    var settingVmess:v2rayInboundVmess?

    enum CodingKeys: String, CodingKey {
        case port
        case listen
        case `protocol`
        case tag
        case streamSettings
        case sniffing
        case settings // auto switch
    }
}

extension v2rayInbound {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        port = try container.decode(String.self, forKey: CodingKeys.port)
        listen = try container.decode(String.self, forKey: CodingKeys.listen)
        `protocol` = try container.decode(v2rayProtocol.self, forKey: CodingKeys.`protocol`)
        tag = try container.decode(String.self, forKey: CodingKeys.tag)
       
        // ignore nil
        if try !container.decodeNil(forKey: .streamSettings) {
            streamSettings = try container.decode(v2rayStreamSettings.self, forKey: CodingKeys.streamSettings)
        }
        
        // ignore nil
        if try !container.decodeNil(forKey: .sniffing) {
            sniffing = try container.decode(v2rayInboundSniffing.self, forKey: CodingKeys.sniffing)
        }
    
        // decode settings depends on `protocol`
        switch `protocol` {
            case .http:
                settingHttp = try container.decode(v2rayInboundHttp.self, forKey: CodingKeys.settings)
                break
            case .shadowsocks:
                settingShadowsocks = try container.decode(v2rayInboundShandowsocks.self, forKey: CodingKeys.settings)
                break
            case .socks:
                settingSocks = try container.decode(v2rayInboundSock.self, forKey: CodingKeys.settings)
                break
            case .vmess:
                settingVmess = try container.decode(v2rayInboundVmess.self, forKey: CodingKeys.settings)
                break
            case .blackhole:
                break
            case .dokodemoDoor:
                break
            case .freedom:
                break
            case .mtproto:
                break
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(port, forKey: .port)
        try container.encode(listen, forKey: .listen)
        try container.encode(`protocol`, forKey: .`protocol`)
        try container.encode(tag, forKey: .tag)
        
        // ignore nil
        if streamSettings != nil {
            try container.encode(streamSettings, forKey: .streamSettings)
        }
        
        // ignore nil
        if sniffing != nil {
            try container.encode(sniffing, forKey: .sniffing)
        }
        
        // encode settings depends on `protocol`
        switch `protocol` {
            case v2rayProtocol.http:
                try container.encode(self.settingHttp, forKey: .settings)
                break
            case .shadowsocks:
                try container.encode(self.settingShadowsocks, forKey: .settings)
                break
            case .socks:
                try container.encode(self.settingSocks, forKey: .settings)
                break
            case .vmess:
                try container.encode(self.settingVmess, forKey: .settings)
                break
            case .blackhole:
                break
            case .dokodemoDoor:
                break
            case .freedom:
                break
            case .mtproto:
                break
        }
    
    }
}

struct v2rayStreamSettings: Codable {
}

struct v2rayInboundDetour: Codable {
    var port:String = "1087"
    var listen:String = "127.0.0.1"
    var `protocol`:v2rayProtocol = .http
    var tag:String?
//    var settings:v2rayInboundSettings?
//    var streamSettings:v2rayInboundSettings?
    var sniffing:v2rayInboundSniffing?
    var allocate:v2rayInboundDetourAllocate?
}

struct v2rayInboundDetourAllocate: Codable {
    enum strategy:String,Codable {
        case always
        case random
    }
    var strategy:strategy = .always // always or random
    var refresh:Int = 2 // val is 2-5 where strategy = random
    var concurrency:Int = 3 // suggest 3, min 1
}

struct v2rayInboundSniffing: Codable {
    enum dest:String,Codable {
        case tls
        case http
    }
    var enabled:Bool = false
    var destOverride:[dest] = [.tls,.http]
}

struct proxySettings: Codable {
    var Tag: String?
}

struct v2rayInboundHttp: Codable {
    var timeout:Int?
    var allowTransparent:Bool = false
    var userLevel:Int = 0
}

struct v2rayInboundShandowsocks: Codable {
    enum auth:String,Codable {
        case noauth
        case password
    }
    var auth:auth = .noauth
    var udp:Bool = true
    var userLevel:Int = 0
    var timeout:Int? // 默认300
    var accounts:[v2rayInboundShandowsockAccount]?
}

struct v2rayInboundShandowsockAccount: Codable {
    var user:String?
    var pass:String?
}

struct v2rayInboundSock: Codable {
    enum auth:String,Codable {
        case noauth
        case password
    }
    
    var auth:auth = .noauth
    var accounts:[v2rayInboundSockAccount]?
    var udp:Bool?
    var ip:String?
    var timeout:Int?
    var userLevel:Int?
}

struct v2rayInboundSockAccount: Codable {
    var user:String?
    var pass:String?
}

struct v2rayInboundVmess: Codable {
    var user:String?
    var pass:String?
}
