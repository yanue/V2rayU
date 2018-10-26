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
    var settings:v2rayInboundSettings?
    var streamSettings:v2rayInboundSettings?
    var sniffing:v2rayInboundSniffing?
}

struct v2rayInboundDetour: Codable {
    var port:String = "1087"
    var listen:String = "127.0.0.1"
    var `protocol`:v2rayProtocol = .http
    var tag:String?
    var settings:v2rayInboundSettings?
    var streamSettings:v2rayInboundSettings?
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

struct v2rayInboundSettings: Codable {
    // protocol
    var v2rayInboundHttp:v2rayInboundHttp?
    var v2rayProtocolShandowsock:v2rayProtocolShandowsock?
    var v2rayInboundSock:v2rayInboundSock?
}

struct v2rayInboundHttp: Codable {
    var timeout:Int?
    var allowTransparent:Bool = false
    var userLevel:Int = 0
}


struct v2rayProtocolShandowsock: Codable {
    enum auth:String,Codable {
        case noauth
        case password
    }
    var auth:auth = .noauth
    var udp:Bool = true
    var userLevel:Int = 0
    var timeout:Int? // 默认300
    var accounts:[v2rayProtocolShandowsockAccount]?
}

struct v2rayProtocolShandowsockAccount: Codable {
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
