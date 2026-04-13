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
    
    static func getLogFiles() -> [(name: String, path: String, size: Int64)] {
        var files: [(name: String, path: String, size: Int64)] = []
        
        let allFiles = [
            (name: "当前日志", path: coreLogFilePath),
            (name: "异常日志", path: recentErrorLogFilePath),
            (name: "TUN日志", path: tunLogFilePath)
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
        
        return files
    }
    
    static func clearAllLogs() {
        // 所有日志文件现在都在用户目录下，直接清空
        let userPaths = [coreLogFilePath, recentErrorLogFilePath, tunLogFilePath]
        for path in userPaths {
            if FileManager.default.fileExists(atPath: path) {
                try? "".write(toFile: path, atomically: true, encoding: .utf8)
            }
        }

        for i in 1...maxBackupCount {
            let backupPath = "\(coreLogFilePath).\(i)"
            try? FileManager.default.removeItem(atPath: backupPath)
        }
        
        logger.info("All logs cleared")
    }
}
