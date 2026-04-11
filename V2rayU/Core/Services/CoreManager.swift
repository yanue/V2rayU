//
//  CoreManager.swift
//  V2rayU
//
//  Created by yanue on 2025/10/31.
//

import Foundation

final class CoreManager {
    private let fm = FileManager.default
    private let destPath = xrayCorePath // /usr/local/v2rayu/bin/xray-core (root:wheel)
    private var backupPath: String { destPath + ".bak" }

    func backupCore() {
        if fm.fileExists(atPath: destPath) {
            // root:wheel 目录，需要 sudo
            _ = try? runCommand(at: "/usr/bin/sudo", with: ["-n", "/bin/rm", "-rf", backupPath])
            _ = try? runCommand(at: "/usr/bin/sudo", with: ["-n", "/bin/cp", "-rf", destPath, backupPath])
        }
    }

    func recoverCore(_ msg: String) throws {
        if fm.fileExists(atPath: backupPath) {
            _ = try runCommand(at: "/usr/bin/sudo", with: ["-n", "/bin/rm", "-rf", destPath])
            _ = try runCommand(at: "/usr/bin/sudo", with: ["-n", "/bin/cp", "-rf", backupPath, destPath])
        }
        throw NSError(domain: "CoreRecover", code: -1, userInfo: [NSLocalizedDescriptionKey: msg])
    }

    func replaceWithDownloaded(zipFile: String) throws -> String {
        backupCore()
        do {
            // 目标目录是 /usr/local/v2rayu/bin/xray-core (root:wheel)，需要 sudo 解压
            let msg = try runCommand(at: "/usr/bin/sudo", with: ["-n", "/usr/bin/unzip", "-o", zipFile, "-d", destPath])

            // 重命名 xray 文件 (下载的文件可能是 xray 或 xray-arm64，需要重命名为 xray-64 或 xray-arm64)
            try renameXrayCore()
  
            // 设置核心文件权限 (bin 目录属于 root:wheel)
            let coreFile = xrayCoreFile
            if fm.fileExists(atPath: coreFile) {
                _ = try runCommand(at: "/usr/bin/sudo", with: ["-n", "/bin/chmod", "-R", "755", destPath])
                _ = try runCommand(at: "/usr/bin/sudo", with: ["-n", "/bin/chown", "-R", "root:wheel", destPath])
            }

            // 去除 quarantine
            _ = try runCommand(at: "/usr/bin/sudo", with: ["-n", "/usr/bin/xattr", "-rd", "com.apple.quarantine", AppBinRoot])

            Task { await V2rayLaunch.shared.restart() }
            _ = try? runCommand(at: "/usr/bin/sudo", with: ["-n", "/bin/rm", "-rf", backupPath])
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
