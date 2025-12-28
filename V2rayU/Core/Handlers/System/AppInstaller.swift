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
        logger.info("source apth: \(AppResourcesPath)")

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
        
        if !needRunInstall && !FileManager.default.isExecutableFile(atPath: xrayCoreFile) {
            logger.info("\(xrayCoreFile) not accessable")
            needRunInstall = true
        }
        // 检查 xrayCoreFile 是否允许 App Background Activity
        // Ensure permission with root admin
        if !needRunInstall && !checkFileIsRootAdmin(file: v2rayUTool) {
            needRunInstall = true
        }
        if !needRunInstall && !FileManager.default.fileExists(atPath: xrayCorePath + "/geoip.dat") {
            logger.info("\(xrayCorePath)/geoip.dat not exists,need install")
            needRunInstall = true
        }
        // 检查 core 文件的 quarantine flag
        if !needRunInstall && isFileQuarantined(at: xrayCoreFile) {
            logger.info("\(xrayCoreFile) is quarantined,need install")
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
    }

    func showInstallAlert() {
        // 将 UI 操作放到主线程, 同步执行, 确保在调用后才能继续
        DispatchQueue.main.sync {

            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = String(localized: .InstallTitle)
            alert.informativeText = String(localized: .InstallPermissionTip)
            alert.addButton(withTitle: String(localized: .Install))
            alert.addButton(withTitle: String(localized: .Quit))

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
        
        let semaphore = DispatchSemaphore(value: 0)
        // 将 UI 操作放到主线程
        DispatchQueue.main.sync {
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
            DispatchQueue.main.sync {
                let title =  String(localized: .InstallFailed)
                let toast = "\(String(localized: .InstallFailedManual))\n \(script)"
                alertDialog(title: title, message: toast)
            }
        }
    }

}
