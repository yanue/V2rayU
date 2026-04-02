//
//  CoreConfigHandler.swift
//  V2rayU
//
//  Created by yanue on 2026/1/7.
//

import Foundation

class CoreConfigHandler {
        
    public func toJSON(item: ProfileEntity) -> String {
        // 目前架构: sing-box的tun服务(daemon) -> socks(sing-box|xray-core) ,因此这里agent端不需要内部的tun功能了
        switch item.AdaptCore() {
        case .SingBox:
            let cfg = SingboxConfigHandler(enableTun: false) // 这里不需要内部的tun功能
            return cfg.toJSON(item: item)
        case .XrayCore:
            let vCfg = V2rayConfigHandler(enableTun: false) // 这里不需要xray内部的tun功能
            return vCfg.toJSON(item: item)
        }
    }
    
    public func toJSON(item: ProfileEntity, httpPort: String) -> String {
        switch item.AdaptCore() {
        case .SingBox:
            let cfg = SingboxConfigHandler()
            return cfg.toJSON(item: item, httpPort: httpPort)
        case .XrayCore:
            let vCfg = V2rayConfigHandler()
            return vCfg.toJSON(item: item, httpPort: httpPort)
        }
    }
}

extension ProfileEntity {
    func AdaptCore() -> CoreType {
        var mode: CoreType = .XrayCore
        // 这里是因为xray新版v25版本后,开始禁止支持这些类型了
        // [Warning] common/errors: This feature gRPC transport (with unnecessary costs, etc.) is deprecated and being migrated to XHTTP stream-up H2.
        if self.network == .grpc || self.network == .h2 || self.network == .ws {
            mode = .SingBox
        }
         logger.info("AdaptCore: \(self.protocol.rawValue)/\(self.network.rawValue) -> \(mode.rawValue)")
        return mode
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
        }
        return alpn
    }
}

func getCoreFile(mode: CoreType = .SingBox) -> String {
    var coreFile: String
#if arch(arm64)
    if mode == .SingBox {
        coreFile = "\(AppHomePath)/bin/sing-box/sing-box-arm64"
    } else {
        coreFile = "\(AppHomePath)/bin/xray-core/xray-arm64"
    }
#else
    if mode == .SingBox {
        coreFile = "\(AppHomePath)/bin/sing-box/sing-box-64"
    } else {
        coreFile = "\(AppHomePath)/bin/xray-core/xray-64"
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
