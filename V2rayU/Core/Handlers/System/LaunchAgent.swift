//
//  Launch.swift
//  V2rayU
//
//  Created by yanue on 2018/10/17.
//  Copyright © 2018 yanue. All rights reserved.
//

import Cocoa

actor LaunchAgent: NSObject {
    static let shared = LaunchAgent()
    private let LAUNCH_AGENT_NAME = "yanue.v2rayu.v2ray-core"
    let launchAgentDirPath = NSHomeDirectory() + "/Library/LaunchAgents/"
    let launchAgentPlistFile: String

    override init() {
        self.launchAgentPlistFile = NSHomeDirectory() + "/Library/LaunchAgents/" + LAUNCH_AGENT_NAME + ".plist"
        super.init()
    }

    // 生成 LaunchAgent plist
    func generateLaunchAgentPlist() {
        // Ensure launch agent directory is existed.
        let fileMgr = FileManager.default
        if !fileMgr.fileExists(atPath: launchAgentDirPath) {
            try! fileMgr.createDirectory(atPath: launchAgentDirPath, withIntermediateDirectories: true, attributes: nil)
        }

        // write launch agent
        // 兼容 v2ray | xray
        #if arch(arm64)
        let coreFile = "./bin/xray-core/xray-arm64"
        #else
        let coreFile = "./bin/xray-core/xray-64"
        #endif
        let agentArguments = [coreFile, "run", "-config", "config.json"]

        let dictAgent: NSMutableDictionary = [
            "Label": LAUNCH_AGENT_NAME,
            "WorkingDirectory": AppHomePath,
            "StandardOutPath": coreLogFilePath,
            "StandardErrorPath": coreLogFilePath,
            "ProgramArguments": agentArguments,
            "RunAtLoad": false, // 不能开机自启(需要停止)
            "KeepAlive": false, // 不能自动重启(需要停止)
        ]

        dictAgent.write(toFile: launchAgentPlistFile, atomically: true)
        // unload launch service(避免更改后无法生效)
        unloadAgent()
        // load launch service
        loadAgent()
    }

    // 加载 LaunchAgent
    func loadAgent() {
        do {
            let output = try runCommand(at: "/bin/launchctl", with: ["load", "-wF", launchAgentPlistFile])
            logger.info("launchctl load \(self.launchAgentPlistFile) succeeded. \(output)")
        } catch let error {
            logger.info("launchctl load \(self.launchAgentPlistFile) failed. \(error)")
        }
    }

    // 卸载 LaunchAgent
    func unloadAgent() {
        do {
            let output = try runCommand(at: "/bin/launchctl", with: ["unload", "-F", launchAgentPlistFile])
            logger.info("launchctl unload \(self.launchAgentPlistFile) succeeded. \(output)")
        } catch let error {
            logger.info("launchctl unload \(self.launchAgentPlistFile) failed. \(error)")
        }
    }

    // 启动任务
    func startAgent() -> Bool {
        do {
            let output = try runCommand(at: "/bin/launchctl", with: ["start", LAUNCH_AGENT_NAME])
            logger.info("Start v2ray-core: ok \(output)")
            return true
        } catch let error {
            alertDialog(title: "Start v2ray-core failed.", message: error.localizedDescription)
            return false
        }
    }

    // 停止任务
    func stopAgent() {
        do {
            let output = try runCommand(at: "/bin/launchctl", with: ["stop", LAUNCH_AGENT_NAME])
            logger.info("Stop v2ray-core: ok \(output)")
        } catch let error {
            alertDialog(title: "Stop v2ray-core failed.", message: error.localizedDescription)
        }
    }
}
