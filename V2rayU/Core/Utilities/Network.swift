//
//  Network.swift
//  V2rayU
//
//  Created by yanue on 2025/11/8.
//

import Foundation
import Network

/// Actor 用于保护一次性 resume 的状态
///
/// 通过 actor 的隔离，确保 resumed 标志只在一个串行上下文里被读写，
/// 避免并发修改与数据竞争，同时保证 continuation 只会被 resume 一次。
actor ResumeFlag {
    private var resumed = false

    /// 尝试恢复一次，如果之前未恢复则执行恢复与连接取消
    /// - Parameters:
    ///   - cont: CheckedContinuation
    ///   - result: 返回结果
    ///   - conn: 当前 NWConnection，用于取消释放资源
    func tryResume(_ cont: CheckedContinuation<Bool, Never>, result: Bool, conn: NWConnection) {
        if !resumed {
            resumed = true
            cont.resume(returning: result)
            conn.cancel()
        }
    }
}

/// 网络连通性检查工具
/// 提供域名解析（通过 TCP 建连）与 IP 直连测试，带超时保护。
struct NetworkChecker {

    /// 检查是否能解析指定域名并建立 TCP 连接（作为连通性近似判断）
    /// - Parameters:
    ///   - host: 域名，例如 "www.apple.com"
    ///   - timeout: 超时时间，默认 3 秒
    /// - Returns: true 表示可连通，false 表示失败或超时
    static func canResolve(host: String, timeout: TimeInterval = 3) async -> Bool {
        await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            let params = NWParameters.tcp
            let endpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(host), port: 80)
            let conn = NWConnection(to: endpoint, using: params)

            // 用 actor 保护一次性 resume
            let flag = ResumeFlag()

            // 状态更新在系统线程回调，转到并发任务中安全调用 actor
            conn.stateUpdateHandler = { state in
                Task {
                    switch state {
                    case .ready:
                        await flag.tryResume(cont, result: true, conn: conn)
                    case .failed, .cancelled:
                        await flag.tryResume(cont, result: false, conn: conn)
                    default:
                        break
                    }
                }
            }

            // 启动连接
            conn.start(queue: .global())

            // 超时保护：若在 timeout 时间内没有 ready/failed 回调，返回 false
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
                Task {
                    await flag.tryResume(cont, result: false, conn: conn)
                }
            }
        }
    }

    /// 检查是否能直连指定 IP 地址和端口（TCP）
    /// - Parameters:
    ///   - ip: 公网 IP，例如 "1.1.1.1"
    ///   - port: 端口，默认 80
    ///   - timeout: 超时时间，默认 3 秒
    /// - Returns: true 表示可连通，false 表示失败或超时
    static func canReachIP(_ ip: String, port: UInt16 = 80, timeout: TimeInterval = 3) async -> Bool {
        await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            let params = NWParameters.tcp
            guard let nwPort = NWEndpoint.Port(rawValue: port) else {
                cont.resume(returning: false)
                return
            }
            let endpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(ip), port: nwPort)
            let conn = NWConnection(to: endpoint, using: params)

            let flag = ResumeFlag()

            conn.stateUpdateHandler = { state in
                Task {
                    switch state {
                    case .ready:
                        await flag.tryResume(cont, result: true, conn: conn)
                    case .failed, .cancelled:
                        await flag.tryResume(cont, result: false, conn: conn)
                    default:
                        break
                    }
                }
            }

            conn.start(queue: .global())

            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
                Task {
                    await flag.tryResume(cont, result: false, conn: conn)
                }
            }
        }
    }
}

/// 进程与端口检查
struct ProcessChecker {
    /// 检查指定进程名是否存在（ps aux 字符串匹配）
    static func isProcessRunning(_ name: String) -> Bool {
        let task = Process()
        task.launchPath = "/bin/ps"
        task.arguments = ["aux"]
        let pipe = Pipe()
        task.standardOutput = pipe
        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            return output.contains(name)
        } catch {
            return false
        }
    }
    
    /// 检查端口是否被监听（lsof -i）
    static func isPortListening(_ port: Int) -> Bool {
        let task = Process()
        task.launchPath = "/usr/sbin/lsof"
        task.arguments = ["-i:\(port)"]
        let pipe = Pipe()
        task.standardOutput = pipe
        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            return output.contains("LISTEN")
        } catch {
            return false
        }
    }
    
    /// 哪个进程占用了端口（用于冲突提示）
    static func portOwner(_ port: Int) -> String? {
        let task = Process()
        task.launchPath = "/usr/sbin/lsof"
        task.arguments = ["-i:\(port)"]
        let pipe = Pipe()
        task.standardOutput = pipe
        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            // 简单解析第一行进程名
            if let line = output.components(separatedBy: "\n").dropFirst().first, !line.isEmpty {
                let cols = line.split(separator: " ").filter { !$0.isEmpty }
                if let name = cols.first {
                    return String(name)
                }
            }
            return nil
        } catch {
            return nil
        }
    }
}

/// TCP 连通性检查（远端端口）
struct TCPConnectivity {
    static func canConnect(host: String, port: UInt16, timeout: TimeInterval = 5) async -> Bool {
        await withCheckedContinuation { cont in
            let params = NWParameters.tcp
            let endpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(host), port: NWEndpoint.Port(rawValue: port)!)
            let conn = NWConnection(to: endpoint, using: params)
            let flag = ResumeFlag()
            
            conn.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    Task {
                        await flag.tryResume(cont, result: true, conn: conn)
                    }
                case .failed, .cancelled:
                    Task {
                        await flag.tryResume(cont, result: false, conn: conn)
                    }
                default:
                    break
                }
            }
            conn.start(queue: .global())
            
            // 超时后取消连接
            Task {
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                await flag.tryResume(cont, result: false, conn: conn)
            }
        }
    }
}

/// 配置文件解析检查（JSON 基本合法性）
struct ConfigValidator {
    static func isValidJSON(filePath: String) async -> Bool {
        await Task.detached(priority: .userInitiated) {
            guard let data = try? Data(contentsOf: URL(fileURLWithPath: filePath)) else { return false }
            return (try? JSONSerialization.jsonObject(with: data)) != nil
        }.value
    }

    /// 详细验证配置文件
    /// - Parameter filePath: 配置文件路径
    /// - Returns: (isValid: Bool, problems: [String]) - 是否有效及问题列表
    static func validateConfig(filePath: String) async -> (isValid: Bool, problems: [String]) {
        await Task.detached(priority: .userInitiated) {
            var problems: [String] = []
            
            guard FileManager.default.fileExists(atPath: filePath) else {
                return (false, ["配置文件不存在"])
            }
            
            guard let data = try? Data(contentsOf: URL(fileURLWithPath: filePath)) else {
                return (false, ["配置文件无法读取，可能是权限问题"])
            }
            
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return (false, ["配置文件格式错误，不是有效的 JSON"])
            }
            
            let isSingBox = json["route"] != nil || json["dns"] != nil
            
            if isSingBox {
                let hasInbounds = json["inbounds"] != nil
                let hasOutbounds = json["outbounds"] != nil
                
                if !hasInbounds {
                    problems.append("缺少入站配置（inbounds）")
                }
                if !hasOutbounds {
                    problems.append("缺少出站配置（outbounds）")
                }
                
                if let inbounds = json["inbounds"] as? [[String: Any]], !inbounds.isEmpty {
                    var foundSocks = false
                    var foundHttp = false
                    var foundTun = false
                    for inbound in inbounds {
                        if let type = inbound["type"] as? String {
                            if type == "socks" {
                                foundSocks = true
                            } else if type == "http" {
                                foundHttp = true
                            } else if type == "tun" {
                                foundTun = true
                            }
                        }
                    }
                    if !foundSocks && !foundHttp && !foundTun {
                    }
                }
            } else {
                let hasInbounds = json["inbounds"] != nil
                let hasOutbounds = json["outbounds"] != nil
                
                if !hasInbounds {
                    problems.append("缺少入站配置（inbounds）")
                }
                if !hasOutbounds {
                    problems.append("缺少出站配置（outbounds）")
                }
                
                if let inbounds = json["inbounds"] as? [[String: Any]], !inbounds.isEmpty {
                    var foundSocks = false
                    var foundHttp = false
                    for inbound in inbounds {
                        if let protocol_ = inbound["protocol"] as? String {
                            if protocol_ == "socks" {
                                foundSocks = true
                            } else if protocol_ == "http" {
                                foundHttp = true
                            }
                        }
                    }
                    if !foundSocks && !foundHttp {
                        problems.append("未配置 SOCKS 或 HTTP 入站代理")
                    }
                }
            }
            
            return (problems.isEmpty, problems)
        }.value
    }
}

/// 日志分析：映射关键错误到用户提示
struct LogAnalyzer {
    struct LogEntry {
        let level: String
        let content: String
        let lineNumber: Int
    }
    
    static func analyze(logPath: String, lastLines: Int = 500) async -> [String] {
        return await Task.detached(priority: .userInitiated) {
            guard let content = try? String(contentsOfFile: logPath, encoding: .utf8) else { return [] }
            let lines = content.components(separatedBy: .newlines)
            let recentLines = Array(lines.suffix(lastLines))
            
            var problems: [String] = []
            var addedMessages: Set<String> = []
            
            for (index, line) in recentLines.enumerated() {
                let lowerLine = line.lowercased()
                var msg: String? = nil
                
                if lowerLine.contains("failed to dial") || lowerLine.contains("connect: cannot assign requested address") {
                    msg = "【连接失败】无法连接到远程服务器。可能原因：节点服务器不可用、被墙、或网络被限制。请尝试更换节点"
                } else if lowerLine.contains("tls handshake error") || (lowerLine.contains("tls:") && lowerLine.contains("error")) {
                    msg = "【TLS 错误】TLS 握手失败。可能原因：\n1. 服务器 TLS 配置问题\n2. SNI 不匹配\n3. 证书过期\n\n请尝试更换节点或联系服务商"
                } else if lowerLine.contains("connection reset by peer") || lowerLine.contains("connection closed") {
                    msg = "【连接被拒】服务器主动断开连接。可能原因：\n1. 账号已过期或被封\n2. 端口号错误\n3. 连接次数超限\n\n请检查节点配置或更换节点"
                } else if lowerLine.contains("invalid user") || lowerLine.contains("user not found") || lowerLine.contains("authentication error") {
                    msg = "【认证失败】用户名或密码（UUID）错误。请检查：\n1. UUID 是否正确\n2. 密码是否正确\n3. 账号是否已过期"
                } else if lowerLine.contains("remote_addr not found") || (lowerLine.contains("dial tcp") && lowerLine.contains("no such host")) {
                    msg = "【域名解析失败】无法解析节点域名。可能是：\n1. DNS 服务器无法解析\n2. 节点域名已失效\n\n请尝试更换网络或更换节点"
                } else if lowerLine.contains("i/o timeout") || lowerLine.contains("timeout") || lowerLine.contains("deadline exceeded") {
                    msg = "【连接超时】连接响应超时。可能原因：\n1. 网络延迟太高\n2. 节点负载过高\n3. 网络不稳定\n\n请尝试更换节点或等待网络恢复"
                } else if lowerLine.contains("quic") && (lowerLine.contains("error") || lowerLine.contains("failed")) {
                    msg = "【QUIC 错误】QUIC 协议连接失败。可能原因：\n1. 服务器不支持 QUIC\n2. UDP 被阻断\n\n请尝试更换节点或切换到 TCP 协议"
                } else if lowerLine.contains("websocket") && (lowerLine.contains("error") || lowerLine.contains("failed")) {
                    msg = "【WebSocket 错误】WebSocket 连接失败。请检查节点配置或更换节点"
                } else if lowerLine.contains("permission denied") || lowerLine.contains("access denied") {
                    msg = "【权限不足】程序权限被拒绝。请以管理员权限运行 V2rayU"
                } else if lowerLine.contains("port") && lowerLine.contains("in use") {
                    msg = "【端口占用】代理端口被其他程序占用。请关闭占用端口的程序或更换端口"
                }
                
                if let m = msg, !addedMessages.contains(m) {
                    addedMessages.insert(m)
                    problems.append(m)
                }
            }
            
            if problems.isEmpty {
                problems.append("未发现明显错误")
            }
            
            return problems
        }.value
    }
    
    static func getSurroundingLog(logPath: String, lastLines: Int = 500, contextLines: Int = 3) async -> String {
        await Task.detached(priority: .userInitiated) {
            guard let content = try? String(contentsOfFile: logPath, encoding: .utf8) else { return "" }
            let lines = content.components(separatedBy: .newlines)
            let recentLines = Array(lines.suffix(lastLines))
            
            var relevantLogs: [String] = []
            
            for (index, line) in recentLines.enumerated() {
                let lowerLine = line.lowercased()
                
                let hasError = lowerLine.contains("[error]") || lowerLine.contains("[warning]") || lowerLine.contains("[info]")
                let isErrorPattern = lowerLine.contains("failed") || lowerLine.contains("error") || 
                                    lowerLine.contains("timeout") || lowerLine.contains("reset") || 
                                    lowerLine.contains("denied") || lowerLine.contains("reject")
                
                if hasError || isErrorPattern {
                    let start = max(0, index - contextLines)
                    let end = min(recentLines.count, index + contextLines + 1)
                    
                    for i in start..<end {
                        let prefix = i == index ? ">>> " : "    "
                        relevantLogs.append("\(prefix)\(recentLines[i])")
                    }
                    relevantLogs.append("")
                }
            }
            
            return relevantLogs.isEmpty ? "无 INFO 及以上级别日志" : relevantLogs.joined(separator: "\n")
        }.value
    }
}
