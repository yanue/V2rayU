//
//  v2rayStream.swift
//  V2rayU
//
//  Created by yanue on 2018/10/26.
//  Copyright © 2018 yanue. All rights reserved.
//

import Foundation

struct streamSettings: Codable {
    var tcpSettings:tcpSettings?
    var kcpSettings:kcpSettings?
    var wsSettings:wsSettings?
    var httpSettings:httpSettings?
    var dsSettings:dsSettings?
}

struct tcpSettings: Codable {
}

struct kcpSettings: Codable {
}

struct wsSettings: Codable {
}

struct httpSettings: Codable {
}

struct dsSettings: Codable {
}

