//
//  Launch.swift
//  V2rayU
//
//  Created by yanue on 2018/10/17.
//  Copyright © 2018 yanue. All rights reserved.
//

import Cocoa

actor LaunchDaemon: NSObject {
    static let shared = LaunchDaemon()
    private let xrayDaemon = "yanue.v2rayu.xray-core"
    private let singDaemon = "yanue.v2rayu.sing-box"
    let LaunchDaemonDirPath = "/Library/LaunchDaemons/"
    var lastCoreFile = getCoreFile()

    override init() {
        super.init()
    }
    
    func bootstrap() {
        for daemon in [xrayDaemon, singDaemon] {
            do {
                _ = try runCommand(at: "/usr/bin/sudo", with: ["-n", "/bin/launchctl", "stop", daemon])
                logger.info("stopAllAgents Stopped: \(daemon)")
            } catch {
                logger.info("stopAllAgents Failed to stop \(daemon): \(error)")
            }
        }
    }
    
    // 停止两个核心
    private func stopAllAgents() {
        for daemon in [xrayDaemon, singDaemon] {
            do {
                _ = try runCommand(at: "/usr/bin/sudo", with: ["-n", "/bin/launchctl", "stop", daemon])
                logger.info("stopAllAgents Stopped: \(daemon)")
            } catch {
                logger.info("stopAllAgents Failed to stop \(daemon): \(error)")
            }
        }
    }

    // 启动指定核心
    func startAgent(coreType: CoreType) -> Bool {
        stopAllAgents()  // 启动前先停掉两个
        let daemon = (coreType == .SingBox) ? singDaemon : xrayDaemon
        do {
            let output = try runCommand(at: "/usr/bin/sudo", with: ["-n", "/bin/launchctl", "start", daemon])
            logger.info("startAgent done: \(daemon) \(output)")
            return true
        } catch {
            logger.info("startAgent failed: \(daemon) \(error)")
            alertDialog(title: "startAgent failed.", message: error.localizedDescription)
            return false
        }
    }

    // 停止指定核心
    func stopAgent() {
        stopAllAgents()
    }
}
