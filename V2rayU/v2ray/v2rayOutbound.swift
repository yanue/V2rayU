//
//  v2rayOutbound.swift
//  V2rayU
//
//  Created by yanue on 2018/10/26.
//  Copyright © 2018 yanue. All rights reserved.
//

import Foundation

//
struct v2rayOutboundFeedom: Codable {
    var sendThrough:String?
    var `protocol`:v2rayProtocol?
    var tag:String?
    var streamSettings:streamSettings?
    var proxySettings:proxySettings?
    var mux:v2rayOutboundMux?
    
    var settings: v2rayOutboundSettings?
    
}

struct v2rayOutboundVmess: Codable {
    var sendThrough:String?
    var `protocol`:v2rayProtocol?
    var tag:String?
    var streamSettings:streamSettings?
    var proxySettings:proxySettings?
    var mux:v2rayOutboundMux?
    
    var settings:v2rayOutboundSettings?
}

struct v2rayOutboundDetour: Codable {
    var sendThrough:String?
    var `protocol`:v2rayProtocol = .freedom
    var settings:v2rayOutboundSettings?
    var tag:String? = outboundDetourTag
    var streamSettings:streamSettings?
    var proxySettings:proxySettings?
    var Mux:v2rayOutboundMux?
}

// protocol settings
struct v2rayOutboundSettings: Codable {
    // Blackhole
    var blackhole_Response: blackhole_Response?
    
    // Freedom
    var Freedom_domainStrategy: String = "AsIs"// UseIP | AsIs
    var Freedom_redirect: String?
    var Freedom_userLevel: Int = 0

    // Shadowsocks
    var Shadowsocks_servers:[Shadowsocks_servers]?
    
    // Socks
    var Socks_servers:[Socks_servers]?
    
    // Vmess
    var Vmess_vnext:[v2rayOutboundVMess]?
    
    enum CodingKeys: String, CodingKey {
        case blackhole_Response = "response"
        case Freedom_domainStrategy = "domainStrategy"
        case Freedom_redirect = "redirect"
        case Freedom_userLevel = "userLevel"
        case Shadowsocks_servers = "servers"
//        case Socks_servers = "servers"
        case Vmess_vnext = "vnext"
    }
}

struct blackhole_Response: Codable {
    enum type: String,Codable {
        case none
        case http
    }
    var type:type = .none
}

struct Shadowsocks_servers: Codable {
    var email:String?
    var address:String?
    var port:Int?
    var method:String?
    var password:String?
    var ota:Bool? = false
    var level:Int = 0
}

struct v2rayOutboundMux: Codable {
    var enabled:Bool = false
    var concurrency:Int = 8
}

// protocol
// Blackhole
struct v2rayOutboundBlackhole: Codable {
    var address:String?
    var port:String?
    var users:[v2rayOutboundVMessUser]?
}

struct Socks_servers: Codable {
    var address:String?
    var port:String?
    var users:[Socks_servers_users]?
}

struct Socks_servers_users: Codable {
    var user:String?
    var pass:String?
    var level:Int = 0
}

struct v2rayOutboundVMess: Codable {
    var address:String?
    var port:String?
    var users:[v2rayOutboundVMessUser]?
}

struct v2rayOutboundVMessUser: Codable {
    var id:String?
    var alterId:Int? // 0-65535
    var level:Int?
    var security:String? // aes-128-gcm/chacha20-poly1305/auto/none
}
