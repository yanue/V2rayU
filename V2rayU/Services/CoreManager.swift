//
//  CoreManager.swift
//  V2rayU
//
//  Created by yanue on 2025/10/31.
//

import Foundation

final class CoreManager {
    private let fm = FileManager.default
    private let destPath = AppHomePath + "/xray-core"
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
            try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: destPath)
            Task { await V2rayLaunch.shared.restart() }
            try? fm.removeItem(atPath: backupPath)
            try? fm.removeItem(atPath: zipFile)
            return msg
        } catch {
            try recoverCore("Operation failed: \(error.localizedDescription)")
            throw error
        }
    }
}
