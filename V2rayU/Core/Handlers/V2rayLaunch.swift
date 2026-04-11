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
    case pac
    case manual
    case tun

    var icon: String {
        switch self {
        case .global:
            return "IconOnG"
        case .pac:
            return "IconOnP"
        case .manual:
            return "IconOnM"
        case .tun:
            return "IconOnT"
        }
    }

    var tip: String {
        switch self {
        case .global:
            return "Global.tip"
        case .pac:
            return "Pac.tip"
        case .manual:
            return "Manual.tip"
        case .tun:
            return "Tun.tip"
        }
    }
}

// MARK: - 核心启动器
actor V2rayLaunch {
    static let shared = V2rayLaunch()
    var lastCore: CoreType?

    func restart() async {
        let _ = await start()
    }

    func start() async -> Bool {
        logger.info("start v2ray-core begin")
        guard let item = ProfileStore.shared.getRunning() else {
            noticeTip(title: "启动失败", informativeText: "无可用服务器配置，请先添加服务器或订阅")
            await MainActor.run {
                AppState.shared.runningProfile = ""
                AppState.shared.runningServer = nil
            }
            return false
        }
        // 同步 AppState 与实际使用的服务器
        await MainActor.run {
            if AppState.shared.runningProfile != item.uuid {
                AppState.shared.runningProfile = item.uuid
                AppState.shared.runningServer = item
                logger.info("V2rayLaunch.start: sync runningProfile to \(item.remark)")
            }
            AppMenuManager.shared.refreshServerItems()
        }
        await AppState.shared.resetSpeed()
        await CoreTrafficStatsHandler.shared.resetData()
        await LaunchAgent.shared.stopAgent()

        createJsonFile(item: item)
        
        // Clear log files on start
        truncateLogFile(appLogFilePath)
        truncateLogFile(coreLogFilePath)
        // tun.log is root-owned in /var/log/v2rayu/, skip truncation here
        // (sing-box will overwrite on start via log.output config)

        // 启动
        let started = await LaunchAgent.shared.startAgent(coreType: item.AdaptCore())
        if !started {
            noticeTip(title: "启动失败", informativeText: "无法启动LaunchDaemon")
            return false
        }
        let mode = await AppState.shared.runMode
        setSystemProxy(mode: mode)
        logger.info("start v2ray-core ok: \(mode.rawValue)")
        Task {
            await CoreTrafficStatsHandler.shared.startTask(coreType: item.AdaptCore())
            do {
                try await PingRunning.shared.startPing()
            } catch {
                logger.error("PingRunning.startPing failed: \(error)")
            }
        }
        // TUN模式: 使用sing-box(tun) -> xray/sing(socks)
        if mode == .tun {
            createTunJsonFile(item: item)
            logger.info("create tun config ok, path: \(TunConfigFilePath)")

            let tunStarted = await LaunchAgent.shared.startTunHelper()
            if !tunStarted {
                noticeTip(title: "启动失败", informativeText: "无法启动TUN服务")
                return false
            }
            logger.info("start tun-helper ok")
        }
        self.lastCore = item.AdaptCore()
        
        DispatchQueue.global().asyncAfter(deadline: .now() + 2) {
            LogRotation.rotateIfNeeded()
            LogRotation.extractErrors()
        }
        
        return true
    }

    func stop() async {
        await LaunchAgent.shared.stopAgent()
        await AppState.shared.resetSpeed()
        await CoreTrafficStatsHandler.shared.resetData()
        setSystemProxy(mode: nil)
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

    // TUN模式: 创建tun配置文件
    private func createTunJsonFile(item: ProfileEntity) {
        // TUN模式使用sing-box
        let cfg = SingboxConfigHandler(enableTun: true)
        let jsonText = cfg.toJSON(item: item)
        do {
            try jsonText.write(to: URL(fileURLWithPath: TunConfigFilePath), atomically: true, encoding: .utf8)
            logger.info("createTunJsonFile: \(jsonText)")
        } catch {
            logger.info("Failed to write tun JSON file: \(error)")
            noticeTip(title: "Failed to write tun JSON file: \(error)")
        }
    }

    func setSystemProxy(mode: RunMode?) {
        let modeValue = mode?.rawValue ?? "off"
        logger.info("setSystemProxy: \(v2rayUTool), \(modeValue)")
        var httpPort = ""
        var sockPort = ""
        var pacUrl = ""
        if mode == .global {
            httpPort = String(getHttpProxyPort())
            sockPort = String(getSocksProxyPort())
        }
        if mode == .pac {
            if !GeneratePACFile(rewrite: false) {
                noticeTip(title: "PAC 生成失败", informativeText: "无法生成 proxy.js，PAC 模式可能不会生效")
            }
            pacUrl = getPacUrl()
        }
        do {
            let output = try runCommand(at: v2rayUTool, with: [
                "-mode", modeValue,
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
