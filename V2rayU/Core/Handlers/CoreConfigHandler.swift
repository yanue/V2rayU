//
//  CoreConfigHandler.swift
//  V2rayU
//
//  Created by yanue on 2026/1/7.
//

class CoreConfigHandler {
        
   public func toJSON(item: ProfileEntity) -> String {
        switch item.AdaptCore() {
        case .SingBox:
            let cfg = SingboxConfigHandler()
            return cfg.toJSON(item: item)
        case .XrayCore:
            let vCfg = V2rayConfigHandler()
            return vCfg.toJSON(item: item)
        }
    }
}


