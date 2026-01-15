//
//  Launch.swift
//  V2rayU
//
//  Created by yanue on 2018/10/17.
//  Copyright © 2018 yanue. All rights reserved.
//

import Cocoa
import SystemConfiguration

enum RunMode: String, CaseIterable {
    case global
    case off
    case pac
    case manual
    case tunnel

    var icon: String {
        switch self {
        case .global:
            return "IconOnG"
        case .pac:
            return "IconOnP"
        case .off:
            return "IconOff"
        case .manual:
            return "IconOnM"
        case .tunnel:
            return "IconOnT"
        }
    }

    var tip: String {
        switch self {
        case .global:
            return "Global.tip"
        case .pac:
            return "Pac.tip"
        case .off:
            return "Off.tip"
        case .manual:
            return "Manual.tip"
        case .tunnel:
            return "Tunnel.tip"
        }
    }
}

// MARK: - 核心启动器
actor V2rayLaunch {
    static let shared = V2rayLaunch()

    func restart() async {
       let _ = await start()
    }
    
    func start() async -> Bool {
        logger.info("start v2ray-core begin")
        guard let item = ProfileStore.shared.getRunning() else {
            noticeTip(title: "启动失败", informativeText: "配置文件不存在")
            return false
        }
        await AppState.shared.resetSpeed()
        await CoreTrafficStatsHandler.shared.resetData()
        await LaunchDaemon.shared.stopAgent()
        
        createJsonFile(item: item)

        // 启动
        let started = await LaunchDaemon.shared.startAgent(coreType: item.AdaptCore())
        if !started {
            noticeTip(title: "启动失败", informativeText: "无法启动LaunchDaemon")
            return false
        }
        let mode = await AppState.shared.runMode
        setSystemProxy(mode: mode)
        logger.info("start v2ray-core ok: \(mode.rawValue)")
        Task {
            await CoreTrafficStatsHandler.shared.startTask(coreType: item.AdaptCore())
            try await PingRunning.shared.startPing()
        }
        return true
    }

    func stop() async {
        await LaunchDaemon.shared.stopAgent()
        await AppState.shared.resetSpeed()
        await CoreTrafficStatsHandler.shared.resetData()
        setSystemProxy(mode: .off)
    }

    private func createJsonFile(item: ProfileEntity) {
        let cfg = CoreConfigHandler()
        let jsonText = cfg.toJSON(item: item)
        do {
            try jsonText.write(to: URL(fileURLWithPath: JsonConfigFilePath), atomically: true, encoding: .utf8)
            logger.info("createJsonFile: \(jsonText)")
        } catch {
            logger.info("Failed to write JSON file: \(error)")
            noticeTip(title: "Failed to write JSON file: \(error)")
        }
    }

    func setSystemProxy(mode: RunMode) {
        logger.info("setSystemProxy: \(v2rayUTool), \(mode.rawValue)")
        var httpPort = ""
        var sockPort = ""
        var pacUrl = ""
        if mode == .global {
            httpPort = String(getHttpProxyPort())
            sockPort = String(getSocksProxyPort())
        }
        if mode == .pac {
            pacUrl = getPacUrl()
        }
        do {
            let output = try runCommand(at: v2rayUTool, with: [
                "-mode", mode.rawValue,
                "-pac-url", pacUrl,
                "-http-port", httpPort,
                "-sock-port", sockPort
            ])
            logger.info("setSystemProxy: ok \(output)")
        } catch {
            alertDialog(title: "setSystemProxy Error", message: error.localizedDescription)
            Task { await AppInstaller.shared.showInstallAlert() }
        }
    }
}
