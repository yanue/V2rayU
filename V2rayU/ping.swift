//
//  ping.swift
//  V2rayU
//
//  Created by Erick on 2019/10/30.
//  Copyright © 2019 yanue. All rights reserved.
//

import SwiftSocket

class Ping : NSObject {

    var startTime: CLongLong
    var item: V2rayItem

    init(item: V2rayItem) {
        self.item = item
        self.startTime = CLongLong(round(Date().timeIntervalSince1970*1000))
    }
    
    func pingProxySpeed() {
        let cfg = V2rayConfig()
        cfg.parseJson(jsonText: item.json)
        
        var host :String
        var port :Int
        if cfg.serverProtocol == V2rayProtocolOutbound.vmess.rawValue {
            host = cfg.serverVmess.address
            port = cfg.serverVmess.port
        } else if cfg.serverProtocol == V2rayProtocolOutbound.shadowsocks.rawValue {
            host = cfg.serverShadowsocks.address
            port = cfg.serverShadowsocks.port
        } else if cfg.serverProtocol == V2rayProtocolOutbound.socks.rawValue {
            host = cfg.serverSocks5.address
            port = Int(cfg.serverSocks5.port)!
        } else {
            return
        }

        let client = TCPClient(address: host, port: Int32(port))

        switch client.connect(timeout: 10) {
          case .success:
            // Connection successful
            connectSuccess()
            break
          case .failure(let error):
            // 💩
            connectError(error: error)
            break
        }
    }

    private func connectError(error: Error) {
        self.item.speed = -1
        NSLog(String.init(format: "Ping %@结果不通的，时间%dms", item.remark, item.speed))
        self.item.store()
    }
    
    private func connectSuccess() {
        self.item.speed = Int(CLongLong(round(Date().timeIntervalSince1970*1000)) - startTime)
        NSLog(String.init(format: "Ping %@结果，时间%dms", item.remark, item.speed))
        self.item.store()
    }
}
