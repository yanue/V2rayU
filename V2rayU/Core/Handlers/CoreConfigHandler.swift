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

    func isChain(_ resolvedGroup: CombinedConfigResolvedGroup) -> Bool {
        combination.isChain(resolvedGroup.group)
    }

    func outboundTag(groupIndex: Int, profileIndex: Int) -> String {
        let resolvedGroup = groups[groupIndex]
        return combinedOutboundTag(isChain: isChain(resolvedGroup), groupIndex: groupIndex, profileIndex: profileIndex, uuid: resolvedGroup.profiles[profileIndex].uuid)
    }

    /// 首组为链式时，出口的上一跳 tag（"proxy" 复制出口并经由它拨号，同样走整条链）；否则返回 nil
    var chainProxyPreviousTag: String? {
        guard let firstGroup = groups.first, isChain(firstGroup) else { return nil }
        return outboundTag(groupIndex: 0, profileIndex: firstGroup.profiles.count - 2)
    }
}

class CoreConfigHandler {

    /// - Parameter tunMode: 当前是否为 TUN 模式（sing-box TUN → socks → 核心）。
    ///   xray 需要据此调整嗅探/出站解析/网卡绑定；sing-box 核心自带嗅探与 auto_detect_interface，无需区分。
    public func toJSON(item: ProfileEntity, tunMode: Bool = false) -> String {
        // 目前架构: sing-box的tun服务(daemon) -> socks(sing-box|xray-core) ,因此这里agent端不需要内部的tun功能了
        switch item.AdaptCore() {
        case .SingBox:
            let cfg = SingboxConfigHandler()
            return cfg.toJSON(item: item)
        case .XrayCore:
            let vCfg = V2rayConfigHandler(enableTun: false, tunChainMode: tunMode) // 这里不需要xray内部的tun功能
            return vCfg.toJSON(item: item)
        }
    }

    public func toJSON(item: ProfileEntity, httpPort: String) -> String {
        toJSON(item: item, httpPort: httpPort, latencyPort: nil)
    }

    public func toJSON(item: ProfileEntity, httpPort: String, latencyPort: String?) -> String {
        switch item.AdaptCore() {
        case .SingBox:
            let cfg = SingboxConfigHandler()
            return cfg.toJSON(item: item, httpPort: httpPort, latencyPort: latencyPort)
        case .XrayCore:
            let vCfg = V2rayConfigHandler()
            return vCfg.toJSON(item: item, httpPort: httpPort, latencyPort: latencyPort)
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

    public func toJSON(combination resolved: CombinedConfigResolved, tunMode: Bool = false) -> String {
        switch resolved.coreType {
        case .SingBox:
            let cfg = SingboxConfigHandler()
            return cfg.toJSON(combination: resolved)
        case .XrayCore:
            let cfg = V2rayConfigHandler(enableTun: false, tunChainMode: tunMode)
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

    /// 服务器本身的标识(不含备注): 订阅更新时分享链接对不上, 再用它认出同一个节点。
    /// 含 host/path/sni: 走 CDN 的订阅里很多节点地址/端口/密码相同, 只差 host 或 path
    func serverKey() -> String {
        [self.protocol.rawValue, self.address.lowercased(), String(self.port), self.password,
         self.network.rawValue, self.security.rawValue, self.host, self.path, self.sni].joined(separator: "|")
    }
}
