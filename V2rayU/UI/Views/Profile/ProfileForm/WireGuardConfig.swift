//
//  WireGuardConfig.swift
//  V2rayU
//

import Foundation

// Extension for ProfileModel to handle WireGuard config (stored in entity.extra)
extension ProfileModel {
    var wireGuardLocalAddress: String {
        get { entity.getWireGuardConfig().localAddress }
        set { setWireGuardConfigField(\.localAddress, newValue) }
    }

    var wireGuardPreSharedKey: String {
        get { entity.getWireGuardConfig().preSharedKey }
        set { setWireGuardConfigField(\.preSharedKey, newValue) }
    }

    var wireGuardReserved: String {
        get { entity.getWireGuardConfig().reserved }
        set { setWireGuardConfigField(\.reserved, newValue) }
    }

    var wireGuardMtu: Int {
        get { entity.getWireGuardConfig().mtu }
        set { setWireGuardConfigField(\.mtu, newValue) }
    }

    private func setWireGuardConfigField<T>(_ keyPath: WritableKeyPath<ProfileEntity.WireGuardConfig, T>, _ value: T) {
        var config = entity.getWireGuardConfig()
        config[keyPath: keyPath] = value
        entity.setWireGuardConfig(config)
    }
}
