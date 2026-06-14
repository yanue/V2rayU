//
//  LaunchAgent.swift
//  V2rayU
//
//  Created by yanue on 2018/10/17.
//  Copyright © 2018 yanue. All rights reserved.
//

import Cocoa

actor LaunchAgent: NSObject {
    static let shared = LaunchAgent()

    let singBoxAgentName = "yanue.v2rayu.sing-box"
    let xrayCoreAgentName = "yanue.v2rayu.xray-core"

    let launchAgentDirPath = NSHomeDirectory() + "/Library/LaunchAgents/" 
    var lastCoreFile = getCoreFile()

    override init() {
        super.init()
    }

    private func getAgentPlistPath(_ name: String) -> String {
        return NSHomeDirectory() + "/Library/LaunchAgents/" + name + ".plist"
    }

    // 生成 LaunchAgent plist
    func generateLaunchAgentPlist(coreType: CoreType) {
        let agentName = coreType == .SingBox ? singBoxAgentName : xrayCoreAgentName
        let plistPath = getAgentPlistPath(agentName)

        let fileMgr = FileManager.default
        if !fileMgr.fileExists(atPath: launchAgentDirPath) {
            do {
                try fileMgr.createDirectory(atPath: launchAgentDirPath, withIntermediateDirectories: true, attributes: nil)
            } catch {
                logger.error("Failed to create LaunchAgents directory: \(error)")
                return
            }
        }

        let agentArguments = [lastCoreFile, "run", "-c", "config.json"]

        let dictAgent: NSMutableDictionary = [
            "Label": agentName,
            "WorkingDirectory": AppHomePath,
            "StandardOutPath": coreLogFilePath,
            "StandardErrorPath": coreLogFilePath,
            "ProgramArguments": agentArguments,
            "RunAtLoad": false,
            "KeepAlive": false,
        ]

        if #available(macOS 11.0, *) {
            dictAgent["AbandonProcessGroup"] = true
        }
        dictAgent["ProcessType"] = "Background"

        dictAgent.write(toFile: plistPath, atomically: true)
        unloadAgent(agentName: agentName)
        loadAgent(agentName: agentName)
        logger.info("generateLaunchAgentPlist: \(plistPath) with args: \(agentArguments)")
    }

    // 加载 LaunchAgent
    func loadAgent(agentName: String) {
        let plistPath = getAgentPlistPath(agentName)
        do {
            let output = try runCommand(at: "/bin/launchctl", with: ["load", "-wF", plistPath])
            logger.info("launchctl load \(plistPath) succeeded. \(output)")
        } catch let error {
            noticeTip(title: "launchctl load failed", informativeText: "plistPath: \(plistPath), error:\(error)")
            logger.info("launchctl load \(plistPath) failed. \(error)")
        }
    }

    // 卸载 LaunchAgent
    func unloadAgent(agentName: String) {
        let plistPath = getAgentPlistPath(agentName)
        do {
            let output = try runCommand(at: "/bin/launchctl", with: ["unload", "-F", plistPath])
            logger.info("launchctl unload \(plistPath) succeeded. \(output)")
        } catch let error {
            logger.info("launchctl unload \(plistPath) failed. \(error)")
        }
    }

    // 启动任务
    func startAgent(coreType: CoreType) -> Bool {
        let agentName = coreType == .SingBox ? singBoxAgentName : xrayCoreAgentName

        // 更新 core file 路径
        lastCoreFile = getCoreFile(mode: coreType)

        // 重新生成 plist
        generateLaunchAgentPlist(coreType: coreType)

        // load 并启动
        loadAgent(agentName: agentName)

        do {
            let output = try runCommand(at: "/bin/launchctl", with: ["start", agentName])
            logger.info("startAgent: \(agentName) ok \(output)")
            return true
        } catch let error {
            alertDialog(title: "startAgent failed.", message: error.localizedDescription, blocking: true)
            return false
        }
    }

    // 检查agent是否存在
    private func agentExists(_ agentName: String) -> Bool {
        let plistPath = getAgentPlistPath(agentName)
        return FileManager.default.fileExists(atPath: plistPath)
    }

    // 停止任务
    func stopAgent() {
        for agentName in [singBoxAgentName, xrayCoreAgentName] {
            guard agentExists(agentName) else { continue }
            do {
                let output = try runCommand(at: "/bin/launchctl", with: ["stop", agentName])
                unloadAgent(agentName: agentName)
                logger.info("stopAgent-ok \(agentName) \(output)")
            } catch let error {
                logger.info("stopAgent-failed: \(agentName) \(error)")
            }
        }
    }

}
