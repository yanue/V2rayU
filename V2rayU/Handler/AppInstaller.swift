//
//  Launch.swift
//  V2rayU
//
//  Created by yanue on 2018/10/17.
//  Copyright © 2018 yanue. All rights reserved.
//

import Cocoa

actor AppInstaller: NSObject {
    static let shared = AppInstaller()
    // 检查是否需要安装
    func checkInstall() {
        // Ensure launch agent directory is existed.
        let fileMgr = FileManager.default
        if !fileMgr.fileExists(atPath: AppHomePath) {
            logger.info("app home dir \(AppHomePath) not exists,need install")
            try! fileMgr.createDirectory(atPath: AppHomePath, withIntermediateDirectories: true, attributes: nil)
        }
        // 检查 V2rayU 自身是否允许 App Background Activity
        // make sure new version
        logger.info("install: \(AppResourcesPath)")
        var needRunInstall = false
        if !needRunInstall && !FileManager.default.isExecutableFile(atPath: v2rayCoreFile) {
            logger.info("\(v2rayCoreFile) not accessable")
            needRunInstall = true
        }
        // 检查 v2rayCoreFile 是否允许 App Background Activity
        // Ensure permission with root admin
        if !needRunInstall && !checkFileIsRootAdmin(file: v2rayUTool) {
            needRunInstall = true
        }
        if !needRunInstall && !FileManager.default.fileExists(atPath: v2rayCorePath + "/geoip.dat") {
            logger.info("\(v2rayCorePath)/geoip.dat not exists,need install")
            needRunInstall = true
        }
        if !needRunInstall {
            // use /bin/bash to fix crash when V2rayUTool is not exist
            let toolVersion = shell(launchPath: "/bin/bash", arguments: ["-c", "\(v2rayUTool) version"])
            logger.info("toolVersion - \(v2rayUTool): \(String(describing: toolVersion))")
            if toolVersion != nil {
                let _version = toolVersion ?? "" // old version
                if _version.contains("Usage:") {
                    logger.info("\(v2rayUTool) old version,need install")
                    needRunInstall = true
                } else {
                    if !(_version >= "4.0.0") {
                        logger.info("\(v2rayUTool) old version,need install")
                        needRunInstall = true
                    }
                }
            } else {
                logger.info("\(v2rayUTool) not exists,need install")
                needRunInstall = true
            }
        }
        logger.info("launchedBefore, \(needRunInstall)")
        if !needRunInstall {
            logger.info("no need install")
            return
        }

        showInstallAlert()
        // generate plist
        Task {
          await LaunchAgent.shared.generateLaunchAgentPlist()
        }
    }

    func showInstallAlert() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.alertStyle = .warning
            if isMainland {
                alert.messageText = "安装V2rayUTool"
                alert.informativeText = "V2rayU 需要使用管理员权限安装 V2rayUTool 到 ~/.V2rayU/V2rayUTool"
                alert.addButton(withTitle: "安装")
                alert.addButton(withTitle: "退出")
            } else {
                alert.messageText = " Install V2rayUTool"
                alert.informativeText = "V2rayU needs to install V2rayUTool into ~/.V2rayU/V2rayUTool with administrator privileges"
                alert.addButton(withTitle: "Install")
                alert.addButton(withTitle: "Quit")
            }
            switch alert.runModal() {
            case .alertFirstButtonReturn:
                Task {
                    await self.showInstallAlertSynchronously()
                }
            default:
                NSApp.terminate(self)
            }
        }
    }

    func showInstallAlertSynchronously() -> Bool {
        // 定义返回值
        var shouldInstall = false
        // 创建信号量，初始值 = 0
        let semaphore = DispatchSemaphore(value: 0)
        // 将 UI 操作放到主线程
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Install V2rayUTool"
            alert.addButton(withTitle: "Install")
            alert.addButton(withTitle: "Quit")
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                shouldInstall = true
            }
            // 释放信号量，让阻塞的线程继续
            semaphore.signal()
        }
        // 阻塞等待 alert 的返回
        semaphore.wait()
        return shouldInstall
    }

    func install() {
        let doSh = "cd " + AppResourcesPath + " && sudo chown root:admin ./install.sh && sudo chmod a+rsx  ./install.sh && ./install.sh"
        // Create authorization reference for the user
        executeAppleScriptWithOsascript(script: doSh)
    }

    // 高版本macos执行NSAppleScript会出现授权失败
    func executeAppleScriptWithOsascript(script: String) {
        do {
            let output = try runCommand(at: "/usr/bin/osascript", with: ["-e", "do shell script \"" + script + "\" with administrator privileges"])
            logger.info("executeAppleScript-Output: \(output)")
        } catch {
            logger.info("executeAppleScript-Error: \(error)")
            var title = "Install V2rayUTool Failed"
            var toast = "Error: \(error),\nYou need execute scripts manually:\n \(script)"
            if isMainland {
                title = "安装 V2rayUTool 失败"
                toast = "安装失败: \(error)\n, 你需要在命令行手动执行一下: \(script)"
            }
            alertDialog(title: title, message: toast)
        }
    }

}
