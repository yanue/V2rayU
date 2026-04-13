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
    // 从 Swift 传入 USERNAME — NSUserName() 在 App 进程中一定是真实用户，
    // 解决 install.sh 在 osascript root 环境下无法可靠获取用户名的问题
    let doSh = "cd '\(AppResourcesPath)' && sudo chown root:admin ./install.sh && sudo chmod a+rsx ./install.sh && USERNAME='\(NSUserName())' ./install.sh"

    func checkInstall() async {
        logger.info("source path: \(AppResourcesPath)")

        let fileMgr = FileManager.default
        var needRunInstall = false

        // ====== 版本检查：每个新版本都执行一次 install ======
        let markerFile = AppHomePath + "/.installed_version"
        if !needRunInstall {
            let installedVer = (try? String(contentsOfFile: markerFile, encoding: .utf8))?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if installedVer != appVersion {
                logger.info("version mismatch: installed=\(installedVer), current=\(appVersion)")
                installReason = "App updated to \(appVersion)"
                needRunInstall = true
            }
        }

        // ====== 目录检查 ======

        // 用户数据目录
        if !needRunInstall && !fileMgr.fileExists(atPath: AppHomePath) {
            logger.info("app home dir \(AppHomePath) not exists")
            installReason = "App home directory missing"
            needRunInstall = true
        }

        // 用户数据目录可写
        if !needRunInstall && !fileMgr.isWritableFile(atPath: AppHomePath) {
            logger.info("app home dir \(AppHomePath) not writable")
            installReason = "App home directory not writable"
            needRunInstall = true
        }

        // 用户数据目录 owner 是当前用户
        if !needRunInstall {
            do {
                let attrs = try fileMgr.attributesOfItem(atPath: AppHomePath)
                let owner = attrs[.ownerAccountName] as? String ?? ""
                if owner != NSUserName() {
                    logger.info("app home dir owner=\(owner), expected=\(NSUserName())")
                    installReason = "App home directory owner mismatch"
                    needRunInstall = true
                }
            } catch {
                logger.info("failed to get app home dir attributes: \(error)")
                installReason = "App home directory attributes error"
                needRunInstall = true
            }
        }

        // 数据库文件可写（readonly 问题诊断）
        if !needRunInstall && fileMgr.fileExists(atPath: databasePath) {
            if !fileMgr.isWritableFile(atPath: databasePath) {
                logger.info("database file \(databasePath) is readonly")
                installReason = "Database file is readonly"
                needRunInstall = true
            }
            // SQLite WAL/SHM 文件可写
            if !needRunInstall {
                for ext in ["-wal", "-shm"] {
                    let walPath = databasePath + ext
                    if fileMgr.fileExists(atPath: walPath) && !fileMgr.isWritableFile(atPath: walPath) {
                        logger.info("database \(ext) file is readonly")
                        installReason = "Database \(ext) file is readonly"
                        needRunInstall = true
                        break
                    }
                }
            }
        }

        // root daemon 日志目录
        if !needRunInstall && !fileMgr.fileExists(atPath: "/var/log/v2rayu") {
            logger.info("/var/log/v2rayu not exists")
            installReason = "Log directory missing"
            needRunInstall = true
        }

        // ====== 二进制检查 ======

        // xray-core 可执行
        if !needRunInstall && !fileMgr.isExecutableFile(atPath: xrayCoreFile) {
            logger.info("\(xrayCoreFile) not executable")
            installReason = "xray-core not executable"
            needRunInstall = true
        }

        // xray-core 架构匹配
        if !needRunInstall && !checkFileIsCurrentArch(file: xrayCoreFile) {
            logger.info("\(xrayCoreFile) not current arch")
            installReason = "xray-core arch mismatch"
            needRunInstall = true
        }

        // sing-box 可执行
        let singBoxFile = getCoreFile(mode: .SingBox)
        if !needRunInstall && !fileMgr.isExecutableFile(atPath: singBoxFile) {
            logger.info("\(singBoxFile) not executable")
            installReason = "sing-box not executable"
            needRunInstall = true
        }

        // sing-box 架构匹配
        if !needRunInstall && !checkFileIsCurrentArch(file: singBoxFile) {
            logger.info("\(singBoxFile) not current arch")
            installReason = "sing-box arch mismatch"
            needRunInstall = true
        }

        // geoip.dat
        if !needRunInstall && !fileMgr.fileExists(atPath: xrayCorePath + "/geoip.dat") {
            logger.info("geoip.dat missing")
            installReason = "geoip.dat missing"
            needRunInstall = true
        }

        // ====== 隔离标记 ======
        let quarantineFiles = [
            (xrayCoreFile, "xray-core"),
            (singBoxFile, "sing-box"),
            (v2rayUTool, "V2rayUTool"),
        ]
        for (path, name) in quarantineFiles {
            if !needRunInstall && isFileQuarantined(at: path) {
                logger.info("\(path) is quarantined")
                installReason = "\(name) quarantined"
                needRunInstall = true
            }
        }

        // ====== 工具 & 权限检查 ======

        // V2rayUTool root:admin + setuid
        if !needRunInstall && !checkFileIsRootAdmin(file: v2rayUTool) {
            installReason = "V2rayUTool not root:admin"
            needRunInstall = true
        }

        // V2rayUTool setuid(+s) 权限
        if !needRunInstall {
            do {
                let attrs = try fileMgr.attributesOfItem(atPath: v2rayUTool)
                if let perms = attrs[.posixPermissions] as? Int {
                    if (perms & 0o4000) == 0 {  // S_ISUID
                        logger.info("V2rayUTool missing setuid(+s) permission")
                        installReason = "V2rayUTool missing setuid"
                        needRunInstall = true
                    }
                }
            } catch {
                logger.info("failed to check V2rayUTool permissions: \(error)")
                installReason = "V2rayUTool permission check failed"
                needRunInstall = true
            }
        }

        // V2rayUTool 版本
        if !needRunInstall {
            let toolVersion = shell(launchPath: "/bin/bash", arguments: ["-c", "\(v2rayUTool) version"])
            if let version = toolVersion {
                if version.contains("Usage:") || version.compare("4.0.0", options: .numeric) == .orderedAscending {
                    installReason = "V2rayUTool version too old"
                    needRunInstall = true
                }
            } else {
                installReason = "V2rayUTool not exists"
                needRunInstall = true
            }
        }

        // update-xray.sh 存在 + 可执行
        let updateScript = AppBinRoot + "/update-xray.sh"
        if !needRunInstall && !fileMgr.fileExists(atPath: updateScript) {
            logger.info("\(updateScript) not exists")
            installReason = "update-xray.sh missing"
            needRunInstall = true
        }
        if !needRunInstall && !fileMgr.isExecutableFile(atPath: updateScript) {
            logger.info("\(updateScript) not executable")
            installReason = "update-xray.sh not executable"
            needRunInstall = true
        }

        // sudoers 文件存在
        let sudoerFile = "/private/etc/sudoers.d/v2rayu-sudoer"
        if !needRunInstall && !fileMgr.fileExists(atPath: sudoerFile) {
            logger.info("\(sudoerFile) not exists")
            installReason = "sudoers rules missing"
            needRunInstall = true
        }

        // sudoers 实际可用（sudo -n 能否无密码执行 launchctl）
        if !needRunInstall {
            let testResult = shell(launchPath: "/usr/bin/sudo", arguments: ["-n", "-l"])
            if testResult == nil || !testResult!.contains("NOPASSWD") {
                logger.info("sudoers NOPASSWD not effective")
                installReason = "sudoers rules incorrect"
                needRunInstall = true
            }
        }

        // tun-helper LaunchDaemon plist 存在
        let tunPlist = "/Library/LaunchDaemons/yanue.v2rayu.tun-helper.plist"
        if !needRunInstall && !fileMgr.fileExists(atPath: tunPlist) {
            logger.info("\(tunPlist) not exists")
            installReason = "tun-helper daemon not installed"
            needRunInstall = true
        }

        // ====== 旧版残留迁移 ======
        if !needRunInstall && (fileMgr.fileExists(atPath: AppHomePath + "/bin") || fileMgr.fileExists(atPath: AppHomePath + "/V2rayUTool")) {
            logger.info("Legacy bin/V2rayUTool found in \(AppHomePath)")
            installReason = "Migrate binaries to system directory"
            needRunInstall = true
        }

        // 清理旧版 sudoers 文件
        if !needRunInstall && fileMgr.fileExists(atPath: "/private/etc/sudoers.d/v2rayu-helper") {
            logger.info("Old sudoers file v2rayu-helper found")
            installReason = "Cleanup old sudoers file"
            needRunInstall = true
        }

        logger.info("checkInstall: needRunInstall=\(needRunInstall), reason=\(self.installReason)")
        if needRunInstall {
            await showInstallAlert()
        } else {
            logger.info("no need install")
        }
        logger.info("checkInstall end")
    }

    func showInstallAlert() async {
        let reason = installReason

        // Use a continuation to bridge the sync NSAlert.runModal() with async
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async { // Async dispatch to avoid strict mode warnings
                let alert = NSAlert()
                alert.alertStyle = .warning
                alert.messageText = String(localized: .InstallTitle) + "\n\n" + reason
                alert.informativeText = self.doSh
                alert.addButton(withTitle: String(localized: .Install))
                alert.addButton(withTitle: String(localized: .Quit))

                let response = alert.runModal()
                if response == .alertFirstButtonReturn {
                    Task {
                        await self.install()
                        continuation.resume() // Resume after install completes
                    }
                } else {
                    NSApp.terminate(self)
                    continuation.resume() // Optional: resume on quit, though app terminates
                }
            }
        }
    }

    func install() async {
        await executeAppleScriptWithOsascript(script: doSh)
        // 安装成功后写入版本标记，下次启动时跳过安装
        let markerFile = AppHomePath + "/.installed_version"
        try? appVersion.write(toFile: markerFile, atomically: true, encoding: .utf8)
    }

    // 高版本macos执行NSAppleScript会出现授权失败
    func executeAppleScriptWithOsascript(script: String) async {
        do {
            // Assuming runCommand is sync; wrap in continuation for async
            let output = try await withCheckedThrowingContinuation { continuation in
                do {
                    let escapedScript = script
                        .replacingOccurrences(of: "\\", with: "\\\\")
                        .replacingOccurrences(of: "\"", with: "\\\"")
                    let appleScript = "do shell script \"\(escapedScript)\" with administrator privileges"
                    let result = try runCommand(at: "/usr/bin/osascript", with: ["-e", appleScript])
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
            logger.info("executeAppleScript-Output: \(output)")
        } catch {
            logger.info("executeAppleScript-Error: \(error)")
            DispatchQueue.main.sync {
                let title = String(localized: .InstallFailed)
                let toast = "\(String(localized: .InstallFailedManual))\n \(script)"
                alertDialog(title: title, message: toast)
            }
        }
    }
}
