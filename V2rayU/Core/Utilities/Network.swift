//
//  Network.swift
//  V2rayU
//
//  Created by yanue on 2025/11/8.
//

import Foundation
import Network
import Foundation
import Network
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
            conn.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    conn.cancel()
                    cont.resume(returning: true)
                case .failed, .cancelled:
                    cont.resume(returning: false)
                default:
                    break
                }
            }
            conn.start(queue: .global())
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
                conn.cancel()
                cont.resume(returning: false)
            }
        }
    }
}

/// 配置文件解析检查（JSON 基本合法性）
struct ConfigValidator {
    static func isValidJSON(filePath: String) -> Bool {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: filePath)) else { return false }
        return (try? JSONSerialization.jsonObject(with: data)) != nil
    }
}

/// 日志分析：映射关键错误到用户提示
struct LogAnalyzer {
    static func analyze(logPath: String, lastLines: Int = 300) -> [String] {
        guard let content = try? String(contentsOfFile: logPath, encoding: .utf8) else { return [] }
        let lines = content.components(separatedBy: .newlines)
        let recent = lines.suffix(lastLines).joined(separator: "\n")
        var problems: [String] = []
        
        if recent.contains("failed to dial") {
            problems.append("无法连接远程服务器，可能是网络不可达或被防火墙阻断")
        }
        if recent.contains("tls handshake error") {
            problems.append("TLS 握手失败，可能是证书问题或 SNI 配置错误")
        }
        if recent.contains("connection reset by peer") {
            problems.append("服务器主动断开连接，请检查账号或端口是否正确")
        }
        if recent.contains("invalid user") || recent.contains("user not found") {
            problems.append("用户凭据错误（UUID/账号），请检查配置")
        }
        if recent.contains("remote_addr not found") || recent.contains("dial tcp") && recent.contains("no such host") {
            problems.append("域名解析失败，DNS 可能异常或节点域名错误")
        }
        if recent.contains("i/o timeout") || recent.contains("timeout") {
            problems.append("连接超时，网络质量差或服务器不可达")
        }
        return problems
    }
}
