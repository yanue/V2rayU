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
    let tunHelperDaemon = "yanue.v2rayu.tun-helper" // 位于 `/Library/LaunchDaemons/yanue.v2rayu.tun-helper.plist`, 由 install.sh 安装

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
            alertDialog(title: "startAgent failed.", message: error.localizedDescription)
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
        stopTunHelper()

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

    // 启动tun-helper (sing-box based)
    func startTunHelper() async -> Bool {
        do {
            let output = try runCommand(at: "/usr/bin/sudo", with: ["-n", "/bin/launchctl", "start", tunHelperDaemon])
            logger.info("startTunHelper done: \(output)")
            return true
        } catch let error {
            let errorStr = String(describing: error)
            logger.info("startTunHelper failed: \(errorStr)")
            if errorStr.contains("password is required") {
                // sudo 权限未配置，直接触发安装授权流程
                await AppInstaller.shared.checkInstall()
                // 安装后重试
                do {
                    let output = try runCommand(at: "/usr/bin/sudo", with: ["-n", "/bin/launchctl", "start", tunHelperDaemon])
                    logger.info("startTunHelper retry done: \(output)")
                    return true
                } catch {
                    logger.info("startTunHelper retry failed: \(error)")
                    return false
                }
            } else {
                alertDialog(title: "startTunHelper failed.", message: error.localizedDescription)
            }
            return false
        }
    }


    // 停止tun-helper
    func stopTunHelper() {
        do {
            _ = try runCommand(at: "/usr/bin/sudo", with: ["-n", "/bin/launchctl", "stop", tunHelperDaemon])
            logger.info("stopTunHelper done")
        } catch let error {
            // 如果是sudo需要密码的错误，说明没有配置好，不需要报错
            if error.localizedDescription.contains("password is required") {
                logger.info("stopTunHelper skipped: sudo not configured, run install first")
            } else {
                logger.info("stopTunHelper failed: \(error)")
            }
        }
    }
}
