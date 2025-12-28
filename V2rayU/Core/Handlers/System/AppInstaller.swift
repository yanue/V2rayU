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
    var installReason: String = ""

    func checkInstall() async {
        logger.info("source path: \(AppResourcesPath)")

        let fileMgr = FileManager.default
        var needRunInstall = false

        // 确保目录存在
        if !fileMgr.fileExists(atPath: AppHomePath) {
            logger.info("app home dir \(AppHomePath) not exists, need install")
            do {
                try fileMgr.createDirectory(atPath: AppHomePath, withIntermediateDirectories: true, attributes: nil)
            } catch {
                logger.error("createDirectory failed: \(error)")
                needRunInstall = true
            }
        }

        // 检查核心文件是否可执行
        if !needRunInstall && !fileMgr.isExecutableFile(atPath: xrayCoreFile) {
            logger.info("\(xrayCoreFile) not executable")
            installReason = "Core file not executable"
            needRunInstall = true
        }

        // 检查架构
        if !needRunInstall && !checkFileIsCurrentArch(file: xrayCoreFile) {
            logger.info("\(xrayCoreFile) not current arch")
            installReason = "Core file arch mismatch"
            needRunInstall = true
        }

        // 检查 root 权限
        if !needRunInstall && !checkFileIsRootAdmin(file: v2rayUTool) {
            installReason = "v2rayUTool not root admin"
            needRunInstall = true
        }

        // 检查 geoip.dat
        if !needRunInstall && !fileMgr.fileExists(atPath: xrayCorePath + "/geoip.dat") {
            logger.info("geoip.dat missing")
            installReason = "geoip.dat missing"
            needRunInstall = true
        }

        // 检查 quarantine
        if !needRunInstall && isFileQuarantined(at: xrayCoreFile) {
            logger.info("\(xrayCoreFile) is quarantined")
            installReason = "File quarantined"
            needRunInstall = true
        }

        // 检查工具版本
        if !needRunInstall {
            let toolVersion = shell(launchPath: "/bin/bash", arguments: ["-c", "\(v2rayUTool) version"])
            if let version = toolVersion {
                if version.contains("Usage:") {
                    installReason = "Old tool version"
                    needRunInstall = true
                } else if version.compare("4.0.0", options: .numeric) == .orderedAscending {
                    installReason = "Tool version too old"
                    needRunInstall = true
                }
            } else {
                installReason = "Tool not exists"
                needRunInstall = true
            }
        }

        logger.info("launchedBefore, needRunInstall=\(needRunInstall)")
        if needRunInstall {
            await showInstallAlert()
        } else {
            logger.info("no need install")
        }
        logger.info("checkInstall end")
    }

    func showInstallAlert() async {
       let reason = self.installReason
       
       // Use a continuation to bridge the sync NSAlert.runModal() with async
       await withCheckedContinuation { continuation in
           DispatchQueue.main.async {  // Async dispatch to avoid strict mode warnings
               let alert = NSAlert()
               alert.alertStyle = .warning
               alert.messageText = String(localized: .InstallTitle)
               alert.informativeText = reason
               alert.addButton(withTitle: String(localized: .Install))
               alert.addButton(withTitle: String(localized: .Quit))

               let response = alert.runModal()
               if response == .alertFirstButtonReturn {
                   Task {
                       await self.install()
                       continuation.resume()  // Resume after install completes
                   }
               } else {
                   NSApp.terminate(self)
                   continuation.resume()  // Optional: resume on quit, though app terminates
               }
           }
       }
   }
    
    func install() async {
        let doSh = "cd " + AppResourcesPath + " && sudo chown root:admin ./install.sh && sudo chmod a+rsx  ./install.sh && ./install.sh"
        // Create authorization reference for the user
        await executeAppleScriptWithOsascript(script: doSh)
    }

    // 高版本macos执行NSAppleScript会出现授权失败
   func executeAppleScriptWithOsascript(script: String) async {
       do {
           // Assuming runCommand is sync; wrap in continuation for async
           let output = try await withCheckedThrowingContinuation { continuation in
               do {
                   let result = try runCommand(at: "/usr/bin/osascript", with: ["-e", "do shell script \"" + script + "\" with administrator privileges"])
                   continuation.resume(returning: result)
               } catch {
                   continuation.resume(throwing: error)
               }
           }
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
