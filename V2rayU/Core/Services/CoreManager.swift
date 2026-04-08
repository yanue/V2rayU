//
//  CoreManager.swift
//  V2rayU
//
//  Created by yanue on 2025/10/31.
//

import Foundation

final class CoreManager {
    private let fm = FileManager.default
    private let destPath = xrayCorePath
    private var backupPath: String { destPath + ".bak" }

    func backupCore() {
        if fm.fileExists(atPath: destPath) {
            try? fm.removeItem(atPath: backupPath)
            try? fm.copyItem(atPath: destPath, toPath: backupPath)
        }
    }

    func recoverCore(_ msg: String) throws {
        if fm.fileExists(atPath: backupPath) {
            try fm.removeItem(atPath: destPath)
            try fm.copyItem(atPath: backupPath, toPath: destPath)
        }
        throw NSError(domain: "CoreRecover", code: -1, userInfo: [NSLocalizedDescriptionKey: msg])
    }

    func replaceWithDownloaded(zipFile: String) throws -> String {
        backupCore()
        do {
            let msg = try runCommand(at: "/usr/bin/unzip", with: ["-o", zipFile, "-d", destPath])

            // 重命名 xray 文件 (下载的文件可能是 xray 或 xray-arm64，需要重命名为 xray-64 或 xray-arm64)
            try renameXrayCore()
  
            // 设置核心文件权限 (需要 sudo)
            let coreFile = xrayCoreFile
            if fm.fileExists(atPath: coreFile) {
                _ = try runCommand(at: "/bin/chmod", with: ["755", coreFile])
            }

            // 去除 quarantine - 需要 sudo
            _ = try runCommand(at: "/usr/bin/sudo", with: ["-n", "/usr/bin/xattr", "-rd", "com.apple.quarantine", AppHomePath+"/"])

            Task { await V2rayLaunch.shared.restart() }
            try? fm.removeItem(atPath: backupPath)
            try? fm.removeItem(atPath: zipFile)
            return msg
        } catch {
            try recoverCore("Operation failed: \(error.localizedDescription)")
            throw error
        }
    }

    private func renameXrayCore() throws {
        // 下载的文件可能名为: xray, xray-arm64, xray-macos-arm64-v8a, xray-macos
        // 需要重命名为: xray-64 (x86_64) 或 xray-arm64 (arm64)
        let targetPath = xrayCoreFile

        // 查找可能存在的 xray 文件
        let possibleNames = ["xray"]

        for name in possibleNames {
            let sourcePath = destPath + "/" + name

            if fm.fileExists(atPath: sourcePath) && sourcePath != targetPath {
                // 使用 sudo mv 重命名（需要 root 权限）
                _ = try runCommand(at: "/usr/bin/sudo", with: ["-n", "/bin/mv", sourcePath, targetPath])
                break
            }
        }
    }
}
