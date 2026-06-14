//
//  LogRotation.swift
//  V2rayU
//
//  日志轮转和异常日志分离工具
//

import Foundation
import OSLog

struct LogRotation {
    static let maxLogSize: Int64 = 5 * 1024 * 1024 // 5MB
    static let maxBackupCount = 3
    static let errorLogFileName = "error.log"
    
    static var errorLogFilePath: String {
        return AppHomePath + "/" + errorLogFileName
    }
    
    static var recentErrorLogFilePath: String {
        return AppHomePath + "/recent_error.log"
    }
    
    static func rotateIfNeeded() {
        let path = coreLogFilePath
        
        guard FileManager.default.fileExists(atPath: path),
              let attrs = try? FileManager.default.attributesOfItem(atPath: path),
              let size = attrs[.size] as? Int64,
              size > maxLogSize else {
            return
        }
        
        rotateLog()
    }
    
    static func rotateLog() {
        let path = coreLogFilePath
        
        for i in (1..<maxBackupCount).reversed() {
            let oldPath = "\(path).\(i)"
            let newPath = "\(path).\(i + 1)"
            
            if FileManager.default.fileExists(atPath: newPath) {
                try? FileManager.default.removeItem(atPath: newPath)
            }
            
            if FileManager.default.fileExists(atPath: oldPath) {
                try? FileManager.default.moveItem(atPath: oldPath, toPath: newPath)
            }
        }
        
        let backupPath = "\(path).1"
        if FileManager.default.fileExists(atPath: backupPath) {
            try? FileManager.default.removeItem(atPath: backupPath)
        }
        
        if FileManager.default.fileExists(atPath: path) {
            try? FileManager.default.moveItem(atPath: path, toPath: backupPath)
        }
        
        FileManager.default.createFile(atPath: path, contents: nil)
        
        logger.info("Log rotated: \(path) -> \(backupPath)")
    }
    
    static func extractErrors(keepRecentLines: Int = 500) {
        let sourcePath = coreLogFilePath
        let destPath = recentErrorLogFilePath
        
        guard let content = try? String(contentsOfFile: sourcePath, encoding: .utf8) else {
            return
        }
        
        let lines = content.components(separatedBy: .newlines)
        let recentLines = Array(lines.suffix(keepRecentLines))
        
        let errorLines = recentLines.filter { line in
            let lower = line.lowercased()
            return lower.contains("[error]") || lower.contains("[warning]") ||
                   lower.contains("error") || lower.contains("failed") ||
                   lower.contains("timeout") || lower.contains("denied")
        }
        
        if errorLines.isEmpty {
            try? "".write(toFile: destPath, atomically: true, encoding: .utf8)
            return
        }
        
        let timestamp = ISO8601DateFormatter().string(from: Date())
        var header = "// Extracted error logs at \(timestamp)\n"
        header += "// Total error lines: \(errorLines.count)\n\n"
        
        let result = header + errorLines.joined(separator: "\n")
        try? result.write(toFile: destPath, atomically: true, encoding: .utf8)
        
        logger.info("Extracted \(errorLines.count) error lines to \(destPath)")
    }
    
    /// 按 session 轮转: 将当前日志 rename → <path>.YYYYMMDD-HHmmss, 创建新空文件
    static func rotateSessionLog(at path: String) {
        guard FileManager.default.fileExists(atPath: path),
              let attrs = try? FileManager.default.attributesOfItem(atPath: path),
              let size = attrs[.size] as? Int64, size > 0 else {
            // 文件不存在或为空则不用备份
            return
        }
        let df = DateFormatter()
        df.dateFormat = "yyyyMMdd-HHmmss"
        let backupPath = "\(path).\(df.string(from: Date()))"
        try? FileManager.default.moveItem(atPath: path, toPath: backupPath)
        FileManager.default.createFile(atPath: path, contents: nil)
    }

    /// 清理 session 轮转备份 (保留最近 maxBackupCount 个)
    static func cleanSessionBackups(at path: String) {
        let dir = (path as NSString).deletingLastPathComponent
        let base = (path as NSString).lastPathComponent
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: dir) else { return }
        let backups = files
            .filter { $0.hasPrefix(base + ".") }
            .filter { $0.count > base.count + 1 } // core.log. 略过 core.log 自身
            .sorted(by: >) // 按文件名倒序 (最新在前)
        if backups.count > maxBackupCount {
            for name in backups[maxBackupCount...] {
                try? FileManager.default.removeItem(atPath: (dir as NSString).appendingPathComponent(name))
            }
        }
    }

    static func clearAllLogs() {
        // 所有日志文件现在都在用户目录下，直接清空
        let userPaths = [coreLogFilePath, recentErrorLogFilePath, tunLogFilePath, runTunLogFilePath]
        for path in userPaths {
            if FileManager.default.fileExists(atPath: path) {
                try? "".write(toFile: path, atomically: true, encoding: .utf8)
            }
        }

        for i in 1...maxBackupCount {
            let backupPath = "\(coreLogFilePath).\(i)"
            try? FileManager.default.removeItem(atPath: backupPath)
        }

        // 清理 session 备份文件
        for path in [coreLogFilePath, tunLogFilePath, runTunLogFilePath] {
            let dir = (path as NSString).deletingLastPathComponent
            let base = (path as NSString).lastPathComponent
            guard let files = try? FileManager.default.contentsOfDirectory(atPath: dir) else { continue }
            let sessionBackups = files.filter { $0.hasPrefix(base + ".") && $0.count > base.count + 1 }
            for name in sessionBackups {
                try? FileManager.default.removeItem(atPath: (dir as NSString).appendingPathComponent(name))
            }
        }

        logger.info("All logs cleared")
    }

    /// 获取当前日志文件列表（含 session 备份）
    static func getLogFiles() -> [(name: String, path: String, size: Int64)] {
        var files: [(name: String, path: String, size: Int64)] = []

        let allFiles = [
            (name: "当前日志", path: coreLogFilePath),
            (name: "异常日志", path: recentErrorLogFilePath),
            (name: "TUN日志", path: tunLogFilePath),
            (name: "TUN启动日志", path: runTunLogFilePath)
        ]

        for (name, path) in allFiles {
            if FileManager.default.fileExists(atPath: path),
               let attrs = try? FileManager.default.attributesOfItem(atPath: path),
               let size = attrs[.size] as? Int64 {
                files.append((name: name, path: path, size: size))
            }
        }

        for i in 1...maxBackupCount {
            let backupPath = "\(coreLogFilePath).\(i)"
            if FileManager.default.fileExists(atPath: backupPath),
               let attrs = try? FileManager.default.attributesOfItem(atPath: backupPath),
               let size = attrs[.size] as? Int64 {
                files.append((name: "备份 \(i)", path: backupPath, size: size))
            }
        }

        // session 备份
        let sessionPaths = [
            (name: "Session 备份", path: coreLogFilePath),
            (name: "TUN Session 备份", path: tunLogFilePath),
            (name: "TUN 启动 Session 备份", path: runTunLogFilePath),
        ]
        for (_, path) in sessionPaths {
            let dir = (path as NSString).deletingLastPathComponent
            let base = (path as NSString).lastPathComponent
            guard let entries = try? FileManager.default.contentsOfDirectory(atPath: dir) else { continue }
            for entry in entries where entry.hasPrefix(base + ".") && entry.count > base.count + 1 {
                let full = (dir as NSString).appendingPathComponent(entry)
                if let attrs = try? FileManager.default.attributesOfItem(atPath: full),
                   let size = attrs[.size] as? Int64 {
                    files.append((name: entry, path: full, size: size))
                }
            }
        }

        return files
    }
}
