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
        // last run mode before turning off
        case lastRunMode
        // enable Traffic Statistics
        case enableStat
        // show speed in menu bar
        case showSpeedOnTray
        // show latency in menu bar
        case showLatencyOnTray
        // show country flag icon
        case showCountryFlag
        // base settings
        // allowLAN
        case allowLAN
        // http port
        case localHttpPort
        // sock port
        case localSockPort
        // mixed http+socks port
        case mixedPort
        // enable mixed http+socks port
        case enableMixedPort
        // pac Port
        case localPacPort
        // dns servers
        case dnsServers
        // dns basic settings
        case dnsDirect
        case dnsRemote
        case dnsBootstrap
        case dnsDirectStrategy
        case dnsProxyStrategy
        // enable udp
        case enableUdp
        // enable mux
        case enableMux
        // enable Sniffing
        case enableSniffing
        // mux Concurrent
        case muxConcurrent
        // gfwPacListUrl
        case gfwPacListUrl
        // capability rules remote base url
        case capabilityRulesBaseURL

        // MARK: - Test settings
        case latencyTestConcurrency
        case pingTestURL
        case udpTestURL
        case currentConnectionTestURL

        // selected routing uuid
        case runningRouting
        // selected profile uuid
        case runningProfile
        // selected combined config uuid
        case runningCombination

        // MARK: - TUN settings
        // tun interface address
        case tunAddress
        // tun mtu
        case tunMtu
        // tun stack (system/gvisor/mixed)
        case tunStack
        // tun default dns server
        case tunDnsDefault
        // tun china dns server
        case tunDnsChina
        // tun fakeip range
        case tunFakeipRange
        // tun strict_route (强制路由), 默认开启; 网络切换异常时可关闭
        case tunStrictRoute
        // tun 自动重建: 网络变化/唤醒后自动重建 TUN, 默认开启
        case tunAutoRebuild

        // sing-box dns json config
        case dnsJsonSingbox
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

    static func getBool(forKey key: KEY, default defaultValue: Bool) -> Bool {
            guard UserDefaults.standard.object(forKey: key.rawValue) != nil else {
                return defaultValue
            }
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
