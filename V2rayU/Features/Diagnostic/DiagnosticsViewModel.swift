//
//  DiagnosticsViewModel.swift
//  V2rayU
//
//  Created by yanue on 2025/11/8.
//

import SwiftUI

@MainActor

final class DiagnosticsViewModel: ObservableObject {
    @Published var items: [DiagnosticItem] = []
    @Published var checking: Bool = false
    @Published var showOpenSettingsAlert: Bool = false
    @Published var showFAQ: Bool = false
    @Published var progressText: String = ""  // 当前执行步骤提示（小白友好）
    
    // 依赖（根据你的项目实际路径/服务替换）
    private let appState = AppState.shared
    private let v2rayUToolPath = v2rayUTool              // 工具路径
    private let logPath = coreLogFilePath               // 日志路径
    private let localSocksPort = 1080                    // 本地代理端口（示例）
    private let localHTTPPort = 1081                     // 本地 HTTP 端口（示例）
    private let nodeHostProvider: () -> String?          // 获取当前节点主机
    private let nodePortProvider: () -> UInt16?          // 获取当前节点端口
    
    init(nodeHostProvider: @escaping () -> String?, nodePortProvider: @escaping () -> UInt16?) {
        self.nodeHostProvider = nodeHostProvider
        self.nodePortProvider = nodePortProvider
        
        // 进入页面：预先填充所有检查项为“等待检查…”，避免空白
        self.items = DiagnosticStep.allCases.map { makePendingItem(for: $0) }
    }
    
    /// 开始逐项诊断（按步骤顺序）
    func runSequentialChecks() {
        Task {
            // 重置：回到 pending 状态并开始检查
            withAnimation {
                self.checking = true
                self.progressText = "准备开始诊断…"
                self.items = DiagnosticStep.allCases.map { makePendingItem(for: $0) }
            }
            
            // 逐项检查（保持你原来的完整步骤顺序）
            await step(.networkConnectivity) { await checkNetworkConnectivity() }
            await step(.systemProxy)        { await checkSystemProxy() }
            await step(.firewall)           { await checkFirewall() }
            await step(.coreInstall)        { await checkCoreInstall() }
            await step(.coreRunning)        { await checkCoreRunning() }
            await step(.uToolPermission)    { await checkUToolPermission() }
            await step(.dnsResolution)      { await checkDNSResolution() }
            await step(.portConnectivity)   { await checkPortConnectivity() }
            await step(.localPortConflict)  { await checkLocalPortConflict() }
            await step(.geoipFile)          { await checkGeoipFile() }
            await step(.pingLatency)        { await checkPingLatency() }
            await step(.logAnalysis)        { await checkLogAnalysis() }
            await step(.configValidity)     { await checkConfigValidity() }
            
            withAnimation {
                self.progressText = "诊断完成"
                self.checking = false
            }
        }
    }
    
    /// 步骤执行包装：更新进度文案，标记“正在检查…”，并用结果替换对应项
    private func step(_ step: DiagnosticStep, action: () async -> DiagnosticItem) async {
        // 标记当前项为“正在检查…”
        if let idx = items.firstIndex(where: { $0.step == step }) {
            withAnimation {
                self.progressText = "正在检查：\(title(for: step))"
                // 由于 DiagnosticItem 多数字段是 let，不可变，这里用“替换”方式更新
                self.items[idx] = DiagnosticItem(
                    step: step,
                    title: items[idx].title,
                    subtitle: "正在检查…",
                    status: .checking,
                    ok: false,
                    problem: nil,
                    actionTitle: nil,
                    action: nil
                )
            }
        }
        
        // 执行实际检查（返回完整的 DiagnosticItem，包含状态/文案/动作）
        let result = await action()
        
        // 用检查结果替换对应项
        if let idx = items.firstIndex(where: { $0.step == step }) {
            withAnimation {
                self.items[idx] = result
            }
        }
        
        // 可选：给用户一点视觉缓冲
        try? await Task.sleep(nanoseconds: 300_000_000)
    }
    
    // MARK: - Helpers
    
    /// 为某步骤生成“等待检查…”的占位项
    private func makePendingItem(for step: DiagnosticStep) -> DiagnosticItem {
        DiagnosticItem(
            step: step,
            title: title(for: step),
            subtitle: "等待检查…",
            status: .pending,
            ok: false,
            problem: nil,
            actionTitle: nil,
            action: nil
        )
    }
    
    /// 标题映射
   private func title(for step: DiagnosticStep) -> String {
       switch step {
       case .networkConnectivity: return String(localized: .DiagNetworkConnectivity)
       case .systemProxy:        return String(localized: .DiagSystemProxy)
       case .firewall:           return String(localized: .DiagFirewall)
       case .coreInstall:        return String(localized: .DiagCoreInstall)
       case .coreRunning:        return String(localized: .DiagCoreRunning)
       case .uToolPermission:    return String(localized: .DiagUToolPermission)
       case .dnsResolution:      return String(localized: .DiagDNSResolution)
       case .portConnectivity:   return String(localized: .DiagPortConnectivity)
       case .localPortConflict:  return String(localized: .DiagLocalPortConflict)
       case .geoipFile:          return String(localized: .DiagGeoipFile)
       case .pingLatency:        return String(localized: .DiagPingLatency)
       case .logAnalysis:        return String(localized: .DiagLogAnalysis)
       case .configValidity:     return String(localized: .DiagConfigValidity)
       }
   }
    // MARK: - 各项检查（返回 DiagnosticItem）
    
    private func checkNetworkConnectivity() async -> DiagnosticItem {
        let appleDNS = await NetworkChecker.canResolve(host: "www.apple.com")
        let googleDNS = await NetworkChecker.canResolve(host: "www.google.com")
        let dnsOK = appleDNS || googleDNS
        let cloudflareIP = await NetworkChecker.canReachIP("1.1.1.1")
        let googleIP = await NetworkChecker.canReachIP("8.8.8.8")
        let ipOK = cloudflareIP || googleIP
        let ok = dnsOK && ipOK
        
        let subtitle: String
        let problem: String?
        
        if ok {
            subtitle = String(localized: .DiagPassed)
            problem = nil
        } else if !dnsOK && !ipOK {
            subtitle = String(localized: .DiagNetUnavailable)
            problem = String(localized: .DiagNetUnavailable)
        } else if !dnsOK {
            subtitle = String(localized: .DiagNetDNSFailed)
            problem = String(localized: .DiagNetDNSFailed)
        } else {
            subtitle = String(localized: .DiagNetIPFailed)
            problem = String(localized: .DiagNetIPFailed)
        }
        
        return DiagnosticItem(
            step: .networkConnectivity,
            title: String(localized: .DiagNetworkConnectivity),
            subtitle: subtitle,
            ok: ok,
            problem: problem,
            actionTitle: ok ? nil : String(localized: .DiagOpenNetworkSettings),
            action: ok ? nil : { self.openSystemNetworkSettings() }
        )
    }
    
    private func checkSystemProxy() async -> DiagnosticItem {
        let currentMode = appState.runMode
        let actualSocksPort = AppSettings.shared.socksPort
        let actualHttpPort = AppSettings.shared.httpPort
        
        let subtitle: String
        let problem: String?
        let ok: Bool
        
        switch currentMode {
        case .tunnel:
            subtitle = String(localized: .DiagProxyNotNeededTunnel)
            problem = nil
            ok = true
            
        case .manual:
            subtitle = String(localized: .DiagProxyNotNeededManual)
            problem = nil
            ok = true
            
        case .off:
            subtitle = String(localized: .DiagProxyNotNeededOff)
            problem = nil
            ok = true
            
        case .pac, .global:
            let (enabled, port) = getSystemProxyStatus()
            let correctPort = port == actualSocksPort || port == actualHttpPort
            ok = enabled && correctPort
            
            if enabled && correctPort {
                subtitle = String(format: String(localized: .DiagPassed), port)
                problem = nil
            } else if enabled && !correctPort {
                subtitle = String(format: String(localized: .DiagProxyPortMismatch), port, actualSocksPort)
                problem = String(format: String(localized: .DiagProxyPortWrong), actualSocksPort, actualHttpPort)
            } else {
                subtitle = String(localized: .DiagProxyRequired)
                problem = String(localized: .DiagProxyNotEnabled)
            }
        }
        
        return DiagnosticItem(
            step: .systemProxy,
            title: String(localized: .DiagSystemProxy),
            subtitle: subtitle,
            ok: ok,
            problem: problem,
            actionTitle: (currentMode == .pac || currentMode == .global) ? String(localized: .DiagOpenNetworkSettings) : nil,
            action: (currentMode == .pac || currentMode == .global) ? { self.openSystemNetworkSettings() } : nil
        )
    }
    
    private func checkFirewall() async -> DiagnosticItem {
        let coreRunning = ProcessChecker.isProcessRunning("v2ray") || ProcessChecker.isProcessRunning("xray")
        let socksListening = ProcessChecker.isPortListening(localSocksPort)
        let httpListening = ProcessChecker.isPortListening(localHTTPPort)
        
        let ok: Bool
        let subtitle: String
        let problem: String?
        
        if !coreRunning {
            ok = true
            subtitle = String(localized: .DiagCoreNotRunning)
            problem = nil
        } else if socksListening || httpListening {
            ok = true
            subtitle = String(localized: .DiagPassed)
            problem = nil
        } else {
            ok = false
            subtitle = String(localized: .DiagFailed)
            problem = String(localized: .DiagFirewallBlocked)
        }
        
        return DiagnosticItem(
            step: .firewall,
            title: String(localized: .DiagFirewall),
            subtitle: subtitle,
            ok: ok,
            problem: problem,
            actionTitle: nil,
            action: nil
        )
    }
    
    private func checkCoreInstall() async -> DiagnosticItem {
        let installed = FileManager.default.fileExists(atPath: xrayCoreFile)
        let executable = installed && FileManager.default.isExecutableFile(atPath: xrayCoreFile)
        let version = executable ? getCoreVersion() : ""
        
        let subtitle: String
        let problem: String?
        
        if executable {
            subtitle = String(format: String(localized: .DiagPassed), version)
            problem = nil
        } else if installed {
            subtitle = String(localized: .DiagCoreNotExecutable)
            problem = String(localized: .DiagCoreNotExecutable)
        } else {
            subtitle = String(localized: .DiagCoreNotInstalled)
            problem = String(localized: .DiagCoreNotInstalled)
        }
        
        return DiagnosticItem(
            step: .coreInstall,
            title: String(localized: .DiagCoreInstall),
            subtitle: subtitle,
            ok: executable,
            problem: problem,
            actionTitle: executable ? nil : String(localized: .DiagFixNow),
            action: executable ? nil : { self.fixInstallAll() }
        )
    }
    
    private func checkCoreRunning() async -> DiagnosticItem {
        let running = ProcessChecker.isProcessRunning("v2ray") || ProcessChecker.isProcessRunning("xray")
        
        let subtitle: String
        let problem: String?
        
        if running {
            subtitle = String(localized: .DiagPassed)
            problem = nil
        } else if !appState.v2rayTurnOn {
            subtitle = String(localized: .DiagCoreStopped)
            problem = String(localized: .DiagCoreStopped)
        } else {
            subtitle = String(localized: .DiagCoreStartFailed)
            problem = String(localized: .DiagCoreStartFailed)
        }
        
        return DiagnosticItem(
            step: .coreRunning,
            title: String(localized: .DiagCoreRunning),
            subtitle: subtitle,
            ok: running,
            problem: problem,
            actionTitle: running ? String(localized: .DiagRestartCore) : String(localized: .DiagStartCore),
            action: running ? { self.restartCore() } : { self.toggleCoreOnOff() }
        )
    }
    
    private func checkVPNConflict() async -> DiagnosticItem {
        let vpnProcesses = [
            "clash_for_windows",
            "clashx",
            "clash",
            "v2rayng",
            "v2ray",
            "shadowsocks",
            "ss-local",
            "trojan",
            "qv2ray",
            "nekobox",
            "sing-box",
            "Outline",
            "tunnelblick",
            "private-internet-access",
            "expressvpn",
            "nordvpn",
            "surfshark"
        ]
        
        var runningVPNs: [String] = []
        for vpn in vpnProcesses {
            if ProcessChecker.isProcessRunning(vpn) {
                runningVPNs.append(vpn)
            }
        }
        
        let ok = runningVPNs.isEmpty
        let subtitle: String
        let problem: String?
        
        if ok {
            subtitle = String(localized: .DiagPassed)
            problem = nil
        } else {
            subtitle = String(localized: .DiagFailed)
            problem = String(localized: .DiagFailed)
        }
        
        return DiagnosticItem(
            step: .uToolPermission,
            title: String(localized: .DiagVPNConflict),
            subtitle: subtitle,
            ok: ok,
            problem: problem,
            actionTitle: ok ? nil : nil,
            action: ok ? nil : nil
        )
    }
    
    private func showRunningProcesses() {
        let task = Process()
        task.launchPath = "/bin/ps"
        task.arguments = ["aux"]
        task.standardOutput = Pipe()
        try? task.run()
    }
    
    private func checkUToolPermission() async -> DiagnosticItem {
        let toolExists = FileManager.default.fileExists(atPath: v2rayUToolPath)
        let hasPermission = toolExists && checkFileIsRootAdmin(file: v2rayUToolPath)
        
        let subtitle: String
        let problem: String?
        
        if hasPermission {
            subtitle = String(localized: .DiagPassed)
            problem = nil
        } else if !toolExists {
            subtitle = String(localized: .DiagToolMissing)
            problem = String(localized: .DiagToolMissing)
        } else {
            subtitle = String(localized: .DiagToolNoPermission)
            problem = String(localized: .DiagToolNoPermission)
        }
        
        return DiagnosticItem(
            step: .uToolPermission,
            title: String(localized: .DiagUToolPermission),
            subtitle: subtitle,
            ok: hasPermission,
            problem: problem,
            actionTitle: hasPermission ? nil : String(localized: .DiagFixNow),
            action: hasPermission ? nil : { self.fixV2rayUTool() }
        )
    }

    private func checkDNSResolution() async -> DiagnosticItem {
        guard let host = nodeHostProvider() else {
            return DiagnosticItem(
                step: .dnsResolution,
                title: String(localized: .DiagDNSResolution),
                subtitle: String(localized: .DiagNodeNotSelected),
                ok: false,
                problem: String(localized: .DiagNodeNotSelected),
                actionTitle: nil,
                action: nil
            )
        }
        let ok = await NetworkChecker.canResolve(host: host)
        
        let subtitle: String
        let problem: String?
        
        if ok {
            subtitle = String(format: String(localized: .DiagPassed), host)
            problem = nil
        } else {
            subtitle = String(format: String(localized: .DiagDNSResolveFailed), host)
            problem = String(format: String(localized: .DiagDNSResolveFailed), host)
        }
        
        return DiagnosticItem(
            step: .dnsResolution,
            title: String(localized: .DiagDNSResolution),
            subtitle: subtitle,
            ok: ok,
            problem: problem,
            actionTitle: ok ? nil : String(localized: .DiagCheckNetwork),
            action: ok ? nil : { self.openSystemNetworkSettings() }
        )
    }
    
    private func checkPortConnectivity() async -> DiagnosticItem {
        guard let host = nodeHostProvider(), let port = nodePortProvider() else {
            return DiagnosticItem(
                step: .portConnectivity,
                title: String(localized: .DiagPortConnectivity),
                subtitle: String(localized: .DiagNodeNotSelected),
                ok: false,
                problem: String(localized: .DiagNodeNotSelected),
                actionTitle: nil,
                action: nil
            )
        }
        let ok = await TCPConnectivity.canConnect(host: host, port: port)
        
        let subtitle: String
        let problem: String?
        
        if ok {
            subtitle = String(format: String(localized: .DiagPassed), port)
            problem = nil
        } else {
            subtitle = String(format: String(localized: .DiagPortConnectFailed), host, port)
            problem = String(format: String(localized: .DiagPortConnectFailed), host, port)
        }
        
        return DiagnosticItem(
            step: .portConnectivity,
            title: String(localized: .DiagPortConnectivity),
            subtitle: subtitle,
            ok: ok,
            problem: problem,
            actionTitle: nil,
            action: nil
        )
    }
    
    private func checkLocalPortConflict() async -> DiagnosticItem {
        let socksListening = ProcessChecker.isPortListening(localSocksPort)
        let httpListening = ProcessChecker.isPortListening(localHTTPPort)
        let coreRunning = ProcessChecker.isProcessRunning("v2ray") || ProcessChecker.isProcessRunning("xray")
        
        let conflictSocks = socksListening && !coreRunning
        let conflictHTTP = httpListening && !coreRunning
        let ok = !(conflictSocks || conflictHTTP)
        
        let ownerSocks = ProcessChecker.portOwner(localSocksPort) ?? "未知"
        let ownerHTTP = ProcessChecker.portOwner(localHTTPPort) ?? "未知"
        
        let subtitle: String
        let problem: String?
        
        if !socksListening && !httpListening {
            subtitle = String(localized: .DiagPassed)
            problem = nil
        } else if coreRunning {
            subtitle = String(localized: .DiagPassed)
            problem = nil
        } else if conflictSocks || conflictHTTP {
            subtitle = String(localized: .DiagPortOccupied)
            if conflictSocks && conflictHTTP {
                problem = String(format: String(localized: .DiagPortOccupied), localSocksPort, ownerSocks)
            } else if conflictSocks {
                problem = String(format: String(localized: .DiagPortOccupied), localSocksPort, ownerSocks)
            } else {
                problem = String(format: String(localized: .DiagPortOccupied), localHTTPPort, ownerHTTP)
            }
        } else {
            subtitle = String(localized: .DiagPassed)
            problem = nil
        }
        
        return DiagnosticItem(
            step: .localPortConflict,
            title: String(localized: .DiagLocalPortConflict),
            subtitle: subtitle,
            ok: ok,
            problem: problem,
            actionTitle: ok ? nil : String(localized: .DiagFixNow),
            action: ok ? nil : { self.restartCore() }
        )
    }
    
    private func checkGeoipFile() async -> DiagnosticItem {
        let exists = FileManager.default.fileExists(atPath: xrayCorePath + "/geoip.dat")
        
        let subtitle: String
        let problem: String?
        
        if exists {
            subtitle = String(localized: .DiagPassed)
            problem = nil
        } else {
            subtitle = String(localized: .DiagGeoipMissing)
            problem = String(localized: .DiagGeoipMissing)
        }
        
        return DiagnosticItem(
            step: .geoipFile,
            title: String(localized: .DiagGeoipFile),
            subtitle: subtitle,
            ok: exists,
            problem: problem,
            actionTitle: exists ? nil : String(localized: .DiagFixNow),
            action: exists ? nil : { self.fixGeoip() }
        )
    }
    
    private func checkPingLatency() async -> DiagnosticItem {
        await PingAll.shared.run()
        let latency = appState.latency
        
        let subtitle: String
        let problem: String?
        let ok: Bool
        
        if latency > 0 && latency < 100 {
            ok = true
            subtitle = String(format: String(localized: .DiagPassed), Int(latency))
            problem = nil
        } else if latency > 0 && latency < 300 {
            ok = true
            subtitle = String(format: String(localized: .DiagPassed), Int(latency))
            problem = nil
        } else if latency > 0 {
            ok = false
            subtitle = String(format: String(localized: .DiagLatencyHigh), Int(latency))
            problem = String(format: String(localized: .DiagLatencyHigh), Int(latency))
        } else {
            ok = false
            subtitle = String(localized: .DiagLatencyFailed)
            problem = String(localized: .DiagLatencyFailed)
        }
        
        return DiagnosticItem(
            step: .pingLatency,
            title: String(localized: .DiagPingLatency),
            subtitle: subtitle,
            ok: ok,
            problem: problem,
            actionTitle: String(localized: .DiagReTest),
            action: { self.doPingNow() }
        )
    }
    
    private func checkLogAnalysis() async -> DiagnosticItem {
        let problems = LogAnalyzer.analyze(logPath: logPath, lastLines: 300)
        let ok = problems.isEmpty
        return DiagnosticItem(
            step: .logAnalysis,
            title: String(localized: .DiagLogAnalysis),
            subtitle: ok ? String(localized: .DiagPassed) : String(localized: .DiagFailed),
            ok: ok,
            problem: ok ? nil : problems.joined(separator: "\n"),
            actionTitle: nil,
            action: nil
        )
    }
    
    private func checkConfigValidity() async -> DiagnosticItem {
        let (isValid, problems) = ConfigValidator.validateConfig(filePath: JsonConfigFilePath)
        
        let subtitle: String
        if !FileManager.default.fileExists(atPath: JsonConfigFilePath) {
            subtitle = "配置文件不存在"
        } else if isValid {
            subtitle = "配置格式正确"
        } else {
            subtitle = "配置存在问题"
        }
        
        return DiagnosticItem(
            step: .configValidity,
            title: "配置合法性",
            subtitle: subtitle,
            ok: isValid,
            problem: isValid ? nil : problems.joined(separator: "；"),
            actionTitle: isValid ? nil : "查看配置",
            action: isValid ? nil : { self.openConfigFile() }
        )
    }
    
    private func openConfigFile() {
        let url = URL(fileURLWithPath: JsonConfigFilePath)
        NSWorkspace.shared.open(url)
    }
    
    // MARK: - 标题辅助
    
    private func titleFor(_ step: DiagnosticStep) -> String {
        switch step {
        case .networkConnectivity: return "网络连接"
        case .systemProxy: return "系统代理设置"
        case .firewall: return "防火墙与安全软件"
        case .coreInstall: return "核心安装与版本"
        case .coreRunning: return "核心运行状态"
        case .uToolPermission: return "工具权限"
        case .configValidity: return "配置合法性"
        case .dnsResolution: return "节点域名解析"
        case .portConnectivity: return "远端端口连通性"
        case .localPortConflict: return "本地端口冲突"
        case .geoipFile: return "GeoIP 文件"
        case .pingLatency: return "延迟与可用性"
        case .logAnalysis: return "日志分析"
        }
    }
    
    // MARK: - 操作项（结合你已有逻辑）
    
    private func openSystemNetworkSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.network") {
            NSWorkspace.shared.open(url)
        } else {
            showOpenSettingsAlert = true
        }
    }

    private func fixInstallAll() {
        Task {
            await AppInstaller.shared.checkInstall()
            await MainActor.run { self.runSequentialChecks() }
        }
    }
    
    private func fixV2rayUTool() {
        Task {
            await AppInstaller.shared.checkInstall()
            await MainActor.run { self.runSequentialChecks() }
        }
    }
    
    private func fixGeoip() {
        Task {
            await AppInstaller.shared.checkInstall()
            await MainActor.run { self.runSequentialChecks() }
        }
    }
    
    private func restartCore() {
        Task {
            await V2rayLaunch.shared.stop()
            try? await Task.sleep(nanoseconds: 300_000_000)
            await AppState.shared.turnOnCore()
            await MainActor.run { self.runSequentialChecks() }
        }
    }
    
    private func toggleCoreOnOff() {
        Task {
            if appState.v2rayTurnOn {
                await AppState.shared.turnOffCore()
            } else {
                await AppState.shared.turnOnCore()
            }
            try? await Task.sleep(nanoseconds: 500_000_000)
            await MainActor.run { self.runSequentialChecks() }
        }
    }
    
    private func doPingNow() {
        Task {
            await PingAll.shared.run()
            try? await Task.sleep(nanoseconds: 300_000_000)
            await MainActor.run { self.runSequentialChecks() }
        }
    }
    
    // MARK: - 系统代理状态（简化版解析：示例）
    private func getSystemProxyStatus() -> (enabled: Bool, port: Int) {
        // 读取当前服务（Wi-Fi/Thunderbolt等），这里直接用 Wi-Fi 作为示例
        let task = Process()
        task.launchPath = "/usr/sbin/networksetup"
        task.arguments = ["-getsocksfirewallproxy", "Wi-Fi"]
        let pipe = Pipe()
        task.standardOutput = pipe
        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            let enabled = output.lowercased().contains("enabled: yes")
            let portLine = output.split(separator: "\n").first { $0.lowercased().contains("port:") }
            let port = portLine.flatMap { Int($0.split(separator: " ").last ?? "0") } ?? 0
            return (enabled, port)
        } catch {
            return (false, 0)
        }
    }
}
