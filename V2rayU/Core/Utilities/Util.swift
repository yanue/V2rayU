//
//  Util.swift
//  V2rayU
//
//  Created by yanue on 2024/12/25.
//  Copyright © 2024 yanue. All rights reserved.

import Foundation
import Cocoa
import Network

private let coreVersionCacheLock = NSLock()
private nonisolated(unsafe) var cachedCoreVersion: String?
private let singboxVersionCacheLock = NSLock()
private nonisolated(unsafe) var cachedSingboxVersion: String?

func getArch() -> String {
    #if arch(arm64)
        return "arm64"
    #else
        return "x86_64"
    #endif
}

func clearCoreVersionCache() {
    coreVersionCacheLock.lock()
    cachedCoreVersion = nil
    coreVersionCacheLock.unlock()
}

func clearSingboxVersionCache() {
    singboxVersionCacheLock.lock()
    cachedSingboxVersion = nil
    singboxVersionCacheLock.unlock()
}

func getCoreShortVersion(refresh: Bool = false) -> String {
    let version = getCoreVersion(refresh: refresh)
    logger.debug("getCoreShortVersion: \(version)")
    if let parsed = XrayVersion(version) {
        return parsed.description
    }
    // 按照空格分割，取第2个
    let components = version.split(separator: " ")
    if components.count >= 2 {
        return String(components[1])
    }
    return version
}

func getCoreVersion(refresh: Bool = false) -> String {
    coreVersionCacheLock.lock()
    if !refresh, let cachedCoreVersion {
        coreVersionCacheLock.unlock()
        return cachedCoreVersion
    }
    coreVersionCacheLock.unlock()

    let resolvedVersion: String
    guard FileManager.default.fileExists(atPath: xrayCoreFile) else {
        resolvedVersion = "Not Found"
        coreVersionCacheLock.lock()
        cachedCoreVersion = resolvedVersion
        coreVersionCacheLock.unlock()
        return resolvedVersion
    }
    if let output = shell(launchPath: xrayCoreFile, arguments: ["version"]) {
        let lines = output.split(separator: "\n")
        if let firstLine = lines.first {
            resolvedVersion = String(firstLine)
        } else {
            resolvedVersion = output
        }
    } else {
        resolvedVersion = "Unknown"
    }

    coreVersionCacheLock.lock()
    cachedCoreVersion = resolvedVersion
    coreVersionCacheLock.unlock()
    return resolvedVersion
}

func getSingboxShortVersion(refresh: Bool = false) -> String {
    let version = getSingboxVersion(refresh: refresh)
    logger.debug("getSingboxShortVersion: \(version)")
    if let parsed = SingboxVersion(version) {
        return parsed.description
    }
    let components = version.split(separator: " ")
    if components.count >= 2 {
        return String(components[1])
    }
    return version
}

func getSingboxVersion(refresh: Bool = false) -> String {
    singboxVersionCacheLock.lock()
    if !refresh, let cachedSingboxVersion {
        singboxVersionCacheLock.unlock()
        return cachedSingboxVersion
    }
    singboxVersionCacheLock.unlock()

    let singboxFile = getCoreFile(mode: .SingBox)
    let resolvedVersion: String
    guard FileManager.default.fileExists(atPath: singboxFile) else {
        resolvedVersion = "Not Found"
        singboxVersionCacheLock.lock()
        cachedSingboxVersion = resolvedVersion
        singboxVersionCacheLock.unlock()
        return resolvedVersion
    }
    if let output = shell(launchPath: singboxFile, arguments: ["version"]) {
        let lines = output.split(separator: "\n")
        if let firstLine = lines.first {
            resolvedVersion = String(firstLine)
        } else {
            resolvedVersion = output
        }
    } else {
        resolvedVersion = "Unknown"
    }

    singboxVersionCacheLock.lock()
    cachedSingboxVersion = resolvedVersion
    singboxVersionCacheLock.unlock()
    return resolvedVersion
}

func getAppVersion() -> String {
    return "\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] ?? "0.0.0")"
}
func getAppBuild() -> String {
    return "\(Bundle.main.infoDictionary?["CFBundleVersion"] ?? "0")"
}
func checkFileIsRootAdmin(file: String) -> Bool {
    do {
        let fileAttrs = try FileManager.default.attributesOfItem(atPath: file)
        var ownerUser = ""
        var groupUser = ""
        for attr in fileAttrs {
            if attr.key.rawValue == "NSFileOwnerAccountName" {
                ownerUser = attr.value as? String ?? ""
            }
            if attr.key.rawValue == "NSFileGroupOwnerAccountName" {
                groupUser = attr.value as? String ?? ""
            }
        }
        logger.info("checkFileIsRootAdmin: file=\(file),owner=\(ownerUser),group=\(groupUser)")
        return ownerUser == "root" && groupUser == "admin"
    } catch {
        logger.info("\(error)")
    }
    return false
}

func checkFileIsCurrentArch(file: String) -> Bool {
    do {
        let data = try Data(contentsOf: URL(fileURLWithPath: file))
        guard data.count >= 20 else { return false }

        var fileArch: String?

        // 判断 ELF
        if data[0] == 0x7F && data[1] == 0x45 && data[2] == 0x4C && data[3] == 0x46 {
            // e_machine 在偏移 18
            let eMachine = data.withUnsafeBytes { $0.load(fromByteOffset: 18, as: UInt16.self) }
            switch eMachine {
            case 62: fileArch = "x86_64"   // EM_X86_64
            case 183: fileArch = "arm64"   // EM_AARCH64
            default: fileArch = "unknown"
            }
        }
        // 判断 Mach-O
        else if data[0] == 0xCF && data[1] == 0xFA && data[2] == 0xED && data[3] == 0xFE {
            let cpuType = data.withUnsafeBytes { $0.load(fromByteOffset: 4, as: Int32.self) }
            switch cpuType {
            case 0x01000007: fileArch = "x86_64"
            case 0x0100000C: fileArch = "arm64"
            default: fileArch = "unknown"
            }
        }

        // 当前系统架构
        var uts = utsname()
        uname(&uts)
        let machine = withUnsafePointer(to: &uts.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: Int(_SYS_NAMELEN)) {
                String(cString: $0)
            }
        }

        return machine.contains(fileArch ?? "unknown")
    } catch {
        return false
    }
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
                        let hostnameBytes = hostname.prefix { $0 != 0 }.map(UInt8.init(bitPattern:))
                        if let address = String(bytes: hostnameBytes, encoding: .utf8) {
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
        DispatchQueue.main.async {
            let title = String(localized: .ClearLogFileFailed)
            alertDialog(title: title, message: error.localizedDescription)
        }
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
        DispatchQueue.main.async {
            let title = String(localized: .ClearLogFileFailed)
            alertDialog(title: title, message: error.localizedDescription)
        }
    }
}

func getHttpProxyPort() -> UInt16 {
    let port = UserDefaults.getInt(forKey: .localHttpPort, defaultValue: 1087)
    return UInt16(port)
}

func getSocksProxyPort() -> UInt16 {
    let port = UserDefaults.getInt(forKey: .localSockPort, defaultValue: 1080)
    return UInt16(port)
}

func isMixedProxyPortEnabled() -> Bool {
    UserDefaults.getBool(forKey: .enableMixedPort)
}

func getMixedProxyPort() -> UInt16 {
    let port = UserDefaults.getInt(forKey: .mixedPort, defaultValue: Int(getSocksProxyPort()))
    guard port > 0, port <= 65535 else { return getSocksProxyPort() }
    return UInt16(port)
}

func getEffectiveHttpProxyPort() -> UInt16 {
    if isMixedProxyPortEnabled() {
        return getMixedProxyPort()
    }
    return getHttpProxyPort()
}

func getEffectiveSocksProxyPort() -> UInt16 {
    if isMixedProxyPortEnabled() {
        return getMixedProxyPort()
    }
    return getSocksProxyPort()
}

func getPacPort() -> UInt16 {
    let port = UserDefaults.getInt(forKey: .localPacPort, defaultValue: 11085)
    return UInt16(port)
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
        do {
            try "".write(to: URL(fileURLWithPath: logFilePath), atomically: true, encoding: .utf8)
        } catch {
            NSLog("Cannot create log file: \(logFilePath), error: \(error.localizedDescription)")
            noticeTip(title: "Cannot open log", informativeText: "Log file does not exist: \(logFilePath)")
            return
        }
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

// 国家代码转 emoji
func countryCodeToEmoji(_ code: String) -> String {
    guard code.count == 2 else { return "" }
    let base: UInt32 = 127397
    var emoji = ""
    for scalar in code.uppercased().unicodeScalars {
        if let unicode = UnicodeScalar(base + scalar.value) {
            emoji.append(String(unicode))
        }
    }
    return emoji
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

func isFileQuarantined(at path: String) -> Bool {
    let attrName = "com.apple.quarantine"
    let result = getxattr(path, attrName, nil, 0, 0, 0)
    return result >= 0
}

enum CoreVersion: String {
    case legacy
    case latest
}

struct XrayVersion: Comparable, CustomStringConvertible {
    let major: Int
    let minor: Int
    let patch: Int

    init(_ major: Int, _ minor: Int, _ patch: Int = 0) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }

    init?(_ rawValue: String) {
        let pattern = #"(\d+)(?:\.(\d+))?(?:\.(\d+))?"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }
        let nsString = rawValue as NSString
        let range = NSRange(location: 0, length: nsString.length)
        guard let match = regex.firstMatch(in: rawValue, options: [], range: range) else {
            return nil
        }

        let major = Int(nsString.substring(with: match.range(at: 1))) ?? 0
        let minor: Int
        if match.range(at: 2).location != NSNotFound {
            minor = Int(nsString.substring(with: match.range(at: 2))) ?? 0
        } else {
            minor = 0
        }
        let patch: Int
        if match.range(at: 3).location != NSNotFound {
            patch = Int(nsString.substring(with: match.range(at: 3))) ?? 0
        } else {
            patch = 0
        }

        self.init(major, minor, patch)
    }

    var description: String {
        "\(major).\(minor).\(patch)"
    }

    var isCalendarStyle: Bool {
        major >= 20
    }

    static func < (lhs: XrayVersion, rhs: XrayVersion) -> Bool {
        if lhs.major != rhs.major {
            return lhs.major < rhs.major
        }
        if lhs.minor != rhs.minor {
            return lhs.minor < rhs.minor
        }
        return lhs.patch < rhs.patch
    }
}

// allowInsecure 在 Xray-core v26.1.31 首次被移除；v26.2.6 改为延时自动禁用（截止 UTC 2026-06-01 00:00），
// 该日期之后所有 >= 26.1.31 的核心一律硬报错。因此对 >= 26.1.31 的核心都不能再下发 allowInsecure，
// 自签/跳过校验场景必须改用 pinnedPeerCertSha256。
let xrayAllowInsecureRemovedVersion = XrayVersion(26, 1, 31)

/// 当前 Xray-core 是否已移除 allowInsecure（即必须改用 pinnedPeerCertSha256）。
/// 版本无法识别时按"现代核心"处理（返回 true），避免对今天普遍 >= 26.1.31 的核心继续下发已失效字段。
func xrayRequiresPinnedCert(version: XrayVersion? = XrayVersion(getCoreVersion())) -> Bool {
    guard let version else { return true }
    return version >= xrayAllowInsecureRemovedVersion
}

struct SingboxVersion: Comparable, CustomStringConvertible {
    let major: Int
    let minor: Int
    let patch: Int

    init(_ major: Int, _ minor: Int, _ patch: Int = 0) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }

    init?(_ rawValue: String) {
        let pattern = #"(\d+)(?:\.(\d+))?(?:\.(\d+))?"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }
        let nsString = rawValue as NSString
        let range = NSRange(location: 0, length: nsString.length)
        guard let match = regex.firstMatch(in: rawValue, options: [], range: range) else {
            return nil
        }

        let major = Int(nsString.substring(with: match.range(at: 1))) ?? 0
        let minor: Int
        if match.range(at: 2).location != NSNotFound {
            minor = Int(nsString.substring(with: match.range(at: 2))) ?? 0
        } else {
            minor = 0
        }
        let patch: Int
        if match.range(at: 3).location != NSNotFound {
            patch = Int(nsString.substring(with: match.range(at: 3))) ?? 0
        } else {
            patch = 0
        }

        self.init(major, minor, patch)
    }

    var description: String {
        "\(major).\(minor).\(patch)"
    }

    static func < (lhs: SingboxVersion, rhs: SingboxVersion) -> Bool {
        if lhs.major != rhs.major {
            return lhs.major < rhs.major
        }
        if lhs.minor != rhs.minor {
            return lhs.minor < rhs.minor
        }
        return lhs.patch < rhs.patch
    }
}

enum CoreType: String, Codable, CaseIterable, Identifiable {
    case SingBox
    case XrayCore

    var id: Self { self }

    var displayName: String {
        switch self {
        case .SingBox:
            return "Sing-Box"
        case .XrayCore:
            return "Xray"
        }
    }
}

enum ProfileCoreSelection: String, Codable, CaseIterable, Identifiable {
    case auto
    case xray
    case singbox = "sing-box"

    var id: Self { self }

    var displayName: String {
        switch self {
        case .auto:
            return "Auto"
        case .xray:
            return "Xray"
        case .singbox:
            return "Sing-Box"
        }
    }

    var forcedCoreType: CoreType? {
        switch self {
        case .auto:
            return nil
        case .xray:
            return .XrayCore
        case .singbox:
            return .SingBox
        }
    }
}

enum CoreSelectionDefaults {
    static let editableProtocols: [V2rayProtocolOutbound] = [.vmess, .shadowsocks, .socks, .vless, .trojan, .hysteria2, .anytls, .naive]

    static func selection(for protocol: V2rayProtocolOutbound) -> ProfileCoreSelection {
        let key = storageKey(for: `protocol`)
        guard let rawValue = UserDefaults.standard.string(forKey: key),
              let selection = ProfileCoreSelection(rawValue: rawValue) else {
            return .auto
        }
        return selection
    }

    static func setSelection(_ selection: ProfileCoreSelection, for protocol: V2rayProtocolOutbound) {
        UserDefaults.standard.set(selection.rawValue, forKey: storageKey(for: `protocol`))
    }

    static func loadAll() -> [V2rayProtocolOutbound: ProfileCoreSelection] {
        Dictionary(uniqueKeysWithValues: editableProtocols.map { ($0, selection(for: $0)) })
    }

    private static func storageKey(for protocol: V2rayProtocolOutbound) -> String {
        "coreSelection.default.\(`protocol`.rawValue)"
    }
}


@MainActor func openInFinder(path: String) {
    let expandedPath = (path as NSString).expandingTildeInPath
    let url = URL(fileURLWithPath: expandedPath)
    NSApp.activate(ignoringOtherApps: true)
    NSWorkspace.shared.activateFileViewerSelecting([url])
}
