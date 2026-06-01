//
//  Hysteria2Uri.swift
//  V2rayU
//
//  Created by yanue on 2026/1/19.
//  Copyright © 2026 yanue. All rights reserved.
//

import Foundation

// Hysteria 2
class Hysteria2Uri: BaseShareUri {
    private var profile: ProfileEntity
    private var error: String?

    // 初始化
    init() {
        profile = ProfileEntity(protocol: .hysteria2)
    }

    // 从 ProfileModel 初始化
    required init(from model: ProfileEntity) {
        // 通过传入的 model 初始化 Profile 类的所有属性
        profile = model
    }

    func getProfile() -> ProfileEntity {
        return profile
    }

    // hysteria2://password@host:port?obfs=salamander&obfs-password=xxx&auth=password&auth-password=xxx&sni=xxx&insecure=1#remark
    func encode() -> String {
        var uri = URLComponents()
        uri.scheme = "hysteria2"
        uri.user = self.profile.password
        uri.host = profile.address
        uri.port = profile.port
        
        let hyConfig = profile.getHysteria2Config()
        
        var queryItems = [
            URLQueryItem(name: "security", value: profile.security.rawValue),
            URLQueryItem(name: "sni", value: profile.sni),
            URLQueryItem(name: "fp", value: profile.fingerprint.rawValue),
            URLQueryItem(name: "pcks", value: profile.pinnedPeerCertSha256),
        ]
        
        // Hysteria 2 特定参数
        if !hyConfig.obfsPassword.isEmpty {
            queryItems.append(URLQueryItem(name: "obfs-password", value: hyConfig.obfsPassword))
        }
        if !hyConfig.hopPortRange.isEmpty {
            queryItems.append(URLQueryItem(name: "mport", value: hyConfig.hopPortRange))
        }
        if hyConfig.hopInterval > 0 {
            queryItems.append(URLQueryItem(name: "hop", value: String(hyConfig.hopInterval)))
        }
        if !hyConfig.bandwidthUp.isEmpty {
            queryItems.append(URLQueryItem(name: "up", value: hyConfig.bandwidthUp))
        }
        if !hyConfig.bandwidthDown.isEmpty {
            queryItems.append(URLQueryItem(name: "down", value: hyConfig.bandwidthDown))
        }
        if !hyConfig.masqueradeJson.isEmpty {
            queryItems.append(URLQueryItem(name: "masquerade", value: hyConfig.masqueradeJson))
        }
        if !hyConfig.finalMaskJson.isEmpty {
            queryItems.append(URLQueryItem(name: "finalmask", value: hyConfig.finalMaskJson))
        }
        if !hyConfig.bandwidthUp.isEmpty {
            queryItems.append(URLQueryItem(name: "up", value: hyConfig.bandwidthUp))
        }
        if !hyConfig.bandwidthDown.isEmpty {
            queryItems.append(URLQueryItem(name: "down", value: hyConfig.bandwidthDown))
        }
        if hyConfig.hopInterval > 0 {
            queryItems.append(URLQueryItem(name: "hop", value: String(hyConfig.hopInterval)))
        }
        
        uri.queryItems = queryItems
        return (uri.url?.absoluteString ?? "") + "#" + profile.remark.urlEncoded()
    }

    func parse(url: URL) -> Error? {
        guard let host = url.host else {
            return NSError(domain: "Hysteria2UriError", code: 1001, userInfo: [NSLocalizedDescriptionKey: "Missing host"])
        }
        guard let port = url.port else {
            return NSError(domain: "Hysteria2UriError", code: 1002, userInfo: [NSLocalizedDescriptionKey: "Missing port"])
        }
        guard let password = url.user else {
            return NSError(domain: "Hysteria2UriError", code: 1003, userInfo: [NSLocalizedDescriptionKey: "Missing password"])
        }
        
        logger.info("Parsed Hysteria2 URI: \(url)")

        profile.address = host
        profile.port = port
        profile.password = password

        let query = url.queryParams()
        
        // 基础设置
        profile.security = query.getEnum(forKey: "security", type: V2rayStreamSecurity.self, defaultValue: .tls)
        profile.sni = query.getString(forKey: "sni", defaultValue: profile.address)
        profile.fingerprint = query.getEnum(forKey: "fp", type: V2rayStreamFingerprint.self, defaultValue: .chrome)
        profile.pinnedPeerCertSha256 = query.getString(forKey: "pcks", defaultValue: "")
        
        // Hysteria 2 特定参数 - 获取现有配置并更新
        var config = profile.getHysteria2Config()
        config.obfsPassword = query.getString(forKey: "obfs-password", defaultValue: "")
        config.hopPortRange = query.getString(forKey: "mport", defaultValue: "")
        config.hopInterval = query.getInt(forKey: "hop", defaultValue: 0)
        config.bandwidthUp = query.getString(forKey: "up", defaultValue: "")
        config.bandwidthDown = query.getString(forKey: "down", defaultValue: "")
        config.masqueradeJson = query.getString(forKey: "masquerade", defaultValue: "")
        config.finalMaskJson = query.getString(forKey: "finalmask", defaultValue: "")
        
        // 保存配置到 extra 字段
        if let data = try? JSONEncoder().encode(config),
           let jsonString = String(data: data, encoding: .utf8) {
            // 创建新的 ProfileEntity 实例
            var newProfile = profile
            newProfile.extra = jsonString
            profile = newProfile
        }
        
        // security 不能为 none
        if profile.security == .none {
            profile.security = .tls
        }
        
        // 如果 sni 为空，则将 host 赋值给 sni
        if profile.sni.isEmpty {
            profile.sni = host
        }
        
        // 设置备注
        if let fragment = url.fragment, !fragment.isEmpty {
            profile.remark = fragment.urlDecoded()
        }
        if profile.remark.isEmpty {
            profile.remark = "hysteria2"
        }
        
        return nil
    }
}
