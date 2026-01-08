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
    var lastCoreFile = getCoreFile()

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

        // coreFile 会变, 需要重新生成 plist
        let agentArguments = [lastCoreFile, "run", "-c", "config.json"]

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
        logger.info("generateLaunchAgentPlist: \(self.launchAgentPlistFile) with args: \(agentArguments)")
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
    func startAgent(coreFile: String) -> Bool {
        do {
            // core文件更换了, 重新生成plist
            if lastCoreFile != coreFile {
                lastCoreFile = coreFile
                generateLaunchAgentPlist()
            }

            // 先load, 确保是最新的配置
            loadAgent()
            // 启动
            let output = try runCommand(at: "/bin/launchctl", with: ["start", LAUNCH_AGENT_NAME])
            logger.info("startAgent: \(coreFile) ok \(output)")
            return true
        } catch let error {
            alertDialog(title: "startAgent failed.", message: error.localizedDescription)
            return false
        }
    }

    // 停止任务
    func stopAgent() {
        do {
            // 先停止
            let output = try runCommand(at: "/bin/launchctl", with: ["stop", LAUNCH_AGENT_NAME])
            // 再卸载，确保彻底停止
            unloadAgent()
            logger.info("stopAgent-ok \(output)")
        } catch let error {
//            alertDialog(title: "stopAgent-failed.", message: error.localizedDescription)
        }
    }
}
