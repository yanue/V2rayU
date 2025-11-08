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
    private let logPath = v2rayLogFilePath               // 日志路径
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
       case .networkConnectivity: return "网络连接"
       case .systemProxy:        return "系统代理设置"
       case .firewall:           return "防火墙与安全软件"
       case .coreInstall:        return "核心安装与版本"
       case .coreRunning:        return "核心运行状态"
       case .uToolPermission:    return "权限与辅助工具"
       case .dnsResolution:      return "DNS 解析"
       case .portConnectivity:   return "端口连通性"
       case .localPortConflict:  return "本地端口冲突"
       case .geoipFile:          return "GeoIP 文件"
       case .pingLatency:        return "延迟与丢包"
       case .logAnalysis:        return "日志分析"
       case .configValidity:     return "配置合法性"
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
        return DiagnosticItem(
            step: .networkConnectivity,
            title: "网络连接",
            subtitle: ok ? "已联网（DNS/公网连通正常）" : "网络不可用或 DNS 异常",
            ok: ok,
            problem: ok ? nil : "请检查路由器/宽带连接、DNS 设置或网络代理是否影响直连",
            actionTitle: ok ? nil : "打开网络设置",
            action: ok ? nil : { self.openSystemNetworkSettings() }
        )
    }
    
    private func checkSystemProxy() async -> DiagnosticItem {
        // 通过 networksetup 检查系统代理是否开启（简化解析）
        let (enabled, port) = getSystemProxyStatus()
        let ok = enabled && (port == localSocksPort || port == localHTTPPort)
        let subtitle = enabled ? "系统代理已开启（端口 \(port)）" : "系统代理未开启"
        return DiagnosticItem(
            step: .systemProxy,
            title: "系统代理设置",
            subtitle: subtitle,
            ok: ok,
            problem: ok ? nil : "系统代理未正确设置或端口不匹配，可能导致应用不走代理",
            actionTitle: "打开设置",
            action: { self.openSystemNetworkSettings() }
        )
    }
    
    private func checkFirewall() async -> DiagnosticItem {
        // 无法直接探测第三方杀软阻断，这里给出提示项
        let coreRunning = ProcessChecker.isProcessRunning("v2ray") || ProcessChecker.isProcessRunning("xray")
        let socksListening = ProcessChecker.isPortListening(localSocksPort)
        let httpListening = ProcessChecker.isPortListening(localHTTPPort)
        let ok = !coreRunning || (socksListening || httpListening)
        return DiagnosticItem(
            step: .firewall,
            title: "防火墙与安全软件",
            subtitle: ok ? "未发现明显阻断迹象" : "可能阻断了进程或端口",
            ok: ok,
            problem: ok ? nil : "安全软件或系统防火墙可能阻止 v2ray 进程或端口，请添加信任或放行规则",
            actionTitle: nil,
            action: nil
        )
    }
    
    private func checkCoreInstall() async -> DiagnosticItem {
        let installed = FileManager.default.fileExists(atPath: v2rayCoreFile) && FileManager.default.isExecutableFile(atPath: v2rayCoreFile)
        let version = installed ? getCoreVersion() : ""
        return DiagnosticItem(
            step: .coreInstall,
            title: "核心安装与版本",
            subtitle: installed ? "版本：\(version)" : "未安装或不可执行",
            ok: installed,
            problem: installed ? nil : "v2ray/xray 核心未安装或权限不足，无法运行",
            actionTitle: installed ? nil : "一键修复",
            action: installed ? nil : { self.fixInstallAll() }
        )
    }
    
    private func checkCoreRunning() async -> DiagnosticItem {
        let running = ProcessChecker.isProcessRunning("v2ray") || ProcessChecker.isProcessRunning("xray")
        return DiagnosticItem(
            step: .coreRunning,
            title: "核心运行状态",
            subtitle: running ? "核心正在运行" : "核心未运行",
            ok: running,
            problem: running ? nil : "核心未运行，无法提供代理服务",
            actionTitle: running ? "重启核心" : "启动核心",
            action: running ? { self.restartCore() } : { self.toggleCoreOnOff() }
        )
    }
    
    private func checkUToolPermission() async -> DiagnosticItem {
        let ok = FileManager.default.fileExists(atPath: v2rayUToolPath) && checkFileIsRootAdmin(file: v2rayUToolPath)
        return DiagnosticItem(
            step: .uToolPermission,
            title: "工具权限",
            subtitle: ok ? "权限正常（管理员）" : "权限不足或缺失",
            ok: ok,
            problem: ok ? nil : "权限不足可能导致安装/修复失败，请提升权限",
            actionTitle: ok ? nil : "修复权限",
            action: ok ? nil : { self.fixV2rayUTool() }
        )
    }

    private func checkDNSResolution() async -> DiagnosticItem {
        guard let host = nodeHostProvider() else {
            return DiagnosticItem(
                step: .dnsResolution,
                title: "节点域名解析",
                subtitle: "未选择节点或缺少域名",
                ok: false,
                problem: "请选择有效节点后再诊断",
                actionTitle: nil,
                action: nil
            )
        }
        let ok = await NetworkChecker.canResolve(host: host)
        return DiagnosticItem(
            step: .dnsResolution,
            title: "节点域名解析",
            subtitle: ok ? "域名可解析：\(host)" : "域名不可解析：\(host)",
            ok: ok,
            problem: ok ? nil : "DNS 无法解析节点域名，可能是 DNS 设置或域名错误",
            actionTitle: "打开网络设置",
            action: { self.openSystemNetworkSettings() }
        )
    }
    
    private func checkPortConnectivity() async -> DiagnosticItem {
        guard let host = nodeHostProvider(), let port = nodePortProvider() else {
            return DiagnosticItem(
                step: .portConnectivity,
                title: "远端端口连通性",
                subtitle: "缺少节点信息",
                ok: false,
                problem: "请选择有效节点后再诊断",
                actionTitle: nil,
                action: nil
            )
        }
        let ok = await TCPConnectivity.canConnect(host: host, port: port)
        return DiagnosticItem(
            step: .portConnectivity,
            title: "远端端口连通性",
            subtitle: ok ? "端口 \(port) 可连接" : "端口 \(port) 不可连接",
            ok: ok,
            problem: ok ? nil : "远端服务器不可达或端口被防火墙阻断，请检查节点端口与服务端状态",
            actionTitle: nil,
            action: nil
        )
    }
    
    private func checkLocalPortConflict() async -> DiagnosticItem {
        let conflictSocks = ProcessChecker.isPortListening(localSocksPort) && !ProcessChecker.isProcessRunning("v2ray") && !ProcessChecker.isProcessRunning("xray")
        let conflictHTTP = ProcessChecker.isPortListening(localHTTPPort) && !ProcessChecker.isProcessRunning("v2ray") && !ProcessChecker.isProcessRunning("xray")
        let ok = !(conflictSocks || conflictHTTP)
        let ownerSocks = ProcessChecker.portOwner(localSocksPort) ?? "未知进程"
        let ownerHTTP = ProcessChecker.portOwner(localHTTPPort) ?? "未知进程"
        let problemText: String? = {
            if conflictSocks { return "本地端口 \(localSocksPort) 已被 \(ownerSocks) 占用" }
            if conflictHTTP { return "本地端口 \(localHTTPPort) 已被 \(ownerHTTP) 占用" }
            return nil
        }()
        return DiagnosticItem(
            step: .localPortConflict,
            title: "本地端口冲突",
            subtitle: ok ? "端口正常可用" : "端口被占用",
            ok: ok,
            problem: problemText,
            actionTitle: ok ? nil : "尝试重启核心",
            action: ok ? nil : { self.restartCore() }
        )
    }
    
    private func checkGeoipFile() async -> DiagnosticItem {
        let exists = FileManager.default.fileExists(atPath: v2rayCorePath + "/geoip.dat")
        return DiagnosticItem(
            step: .geoipFile,
            title: "GeoIP 文件",
            subtitle: exists ? "已安装" : "缺失",
            ok: exists,
            problem: exists ? nil : "规则可能不完整，影响分流与访问",
            actionTitle: exists ? nil : "一键修复",
            action: exists ? nil : { self.fixGeoip() }
        )
    }
    
    private func checkPingLatency() async -> DiagnosticItem {
        await PingAll.shared.run()
        let latency = appState.latency
        let ok = latency > 0
        let subtitle = ok ? String(format: "延迟 %.0f ms", latency) : "无法测得延迟"
        return DiagnosticItem(
            step: .pingLatency,
            title: "延迟与可用性",
            subtitle: subtitle,
            ok: ok,
            problem: ok ? nil : "可能无法连通或被阻断，请切换节点或重试",
            actionTitle: "立即测试",
            action: { self.doPingNow() }
        )
    }
    
    private func checkLogAnalysis() async -> DiagnosticItem {
        let problems = LogAnalyzer.analyze(logPath: logPath, lastLines: 300)
        let ok = problems.isEmpty
        return DiagnosticItem(
            step: .logAnalysis,
            title: "日志分析",
            subtitle: ok ? "未发现异常" : "发现问题（见下）",
            ok: ok,
            problem: ok ? nil : problems.joined(separator: "\n"),
            actionTitle: nil,
            action: nil
        )
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
            AppState.shared.turnOnCore()
            await MainActor.run { self.runSequentialChecks() }
        }
    }
    
    private func toggleCoreOnOff() {
        if appState.v2rayTurnOn {
            AppState.shared.turnOffCore()
        } else {
            AppState.shared.turnOnCore()
        }
        Task {
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
