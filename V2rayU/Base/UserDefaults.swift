//
//  UserDefaults.swift
//  V2rayU
//
//  Created by yanue on 2024/12/25.
//  Copyright © 2024 yanue. All rights reserved.

import Foundation

extension UserDefaults {
    enum KEY: String {
        // v2ray-core version
        case v2rayCoreVersion
        // v2ray-core turn on status
        case v2rayTurnOn
        // v2ray-core log level
        case v2rayLogLevel
        // v2ray dns json txt
        case v2rayDnsJson

        // auth check version
        case autoCheckVersion
        // auto launch after login
        case autoLaunch
        // auto clear logs
        case autoClearLog
        // auto update servers
        case autoUpdateServers
        // auto select Fastest server
        case autoSelectFastestServer
        // pac|manual|global
        case runMode
        // enable Traffic Statistics
        case enableStat

        // base settings
        // http host
        case localHttpHost
        // http port
        case localHttpPort
        // sock host
        case localSockHost
        // sock port
        case localSockPort
        // dns servers
        case dnsServers
        // enable udp
        case enableUdp
        // enable mux
        case enableMux
        // enable Sniffing
        case enableSniffing
        // mux Concurrent
        case muxConcurrent
        // pacPort
        case localPacPort

        // selected routing uuid
        case runningRouting
        // selected profile uuid
        case runningProfile
    }

    static func del(forKey key: KEY) {
        UserDefaults.standard.removeObject(forKey: key.rawValue)
    }
    
    static func setInt(forKey key: KEY, value: Int) {
        UserDefaults.standard.set(value, forKey: key.rawValue)
    }

    static func getInt(forKey key: KEY, defaultValue: Int = 0) -> Int {
        let num = UserDefaults.standard.integer(forKey: key.rawValue)
        if num != 0 {
            return num
        }
        return defaultValue
    }

    static func setBool(forKey key: KEY, value: Bool) {
        UserDefaults.standard.set(value, forKey: key.rawValue)
    }

    static func getBool(forKey key: KEY) -> Bool {
        return UserDefaults.standard.bool(forKey: key.rawValue)
    }

    static func set(forKey key: KEY, value: String) {
        UserDefaults.standard.set(value, forKey: key.rawValue)
    }

    static func get(forKey key: KEY, defaultValue: String = "") -> String {
        let rawValue = UserDefaults.standard.string(forKey: key.rawValue)
        if let value = rawValue, !value.isEmpty {
            return value
        }
        return defaultValue
    }

    // MARK: 获取枚举类型
    static func getEnum<T: RawRepresentable>(forKey key: KEY, type: T.Type, defaultValue: T) -> T where T.RawValue == String {
        guard let rawValue = UserDefaults.standard.string(forKey: key.rawValue),
              let enumValue = T(rawValue: rawValue) else {
            return defaultValue
        }
        return enumValue
    }
}
