//
//  Util.swift
//  V2rayU
//
//  Created by yanue on 2024/12/25.
//  Copyright © 2024 yanue. All rights reserved.

import Foundation
import Cocoa
import Network

func getArch() -> String {
    #if arch(arm64)
        return "arm64"
    #else
        return "amd64"
    #endif
}

func getCoreShortVersion() -> String {
    let version = getCoreVersion()
    logger.debug("getCoreShortVersion: \(version)")
    // Xray 1.8.20 (Xray, Penetrates Everything.) 8deb953 (go1.22.5 darwin/arm64)
    // 正则提取类似 1.8.20 ,1.8 等
    let pattern = #"(\d+\.\d+(\.\d+)?)"#
    let regex = try! NSRegularExpression(pattern: pattern, options: [])
    let nsString = version as NSString
    let results = regex.matches(in: version, options: [], range: NSRange(location: 0, length: nsString.length))
    if let match = results.first {
        let shortVersion = nsString.substring(with: match.range(at: 1))
        return shortVersion
    }
    // 按照空格分割，取第2个
    let components = version.split(separator: " ")
    if components.count >= 2 {
        return String(components[1])
    }
    return version
}

func getCoreVersion() -> String {
    guard FileManager.default.fileExists(atPath: v2rayCoreFile) else {
        return "Not Found"
    }
    if let output = shell(launchPath: v2rayCoreFile, arguments: ["version"]) {
        let lines = output.split(separator: "\n")
        if let firstLine = lines.first {
            return String(firstLine)
        }
        return output
    }
    return "Unknown"
}

func getAppVersion() -> String {
    return "\(Bundle.main.infoDictionary!["CFBundleShortVersionString"] ?? "")"
}
func getAppBuild() -> String {
    return "\(Bundle.main.infoDictionary!["CFBundleVersion"] ?? "")"
}
func checkFileIsRootAdmin(file: String) -> Bool {
    do {
        let fileAttrs = try FileManager.default.attributesOfItem(atPath: file)
        var ownerUser = ""
        var groupUser = ""
        for attr in fileAttrs {
            if attr.key.rawValue == "NSFileOwnerAccountName" {
                ownerUser = attr.value as! String
            }
            if attr.key.rawValue == "NSFileGroupOwnerAccountName" {
                groupUser = attr.value as! String
            }
        }
        logger.info("checkFileIsRootAdmin: file=\(file),owner=\(ownerUser),group=\(groupUser)")
        return ownerUser == "root" && groupUser == "admin"
    } catch {
        logger.info("\(error)")
    }
    return false
}

// get ip address

func GetIPAddresses() -> String? {
    var addresses = [String]()

    var ifaddr: UnsafeMutablePointer<ifaddrs>?
    if getifaddrs(&ifaddr) == 0 {
        var ptr = ifaddr
        while ptr != nil {
            let flags = Int32(ptr!.pointee.ifa_flags)
            var addr = ptr!.pointee.ifa_addr.pointee
            if (flags & (IFF_UP | IFF_RUNNING | IFF_LOOPBACK)) == (IFF_UP | IFF_RUNNING) {
                if addr.sa_family == UInt8(AF_INET) { // just ipv4
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    if getnameinfo(&addr, socklen_t(addr.sa_len), &hostname, socklen_t(hostname.count), nil, socklen_t(0), NI_NUMERICHOST) == 0 {
                        if let address = String(validatingUTF8: hostname) {
                            addresses.append(address)
                        }
                    }
                }
            }
            ptr = ptr!.pointee.ifa_next
        }
        freeifaddrs(ifaddr)
    }
    return addresses.first
}


func showDock(state: Bool) {
    DispatchQueue.main.async {
        // Get transform state.
        var transformState: ProcessApplicationTransformState
        if state {
            transformState = ProcessApplicationTransformState(kProcessTransformToForegroundApplication)
        } else {
            transformState = ProcessApplicationTransformState(kProcessTransformToUIElementApplication)
        }

        // Show / hide dock icon.
        var psn = ProcessSerialNumber(highLongOfPSN: 0, lowLongOfPSN: UInt32(kCurrentProcess))
        TransformProcessType(&psn, transformState)
        if state {
            // bring to front
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}

func noticeTip(title: String = "", informativeText: String = "") {
    makeToast(message: title + " : " + informativeText)
}


func getRandomPort() -> UInt16 {
    return UInt16.random(in: 49152...65535)
}


func formatByte(_ bytesPerSecond: Double) -> String {
    let formatter = ByteCountFormatter()
    formatter.allowedUnits = .useAll
    formatter.countStyle = .file

    let speedInBytesPerSecond = max(0, Int64(bytesPerSecond))
    let formatted = formatter.string(fromByteCount: speedInBytesPerSecond)

    return formatted
}


// clear v2ray-core.log file
func clearLogFile(logFilePath: String) {
    let logFile = URL(fileURLWithPath: logFilePath)
    do {
        if FileManager.default.fileExists(atPath: logFilePath) {
            try FileManager.default.removeItem(at: logFile)
        }
        // create new file
        FileManager.default.createFile(atPath: logFilePath, contents: nil, attributes: nil)
    } catch let error {
        logger.info("clear log file fail: \(error)")
        var title = String(localized: .ClearLogFileFailed)
        alertDialog(title: title, message: error)
    }
}

func truncateLogFile(_ logFilePath: String) {
    let logFile = URL(fileURLWithPath: logFilePath)
    do {
        if FileManager.default.fileExists(atPath: logFilePath) {
            // truncate log file,  write empty string
            try "".write(to: logFile, atomically: true, encoding: String.Encoding.utf8)
        }
    } catch let error {
        logger.info("truncate log file fail: \(error)")
        var title = String(localized: .ClearLogFileFailed)
        alertDialog(title: title, message: toast)
    }
}

func getHttpProxyPort() -> UInt16 {
    return UInt16(UserDefaults.get(forKey: .localHttpPort)) ?? 1087
}

func getSocksProxyPort() -> UInt16 {
    return UInt16(UserDefaults.get(forKey: .localSockPort)) ?? 1080
}

func getPacPort() -> UInt16 {
    return UInt16(UserDefaults.get(forKey: .localPacPort)) ?? 11085
}

func getListenAddress() -> String {
    let allowLAN = UserDefaults.getBool(forKey: .allowLAN)
    if allowLAN{
        return "0.0.0.0"
    } else {
        return "127.0.0.1"
    }
}


func getPacAddress() -> String {
    let allowLAN = UserDefaults.getBool(forKey: .allowLAN)
    if allowLAN{
        return GetIPAddresses() ?? "127.0.0.1"
    } else {
        return "127.0.0.1"
    }
}

func OpenLogs(logFilePath: String) {
    if !FileManager.default.fileExists(atPath: logFilePath) {
        let txt = ""
        try! txt.write(to: URL(fileURLWithPath: logFilePath), atomically: true, encoding: String.Encoding.utf8)
    }

    let task = Process.launchedProcess(launchPath: "/usr/bin/open", arguments: [logFilePath])
    task.waitUntilExit()
    if task.terminationStatus == 0 {
        NSLog("open logs succeeded.")
    } else {
        NSLog("open logs failed.")
    }
}

// 根据延迟返回颜色
func getSpeedColor(latency: Double) -> NSColor {
    if latency <= 0 {
        return NSColor.systemGray
    } else if latency < 200 {
        return NSColor.systemGreen
    } else if latency < 500 {
        return NSColor.systemOrange
    } else {
        return NSColor.systemRed
    }
}

extension Int64 {
    var humanSize: String {
        let units = ["B", "KB", "MB", "GB", "TB"]
        var value = Double(self)
        var index = 0
        if value < 1024 {
            return ""
        }
        while value >= 1024 && index < units.count - 1 {
            value /= 1024
            index += 1
        }
        return String(format: "%.2f %@", value, units[index])
    }
}
