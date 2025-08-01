//
//  Util.swift
//  V2rayU
//
//  Created by yanue on 2024/12/25.
//  Copyright © 2024 yanue. All rights reserved.

import Foundation
import Cocoa

func getArch() -> String {
    #if arch(arm64)
        return "arm64"
    #else
        return "amd64"
    #endif
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
        print("checkFileIsRootAdmin: file=\(file),owner=\(ownerUser),group=\(groupUser)")
        return ownerUser == "root" && groupUser == "admin"
    } catch {
        print("\(error)")
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


func vold() {
    
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
        NSLog("clear log file fail: \(error)")
        var title = "Clear log file failed"
        var toast = "Error: \(error)"
        if isMainland {
            title = "清除日志文件失败"
            toast = "错误: \(error)"
        }
        alertDialog(title: title, message: toast)
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
        NSLog("truncate log file fail: \(error)")
        var title = "Truncate log file failed"
        var toast = "Error: \(error)"
        if isMainland {
            title = "清除日志文件失败"
            toast = "错误: \(error)"
        }
        alertDialog(title: title, message: toast)
    }
}
