//
//  Launch.swift
//  V2rayU
//
//  Created by yanue on 2018/10/17.
//  Copyright © 2018 yanue. All rights reserved.
//

import Cocoa
import SystemConfiguration

class V2rayLaunch: NSObject {

    static func restartV2ray() {
        // start
        Task {
            await Self.startV2rayCore()
        }
    }

    static func startV2rayCore() async -> Bool {
        logger.info("start v2ray-core begin")
        guard let v2ray = ProfileViewModel.getRunning() else {
            noticeTip(title: "启动失败", informativeText: "配置文件不存在")
            return false
        }
        // 重置流量统计
        await V2rayTraffics.shared.resetData()
        // 创建配置文件
        createJsonFile(item: v2ray)
        // 启动失败就返回 false
        guard Self.StartAgent() else { return false }
        // 设置系统代理（只动作，不更新状态）
        setSystemProxy(mode: .global)
        return true
    }

    static func stopV2rayCore() {
        // stop launch
        Self.StopAgent()
        // off system proxy
        Self.setSystemProxy(mode: .off)
        // set status
        Task {
            await AppState.shared.switchRunMode(mode: .off)
        }
    }

    static func createJsonFile(item: ProfileModel) {
        let vCfg = V2rayConfigHandler()
        let jsonText = vCfg.toJSON(item: item)
        do {
            logger.info("createJsonFile: \(JsonConfigFilePath)")
            try jsonText.write(to: URL(fileURLWithPath: JsonConfigFilePath), atomically: true, encoding: .utf8)
        } catch {
            logger.info("Failed to write JSON file: \(error)")
            noticeTip(title: "Failed to write JSON file: \(error)")
        }
    }

    static func StartAgent() -> Bool {
        StopAgent()

        // close port
        let httpPort = getHttpProxyPort()
        let sockPort = getSocksProxyPort()

        // port has been used
        if isPortOpen(port: httpPort) {
            var toast = "http port \(httpPort) has been used, please replace it from advance setting"
            var title = "Port is already in use"
            if isMainland {
                toast = "http端口 \(httpPort) 已被使用, 请更换"
                title = "端口已被占用"
            }
            alertDialog(title: title, message: toast)
            DispatchQueue.main.async {
                StatusItemManager.shared.openAdvanceSetting()
            }
            return false
        }

        // port has been used
        if isPortOpen(port: sockPort) {
            var toast = "socks port \(sockPort) has been used, please replace it from advance setting"
            var title = "Port is already in use"
            if isMainland {
                toast = "socks端口 \(sockPort) 已被使用, 请更换"
                title = "端口已被占用"
            }
            alertDialog(title: title, message: toast)
            DispatchQueue.main.async {
                StatusItemManager.shared.openAdvanceSetting()
            }
            return false
        }
        // 启动
        Task {
            await LaunchAgent.shared.startAgent()
        }
        return true
    }

    static func StopAgent() {
        Task {
            await LaunchAgent.shared.stopAgent()
        }
    }

    static func setSystemProxy(mode: RunMode) {
        logger.info("setSystemProxy: \(v2rayUTool), \(mode.rawValue)")
        var httpPort: String = ""
        var sockPort: String = ""
        // reload
        if mode == .global {
            httpPort = String(getHttpProxyPort())
            sockPort = String(getSocksProxyPort())
        }
        do {
            let output = try runCommand(at: v2rayUTool, with: ["-mode", mode.rawValue, "-pac-url", "", "-http-port", httpPort, "-sock-port", sockPort])
            logger.info("setSystemProxy: ok \(output)")
        } catch let error {
            alertDialog(title: "setSystemProxy Error", message: error.localizedDescription)
            Task {
               await AppInstaller.shared.showInstallAlert()
            }
        }
    }
}
