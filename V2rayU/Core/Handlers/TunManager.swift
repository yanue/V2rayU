//
//  TunManager.swift
//  V2rayU
//
//  Created by yanue on 2026/1/29.
//

import Foundation

/// TUN 路由管理器 - 增强版
/// 支持异常恢复、状态检测、自动清理
class TunManager {
    
    // MARK: - 配置参数
    struct Config {
        let serverIP: String
        let tunInterface: String
        let tunLocalIP: String
        let tunRemoteIP: String
        let dnsServers: [String]
        let networkInterface: String
        
        init(serverIP: String,
             tunInterface: String = "utun8",
             tunLocalIP: String = "10.0.0.1",
             tunRemoteIP: String = "10.0.0.2",
             dnsServers: [String] = ["1.1.1.1", "8.8.8.8", "223.5.5.5"],
             networkInterface: String = "Wi-Fi") {
            self.serverIP = serverIP
            self.tunInterface = tunInterface
            self.tunLocalIP = tunLocalIP
            self.tunRemoteIP = tunRemoteIP
            self.dnsServers = dnsServers
            self.networkInterface = networkInterface
        }
    }
    
    // MARK: - 状态管理
    
    /// TUN 状态
    struct TunStatus {
        let isActive: Bool              // TUN 接口是否激活
        let hasRoutes: Bool             // 是否有 TUN 路由
        let serverIP: String?           // 当前配置的服务器 IP
        let tunInterface: String?       // TUN 接口名
        
        var isConfigured: Bool {
            return isActive && hasRoutes
        }
    }
    
    /// 获取当前 TUN 状态
    static func getCurrentStatus() -> TunStatus {
        var isActive = false
        var hasRoutes = false
        var serverIP: String? = nil
        var tunInterface: String? = nil
        
        // 检查 TUN 接口是否存在
        do {
            let output = try runCommand(at: "/sbin/ifconfig", with: ["-a"])
            let interfaces = output.components(separatedBy: "\n")
            
            for line in interfaces {
                if line.hasPrefix("utun") && line.contains("10.0.0.1") {
                    isActive = true
                    if let match = line.components(separatedBy: ":").first {
                        tunInterface = match
                    }
                    break
                }
            }
        } catch {
            // 忽略错误
        }
        
        // 检查路由表
        do {
            let output = try runCommand(at: "/usr/sbin/netstat", with: ["-rn"])
            let lines = output.components(separatedBy: "\n")
            
            for line in lines {
                if line.contains("utun") && (line.contains("0.0.0.0/1") || line.contains("128.0.0.0/1")) {
                    hasRoutes = true
                    break
                }
            }
        } catch {
            // 忽略错误
        }
        
        // 尝试读取状态文件
        serverIP = readStateFile()?.serverIP
        
        return TunStatus(
            isActive: isActive,
            hasRoutes: hasRoutes,
            serverIP: serverIP,
            tunInterface: tunInterface ?? "utun12"
        )
    }
    
    // MARK: - 状态持久化
    
    private struct StateInfo: Codable {
        let serverIP: String
        let tunInterface: String
        let timestamp: Date
        let pid: Int32
    }
    
    private static let stateFilePath = "/tmp/tun-manager-state.json"
    
    private static func saveStateFile(serverIP: String, tunInterface: String) {
        let state = StateInfo(
            serverIP: serverIP,
            tunInterface: tunInterface,
            timestamp: Date(),
            pid: getpid()
        )
        
        if let data = try? JSONEncoder().encode(state) {
            try? data.write(to: URL(fileURLWithPath: stateFilePath))
        }
    }
    
    private static func readStateFile() -> StateInfo? {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: stateFilePath)) else {
            return nil
        }
        return try? JSONDecoder().decode(StateInfo.self, from: data)
    }
    
    private static func removeStateFile() {
        try? FileManager.default.removeItem(atPath: stateFilePath)
    }
    
    // MARK: - 错误定义
    enum TunError: Error, LocalizedError {
        case scriptExecutionFailed(String)
        case scriptCreationFailed
        case sudoNotConfigured
        case permissionDenied
        case alreadyConfigured(String)
        
        var errorDescription: String? {
            switch self {
            case .scriptExecutionFailed(let msg):
                return "脚本执行失败: \(msg)"
            case .scriptCreationFailed:
                return "脚本创建失败"
            case .sudoNotConfigured:
                return "sudo 未配置，请先运行安装程序"
            case .permissionDenied:
                return "权限不足"
            case .alreadyConfigured(let serverIP):
                return "TUN 已配置（服务器: \(serverIP)），请先执行清理"
            }
        }
    }
    
    // MARK: - 主要方法
    
    /// 设置 TUN 路由（带状态检查）
    static func setupTunRouting(config: Config, force: Bool = false) throws {
        // 检查当前状态
        let status = getCurrentStatus()
        
        if status.isConfigured && !force {
            if let existingServer = status.serverIP {
                throw TunError.alreadyConfigured(existingServer)
            } else {
                // 有残留配置，先清理
                print("⚠️ 检测到残留配置，正在清理...")
                try forceCleanup()
            }
        }
        
        let commands = [
            "-n",
            "/Library/PrivilegedHelperTools/yanue.v2rayu.tun-helper.sh",
            "setup",
            config.serverIP,
            config.tunInterface,
            config.tunLocalIP,
            config.tunRemoteIP,
            config.dnsServers[0],
            config.dnsServers[1],
            config.dnsServers[2],
            config.networkInterface
        ]
        
        let _ = try runCommand(at: "/usr/bin/sudo", with: commands)

        // 保存状态
        saveStateFile(serverIP: config.serverIP, tunInterface: config.tunInterface)
    }
    
    /// 清理 TUN 路由配置
    static func teardownTunRouting(config: Config) throws {
        let commands = [
            "-n",
            "/Library/PrivilegedHelperTools/yanue.v2rayu.tun-helper.sh",
            "teardown",
            config.serverIP,
            config.tunInterface,
            config.dnsServers[0],
            config.dnsServers[1],
            config.dnsServers[2],
            config.networkInterface
        ]
        let _ = try runCommand(at: "/usr/bin/sudo", with: commands)
        // 清理状态文件
        removeStateFile()
    }
    
    /// 强制清理（不管当前配置是什么）
    static func forceCleanup() throws {
        let status = getCurrentStatus()
        
        // 使用当前检测到的配置或默认配置
        let serverIP = status.serverIP ?? "0.0.0.0"
        let tunInterface = status.tunInterface ?? "utun8"
        
        let config = Config(serverIP: serverIP)
        try teardownTunRouting(config: config)
        
        print("✅ 强制清理完成")
    }
    
    /// 智能清理（根据状态文件）
    static func cleanupIfNeeded() throws {
        guard let state = readStateFile() else {
            // 没有状态文件，检查是否有残留
            let status = getCurrentStatus()
            if status.isConfigured {
                print("⚠️ 检测到未记录的 TUN 配置，正在清理...")
                try forceCleanup()
            }
            return
        }
        
        // 有状态文件，使用记录的配置清理
        let config = Config(serverIP: state.serverIP, tunInterface: state.tunInterface)
        try teardownTunRouting(config: config)
    }
}

// MARK: - 便捷方法
extension TunManager {
    
    static func smartSetup(server: String) throws {
        let serverIPs = try DNSResolver.resolveIPv4(hostname: server)
        logger.info("TunManager smartSetup resolved IPs: \(serverIPs)")
        for serverIP in serverIPs {
            try smartSetup(serverIP: serverIP)
        }
    }
    
    /// 智能设置（自动处理异常情况）
    static func smartSetup(serverIP: String) throws {
        // 检查并清理残留s
        let status = getCurrentStatus()
        if status.isConfigured {
            if let existingServer = status.serverIP, existingServer == serverIP {
                print("⚠️ VPN 已连接到此服务器，无需重复设置")
                return
            } else {
                print("⚠️ 检测到旧配置，正在清理...")
                try cleanupIfNeeded()
            }
        }
        
        let config = Config(serverIP: serverIP)
        try setupTunRouting(config: config)
    }
    
    /// 智能清理（自动检测配置）
    static func smartTeardown() throws {
        try cleanupIfNeeded()
    }
    
    /// 快速设置（保持向后兼容）
    static func quickSetup(serverIP: String) throws {
        try smartSetup(serverIP: serverIP)
    }
    
    /// 快速清理（保持向后兼容）
    static func quickTeardown(serverIP: String) throws {
        let config = Config(serverIP: serverIP)
        try teardownTunRouting(config: config)
    }
}
