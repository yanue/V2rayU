//
//  Hysteria2Config.swift
//  V2rayU
//
//  Created by yanue on 2026/1/19.
//  Copyright © 2026 yanue. All rights reserved.
//

import Foundation

// Extension for ProfileModel to handle Hysteria 2 config
extension ProfileModel {
    var hysteria2ObfsPassword: String {
        get { getHysteria2Config().obfsPassword }
        set { setHysteria2ConfigField(\.obfsPassword, newValue) }
    }

    var hysteria2HopPortRange: String {
        get { getHysteria2Config().hopPortRange }
        set { setHysteria2ConfigField(\.hopPortRange, newValue) }
    }

    var hysteria2HopInterval: Int {
        get { getHysteria2Config().hopInterval }
        set { setHysteria2ConfigField(\.hopInterval, newValue) }
    }

    var hysteria2BandwidthUp: String {
        get { getHysteria2Config().bandwidthUp }
        set { setHysteria2ConfigField(\.bandwidthUp, newValue) }
    }

    var hysteria2BandwidthDown: String {
        get { getHysteria2Config().bandwidthDown }
        set { setHysteria2ConfigField(\.bandwidthDown, newValue) }
    }

    var hysteria2MasqueradeJson: String {
        get { getHysteria2Config().masqueradeJson }
        set { setHysteria2ConfigField(\.masqueradeJson, newValue) }
    }

    var hysteria2FinalMaskJson: String {
        get { getHysteria2Config().finalMaskJson }
        set { setHysteria2ConfigField(\.finalMaskJson, newValue) }
    }

    func getHysteria2Config() -> ProfileEntity.Hysteria2Config {
        guard let data = entity.extra.data(using: .utf8),
              let config = try? JSONDecoder().decode(ProfileEntity.Hysteria2Config.self, from: data) else {
            return ProfileEntity.Hysteria2Config()
        }
        return config
    }

    func setHysteria2Config(_ config: ProfileEntity.Hysteria2Config) {
        guard let data = try? JSONEncoder().encode(config),
              let jsonString = String(data: data, encoding: .utf8) else { return }
        entity.extra = jsonString
    }

    private func setHysteria2ConfigField<T>(_ keyPath: WritableKeyPath<ProfileEntity.Hysteria2Config, T>, _ value: T) {
        var config = getHysteria2Config()
        config[keyPath: keyPath] = value
        setHysteria2Config(config)
    }
}
