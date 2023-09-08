//
//  Util.swift
//  V2rayU
//
//  Created by yanue on 2018/10/12.
//  Copyright © 2018 yanue. All rights reserved.
//

import Cocoa

extension UserDefaults {
    enum KEY: String {
        // v2ray-core version
        case xRayCoreVersion
        // v2ray server item list
        case v2rayServerList
        // v2ray subscribe item list
        case v2raySubList
        // current v2ray server name
        case v2rayCurrentServerName
        // v2ray-core turn on status
        case v2rayTurnOn
        // v2ray-core log level
        case v2rayLogLevel
        // v2ray dns json txt
        case v2rayDnsJson

        // auth check version
        case autoCheckVersion
        // auto launch after login
        case autoLaunch
        // auto clear logs
        case autoClearLog
        // auto update servers
        case autoUpdateServers
        // auto select Fastest server
        case autoSelectFastestServer
        // pac|manual|global
        case runMode
        // gfw pac list url
        case gfwPacListUrl
        // server iterms group by subscription remark
        case grpBySubsrptnRmrk

        // base settings
        // http host
        case localHttpHost
        // http port
        case localHttpPort
        // sock host
        case localSockHost
        // sock port
        case localSockPort
        // dns servers
        case dnsServers
        // enable udp
        case enableUdp
        // enable mux
        case enableMux
        // enable Sniffing
        case enableSniffing
        // mux Concurrent
        case muxConcurrent
        // pacPort
        case localPacPort

        // for routing rule
        case routingDomainStrategy
        case routingRule
        case routingProxyDomains
        case routingProxyIps
        case routingDirectDomains
        case routingDirectIps
        case routingBlockDomains
        case routingBlockIps
        case Exception
    }

    static func setBool(forKey key: KEY, value: Bool) {
        UserDefaults.standard.set(value, forKey: key.rawValue)
    }

    static func getBool(forKey key: KEY) -> Bool {
        return UserDefaults.standard.bool(forKey: key.rawValue)
    }

    static func set(forKey key: KEY, value: String) {
        UserDefaults.standard.set(value, forKey: key.rawValue)
    }

    static func get(forKey key: KEY) -> String? {
        return UserDefaults.standard.string(forKey: key.rawValue)
    }

    static func del(forKey key: KEY) {
        UserDefaults.standard.removeObject(forKey: key.rawValue)
    }

    static func setArray(forKey key: KEY, value: [String]) {
        UserDefaults.standard.set(value, forKey: key.rawValue)
    }

    static func getArray(forKey key: KEY) -> [String]? {
        return UserDefaults.standard.array(forKey: key.rawValue) as? [String]
    }

    static func delArray(forKey key: KEY) {
        UserDefaults.standard.removeObject(forKey: key.rawValue)
    }
}

func getPacUrl() -> String {
    var pacPort = UInt16(UserDefaults.get(forKey: .localPacPort) ?? "11085") ?? 11085
    var pacUrl = "http://127.0.0.1:" + String(pacPort) + "/proxy.js"
    return pacUrl
}

func getConfigUrl() -> String {
    var pacPort = UInt16(UserDefaults.get(forKey: .localPacPort) ?? "11085") ?? 11085
    var configUrl = "http://127.0.0.1:" + String(pacPort) + "/config.json"
    return configUrl
}

extension String {
    // version compare
    func versionToInt() -> [Int] {
        return components(separatedBy: ".")
            .map {
                Int($0) ?? 0
            }
    }

    //: ### Base64 encoding a string
    func base64Encoded() -> String? {
        if let data = data(using: .utf8) {
            return data.base64EncodedString()
        }
        return nil
    }

    //: ### Base64 decoding a string
    func base64Decoded() -> String? {
        if let _ = range(of: ":")?.lowerBound {
            return self
        }
        let base64String = replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        let padding = base64String.count + (base64String.count % 4 != 0 ? (4 - base64String.count % 4) : 0)
        if let decodedData = Data(base64Encoded: base64String.padding(toLength: padding, withPad: "=", startingAt: 0), options: NSData.Base64DecodingOptions(rawValue: 0)), let decodedString = NSString(data: decodedData, encoding: String.Encoding.utf8.rawValue) {
            return decodedString as String
        }
        return nil
    }

    //: isValidUrl
    func isValidUrl() -> Bool {
        let urlRegEx = "(https?|ftp|file)://[-A-Za-z0-9+&@#/%?=~_|!:,.;]+[-A-Za-z0-9+&@#/%=~_|]"
        let urlTest = NSPredicate(format: "SELF MATCHES %@", urlRegEx)
        let result = urlTest.evaluate(with: self)
        return result
    }

    // 将原始的url编码为合法的url
    func urlEncoded() -> String {
        let encodeUrlString = addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        return encodeUrlString ?? self
    }

    // 将编码后的url转换回原始的url
    func urlDecoded() -> String {
        return removingPercentEncoding ?? self
    }
}

//  run custom shell
// demo:
// shell("/bin/bash",["-c","ls"])
// shell("/bin/bash",["-c","cd ~ && ls -la"])
func shell(launchPath: String, arguments: [String]) -> String? {
    let task = Process()
    task.launchPath = launchPath
    task.arguments = arguments

    let pipe = Pipe()
    task.standardOutput = pipe
    task.launch()

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let output = String(data: data, encoding: String.Encoding.utf8)!

    if output.count > 0 {
        // remove newline character.
        let lastIndex = output.index(before: output.endIndex)
        return String(output[output.startIndex ..< lastIndex])
    }

    return output
}

// → /var/folders/v8/tft1q…/T/…-8DC6DD131DC1/report.pdf
//  guard let tmp = try? TemporaryFile(creatingTempDirectoryForFilename: "v2ray-macos.zip") else {
//      print("err get tmp")
//      return
//  }
//  let fileUrl = tmp.fileURL

/// 临时目录中临时文件的包装（Wrapper）。目录是为文件而特别创建的，因此不再需要文件时，可以安全地删除该文件。
///
/// 在你不再需要文件时，调用 `deleteDirectory`
struct TemporaryFile {
    let directoryURL: URL
    let fileURL: URL
    /// 删除临时目录和其中的所有文件。
    let deleteDirectory: () throws -> Void
    /// 使用唯一的名字来创建临时目录，并且使用 `fileURL` 目录中名为 `filename` 的文件来初始化接收者。
    ///
    /// - 注意: 这里不会创建文件！
    init(creatingTempDirectoryForFilename filename: String) throws {
        let (directory, deleteDirectory) = try FileManager.default
            .urlForUniqueTemporaryDirectory()
        directoryURL = directory
        fileURL = directory.appendingPathComponent(filename)
        self.deleteDirectory = deleteDirectory
    }
}

extension FileManager {
    /// 创建一个有唯一名字的临时目录并返回 URL。
    ///
    /// - 返回：目录 URL 的 tuple 以及删除函数。
    ///   完成后调用函数删除目录。
    ///
    /// - 注意: 在应用退出后，不应该存在依赖的临时目录。
    func urlForUniqueTemporaryDirectory(preferredName: String? = nil) throws -> (url: URL, deleteDirectory: () throws -> Void) {
        let basename = preferredName ?? UUID().uuidString

        var counter = 0
        var createdSubdirectory: URL?
        repeat {
            do {
                let subdirName = counter == 0 ? basename : "\(basename)-\(counter)"
                let subdirectory = temporaryDirectory.appendingPathComponent(subdirName, isDirectory: true)
                try createDirectory(at: subdirectory, withIntermediateDirectories: false)
                createdSubdirectory = subdirectory
            } catch CocoaError.fileWriteFileExists {
                // 捕捉到文件已存在的错误，并使用其他名字重试。
                // 其他错误传播到调用方。
                counter += 1
            }
        } while createdSubdirectory == nil

        let directory = createdSubdirectory!
        let deleteDirectory: () throws -> Void = {
            try self.removeItem(at: directory)
        }
        return (directory, deleteDirectory)
    }
}

func getAppVersion() -> String {
    return "\(Bundle.main.infoDictionary!["CFBundleShortVersionString"] ?? "")"
}

extension URL {
    func queryParams() -> [String: Any] {
        var dict = [String: Any]()

        if let components = URLComponents(url: self, resolvingAgainstBaseURL: false) {
            if let queryItems = components.queryItems {
                for item in queryItems {
                    dict[item.name] = item.value!
                }
            }
            return dict
        } else {
            return [:]
        }
    }
}

extension utsname {
    static var sMachine: String {
        var utsname = utsname()
        uname(&utsname)
        return withUnsafePointer(to: &utsname.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: Int(_SYS_NAMELEN)) {
                String(cString: $0)
            }
        }
    }

    static var isAppleSilicon: Bool {
        sMachine == "arm64"
    }
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

// https://stackoverflow.com/questions/65670932/how-to-find-a-free-local-port-using-swift
func findFreePort() -> UInt16 {
    var port: UInt16 = 8000

    let socketFD = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP)
    if socketFD == -1 {
        // print("Error creating socket: \(errno)")
        return port
    }

    var hints = addrinfo(
        ai_flags: AI_PASSIVE,
        ai_family: AF_INET,
        ai_socktype: SOCK_STREAM,
        ai_protocol: 0,
        ai_addrlen: 0,
        ai_canonname: nil,
        ai_addr: nil,
        ai_next: nil
    )

    var addressInfo: UnsafeMutablePointer<addrinfo>?
    var result = getaddrinfo(nil, "0", &hints, &addressInfo)
    if result != 0 {
        // print("Error getting address info: \(errno)")
        close(socketFD)

        return port
    }

    result = Darwin.bind(socketFD, addressInfo!.pointee.ai_addr, socklen_t(addressInfo!.pointee.ai_addrlen))
    if result == -1 {
        // print("Error binding socket to an address: \(errno)")
        close(socketFD)

        return port
    }

    result = Darwin.listen(socketFD, 1)
    if result == -1 {
        // print("Error setting socket to listen: \(errno)")
        close(socketFD)

        return port
    }

    var addr_in = sockaddr_in()
    addr_in.sin_len = UInt8(MemoryLayout.size(ofValue: addr_in))
    addr_in.sin_family = sa_family_t(AF_INET)

    var len = socklen_t(addr_in.sin_len)
    result = withUnsafeMutablePointer(to: &addr_in, {
        $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
            Darwin.getsockname(socketFD, $0, &len)
        }
    })

    if result == 0 {
        port = addr_in.sin_port
    }

    Darwin.shutdown(socketFD, SHUT_RDWR)
    close(socketFD)

    return port
}

func isPortOpen(port: UInt16) -> Bool {
    let process = Process()
    process.launchPath = "/usr/sbin/lsof"
    process.arguments = ["-i", ":\(port)"]

    let pipe = Pipe()
    process.standardOutput = pipe
    process.launch()

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let output = String(data: data, encoding: .utf8)
    return output?.contains("LISTEN") ?? false
}

func getUsablePort(port: UInt16) -> (Bool,UInt16) {
    var i = 0
    var isNew = false
    var _port = port
    while i < 100 {
        let opened = isPortOpen(port: _port)
        NSLog("getUsablePort: try=\(i) port=\(_port) opened=\(opened)")
        if !opened {
            return (isNew, _port)
        }
        isNew = true
        i += 1
        _port += 1
    }
    return (isNew, _port)
}
