//
//  CoreConfigHandler.swift
//  V2rayU
//
//  Created by yanue on 2026/1/7.
//

import Foundation

struct CombinedConfigResolvedGroup {
    let group: CombinedInboundOutboundGroup
    let profiles: [ProfileEntity]
}

struct CombinedConfigResolved {
    let combination: CombinedConfigEntity
    let groups: [CombinedConfigResolvedGroup]
    let coreType: CoreType
    let warningMessage: String?
    let canLaunch: Bool

    var firstProfile: ProfileEntity? {
        groups.flatMap { $0.profiles }.first
    }
}

class CoreConfigHandler {

    public func toJSON(item: ProfileEntity) -> String {
        // 目前架构: sing-box的tun服务(daemon) -> socks(sing-box|xray-core) ,因此这里agent端不需要内部的tun功能了
        switch item.AdaptCore() {
        case .SingBox:
            let cfg = SingboxConfigHandler()
            return cfg.toJSON(item: item)
        case .XrayCore:
            let vCfg = V2rayConfigHandler(enableTun: false) // 这里不需要xray内部的tun功能
            return vCfg.toJSON(item: item)
        }
    }

    public func toJSON(item: ProfileEntity, httpPort: String) -> String {
        toJSON(item: item, httpPort: httpPort, apiPort: nil)
    }

    public func toJSON(item: ProfileEntity, httpPort: String, apiPort: String?) -> String {
        switch item.AdaptCore() {
        case .SingBox:
            let cfg = SingboxConfigHandler()
            return cfg.toJSON(item: item, httpPort: httpPort, apiPort: apiPort)
        case .XrayCore:
            let vCfg = V2rayConfigHandler()
            return vCfg.toJSON(item: item, httpPort: httpPort, apiPort: apiPort)
        }
    }

    public func resolveCombination(
        _ combination: CombinedConfigEntity,
        profileOverrides: [ProfileEntity] = [],
        forceSingboxProfileUUIDs: Set<String> = []
    ) -> CombinedConfigResolved? {
        guard let validCombination = CombinedConfigStore.shared.getValidCombination(uuid: combination.uuid) else { return nil }
        var profilesByUUID = Dictionary(uniqueKeysWithValues: ProfileStore.shared.fetchAll().map { ($0.uuid, $0) })
        for profile in profileOverrides {
            profilesByUUID[profile.uuid] = profile
        }
        let forcedCore = validCombination.coreType?.forcedCoreType
        var resolvedGroups: [CombinedConfigResolvedGroup] = []
        var allProfiles: [ProfileEntity] = []

        for group in validCombination.groups {
            let profiles = group.outboundProfileUUIDs.compactMap { profilesByUUID[$0] }.map { profile -> ProfileEntity in
                if forceSingboxProfileUUIDs.contains(profile.uuid) {
                    var copy = profile
                    copy.coreType = .singbox
                    return copy
                }
                guard let forcedCore else { return profile }
                var copy = profile
                copy.coreType = forcedCore == .XrayCore ? .xray : .singbox
                return copy
            }
            guard profiles.count == group.outboundProfileUUIDs.count, !profiles.isEmpty else { return nil }
            resolvedGroups.append(CombinedConfigResolvedGroup(group: group, profiles: profiles))
            allProfiles.append(contentsOf: profiles)
        }

        guard !resolvedGroups.isEmpty else { return nil }

        let decisions = allProfiles.map { $0.resolveCoreCompatibility() }
        let warningMessage = decisions.compactMap { $0.warningMessage }.joined(separator: "\n\n")
        let canLaunch = decisions.allSatisfy { $0.canLaunch }
        let coreType: CoreType

        if !forceSingboxProfileUUIDs.isEmpty {
            coreType = .SingBox
        } else if let forcedCore {
            coreType = forcedCore
        } else if decisions.contains(where: { $0.coreType == .SingBox }) {
            coreType = .SingBox
        } else {
            coreType = .XrayCore
        }

        return CombinedConfigResolved(
            combination: validCombination,
            groups: resolvedGroups,
            coreType: coreType,
            warningMessage: warningMessage.isEmpty ? nil : warningMessage,
            canLaunch: canLaunch
        )
    }

    public func toJSON(combination resolved: CombinedConfigResolved) -> String {
        switch resolved.coreType {
        case .SingBox:
            let cfg = SingboxConfigHandler()
            return cfg.toJSON(combination: resolved)
        case .XrayCore:
            let cfg = V2rayConfigHandler(enableTun: false)
            return cfg.toJSON(combination: resolved)
        }
    }
}

extension ProfileEntity {
    func AdaptCore() -> CoreType {
        let decision = resolveCoreCompatibility()
        logger.info("AdaptCore: \(self.protocol.rawValue)/\(self.network.rawValue) -> \(decision.coreType.rawValue)")
        return decision.coreType
    }

    // 是否需要使用oldCore
    func getCoreFile() -> String {
        return  V2rayU.getCoreFile(mode: AdaptCore())
    }

    // 是否需要使用oldCore
    func getCoreName() -> String {
        return  V2rayU.getCoreFile(mode: AdaptCore())
    }

    func getAlpn() -> [String] {
        var alpn: [String] = []
        if self.network == .h2 || self.network == .grpc {
            alpn = ["h2"]
        } else if !self.alpn.rawValue.isEmpty {
            alpn = self.alpn.rawValue.split(separator: ",").map { String($0) }
            // WebSocket only supports HTTP/1.1 upgrade (h2/h3 breaks WS)
            if self.network == .ws {
                alpn = alpn.filter { $0 != "h2" && $0 != "h3" }
            }
            // Normalize to standard ALPN protocol IDs
            alpn = alpn.map { $0 == "http1.1" ? "http/1.1" : $0 }
        }
        return alpn
    }
}

func getCoreFile(mode: CoreType = .SingBox) -> String {
    var coreFile: String
#if arch(arm64)
    if mode == .SingBox {
        coreFile = "\(AppBinRoot)/bin/sing-box/sing-box-arm64"
    } else {
        coreFile = "\(AppBinRoot)/bin/xray-core/xray-arm64"
    }
#else
    if mode == .SingBox {
        coreFile = "\(AppBinRoot)/bin/sing-box/sing-box-64"
    } else {
        coreFile = "\(AppBinRoot)/bin/xray-core/xray-64"
    }
#endif
    return coreFile
}

extension ProfileEntity {
    /// 使用分享链接保存下来(用于比较是否订阅是否有变化)
    func uniqueKey() -> String {
        if self.shareUri.isEmpty {
            return ShareUri.generateShareUri(item: self)
        } else {
            return self.shareUri
        }
    }
}
