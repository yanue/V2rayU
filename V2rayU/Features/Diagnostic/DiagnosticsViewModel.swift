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
    @Published var progressText: String = ""
    @Published var showSubmitSheet: Bool = false
    @Published var logContent: String = ""
    
    var hasFailures: Bool {
        items.contains { !$0.ok }
    }
    
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
        
        self.items = DiagnosticStep.allCheckSteps.map { makePendingItem(for: $0) }
    }
    
    func itemsForCategory(_ category: DiagnosticCategory) -> [DiagnosticItem] {
        items.filter { $0.category == category }
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
            
            // 精简检查步骤
            await step(.v2rayUToolInstall)  { await checkV2rayUToolInstall() }
            await step(.uToolPermission)    { await checkUToolPermission() }
            await step(.coreInstall)        { await checkCoreInstall() }
            await step(.coreArch)           { await checkCoreArch() }
            await step(.configFile)         { await checkConfigFile() }
            await step(.geoipFile)          { await checkGeoipFile() }
            await step(.geositeFile)        { await checkGeositeFile() }
            await step(.coreRunning)        { await checkCoreRunning() }
            await step(.nodeConnectivity)   { await checkNodeConnectivity() }
            await step(.localPortConflict)  { await checkLocalPortConflict() }
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
       case .v2rayUToolInstall:  return String(localized: .DiagV2rayUToolInstall)
       case .uToolPermission:    return String(localized: .DiagUToolPermission)
       case .coreInstall:        return String(localized: .DiagCoreInstall)
       case .coreArch:           return String(localized: .DiagCoreArch)
       case .configFile:         return String(localized: .DiagConfigFile)
       case .geoipFile:          return String(localized: .DiagGeoipFile)
       case .geositeFile:        return String(localized: .DiagGeositeFile)
       case .coreRunning:        return String(localized: .DiagCoreRunning)
       case .nodeConnectivity:   return "节点连接"
       case .localPortConflict:  return String(localized: .DiagLocalPortConflict)
       case .pingLatency:        return String(localized: .DiagPingLatency)
       case .logAnalysis:        return String(localized: .DiagLogAnalysis)
       }
   }
    // MARK: - 各项检查（返回 DiagnosticItem）
    
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
    
    private func checkCoreArch() async -> DiagnosticItem {
        let installed = FileManager.default.fileExists(atPath: xrayCoreFile)
        let executable = installed && FileManager.default.isExecutableFile(atPath: xrayCoreFile)
        
        let currentArch = isARM64() ? "arm64" : "amd64"
        let actualArch = executable ? getFileArch(file: xrayCoreFile) : nil
        let ok = actualArch == currentArch
        
        let subtitle: String
        let problem: String?
        
        if !installed {
            subtitle = String(localized: .DiagCoreNotInstalled)
            problem = String(localized: .DiagCoreNotInstalled)
        } else if !executable {
            subtitle = String(localized: .DiagCoreNotExecutable)
            problem = String(localized: .DiagCoreNotExecutable)
        } else if ok {
            subtitle = String(format: String(localized: .DiagCoreArchCorrect), actualArch ?? "unknown")
            problem = nil
        } else {
            subtitle = String(format: String(localized: .DiagCoreArchMismatch), actualArch ?? "unknown", currentArch)
            problem = String(format: String(localized: .DiagCoreArchMismatch), actualArch ?? "unknown", currentArch)
        }
        
        return DiagnosticItem(
            step: .coreArch,
            title: String(localized: .DiagCoreArch),
            subtitle: subtitle,
            ok: ok,
            problem: problem,
            actionTitle: ok ? nil : String(localized: .DiagFixNow),
            action: ok ? nil : { self.fixInstallAll() }
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
    
    private func checkGeositeFile() async -> DiagnosticItem {
        let exists = FileManager.default.fileExists(atPath: xrayCorePath + "/geosite.dat")
        
        let subtitle: String
        let problem: String?
        
        if exists {
            subtitle = String(localized: .DiagPassed)
            problem = nil
        } else {
            subtitle = String(localized: .DiagGeositeMissing)
            problem = String(localized: .DiagGeositeMissing)
        }
        
        return DiagnosticItem(
            step: .geositeFile,
            title: String(localized: .DiagGeositeFile),
            subtitle: subtitle,
            ok: exists,
            problem: problem,
            actionTitle: exists ? nil : String(localized: .DiagFixNow),
            action: exists ? nil : { self.fixGeoip() }
        )
    }
    
    private func checkConfigFile() async -> DiagnosticItem {
        let exists = FileManager.default.fileExists(atPath: JsonConfigFilePath)
        
        let subtitle: String
        let problem: String?
        
        if exists {
            let fileSize = (try? FileManager.default.attributesOfItem(atPath: JsonConfigFilePath)[.size] as? Int) ?? 0
            if fileSize > 0 {
                subtitle = String(format: String(localized: .DiagConfigFileExists), fileSize)
                problem = nil
            } else {
                subtitle = String(localized: .DiagConfigFileEmpty)
                problem = String(localized: .DiagConfigFileEmpty)
            }
        } else {
            subtitle = String(localized: .DiagConfigFileMissing)
            problem = String(localized: .DiagConfigFileMissing)
        }
        
        return DiagnosticItem(
            step: .configFile,
            title: String(localized: .DiagConfigFile),
            subtitle: subtitle,
            ok: exists && ((try? FileManager.default.attributesOfItem(atPath: JsonConfigFilePath)[.size] as? Int) ?? 0) > 0,
            problem: problem,
            actionTitle: exists ? nil : String(localized: .DiagFixNow),
            action: exists ? nil : { self.fixInstallAll() }
        )
    }
    
    private func checkV2rayUToolInstall() async -> DiagnosticItem {
        let exists = FileManager.default.fileExists(atPath: v2rayUToolPath)
        let executable = exists && FileManager.default.isExecutableFile(atPath: v2rayUToolPath)
        
        let subtitle: String
        let problem: String?
        
        if executable {
            subtitle = String(localized: .DiagPassed)
            problem = nil
        } else if exists {
            subtitle = String(localized: .DiagToolNoPermission)
            problem = String(localized: .DiagToolNoPermission)
        } else {
            subtitle = String(localized: .DiagToolMissing)
            problem = String(localized: .DiagToolMissing)
        }
        
        return DiagnosticItem(
            step: .v2rayUToolInstall,
            title: String(localized: .DiagV2rayUToolInstall),
            subtitle: subtitle,
            ok: executable,
            problem: problem,
            actionTitle: executable ? nil : String(localized: .DiagFixNow),
            action: executable ? nil : { self.fixV2rayUTool() }
        )
    }
    
    private func checkPingLatency() async -> DiagnosticItem {
        await PingAll.shared.run()
        let latency = appState.latency
        
        let subtitle: String
        let problem: String?
        let ok: Bool
        
        if latency > 0 {
            ok = true
            if latency < 100 {
                subtitle = String(format: String(localized: .DiagPassed), Int(latency))
            } else if latency < 300 {
                subtitle = String(format: "延迟 %dms (可接受)", Int(latency))
            } else {
                subtitle = String(format: "延迟 %dms (较高但可用)", Int(latency))
            }
            problem = nil
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
    
    private func checkNodeConnectivity() async -> DiagnosticItem {
        guard let host = nodeHostProvider() else {
            return DiagnosticItem(
                step: .coreRunning,
                title: "节点连接",
                subtitle: "未选择节点",
                ok: false,
                problem: "请先选择节点",
                actionTitle: nil,
                action: nil
            )
        }
        
        let dnsOK = await NetworkChecker.canResolve(host: host)
        
        guard let port = nodePortProvider() else {
            return DiagnosticItem(
                step: .coreRunning,
                title: "节点连接",
                subtitle: "未选择节点",
                ok: false,
                problem: "请先选择节点",
                actionTitle: nil,
                action: nil
            )
        }
        
        let portOK = await TCPConnectivity.canConnect(host: host, port: port)
        
        let ok = dnsOK && portOK
        let subtitle: String
        let problem: String?
        
        if dnsOK && portOK {
            subtitle = "节点正常"
            problem = nil
        } else if !dnsOK {
            subtitle = "域名解析失败"
            problem = "【节点失效】域名无法解析，节点可能已过期或被封"
        } else {
            subtitle = "端口连接失败"
            problem = "【连接失败】无法连接到节点服务器"
        }
        
        return DiagnosticItem(
            step: .coreRunning,
            title: "节点连接",
            subtitle: subtitle,
            ok: ok,
            problem: problem,
            actionTitle: nil,
            action: nil
        )
    }
    
    private func checkLogAnalysis() async -> DiagnosticItem {
        let problems = LogAnalyzer.analyze(logPath: logPath, lastLines: 500)
        self.logContent = LogAnalyzer.getSurroundingLog(logPath: logPath, lastLines: 500, contextLines: 3)
        let ok = problems.isEmpty || (problems.count == 1 && problems[0] == "未发现明显错误")
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
    
    private func openConfigFile() {
        let url = URL(fileURLWithPath: JsonConfigFilePath)
        NSWorkspace.shared.open(url)
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
    
    private func isARM64() -> Bool {
        #if arch(arm64)
        return true
        #else
        return false
        #endif
    }
    
    private func getFileArch(file: String) -> String? {
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: file))
            guard data.count >= 20 else { return nil }
            
            if data[0] == 0x7F && data[1] == 0x45 && data[2] == 0x4C && data[3] == 0x46 {
                let eMachine = data.withUnsafeBytes { $0.load(fromByteOffset: 18, as: UInt16.self) }
                switch eMachine {
                case 62: return "amd64"
                case 183: return "arm64"
                default: return "unknown"
                }
            }
            else if data[0] == 0xCF && data[1] == 0xFA && data[2] == 0xED && data[3] == 0xFE {
                let cpuType = data.withUnsafeBytes { $0.load(fromByteOffset: 4, as: Int32.self) }
                switch cpuType {
                case 0x01000007: return "x86_64"
                case 0x0100000C: return "arm64"
                default: return "unknown"
                }
            }
            
            return nil
        } catch {
            return nil
        }
    }
    
    // MARK: - 提交诊断报告
    
    func generateReport() -> String {
        var report = """
        ## 环境信息
        - V2rayU 版本: \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown")
        - macOS 版本: \(ProcessInfo.processInfo.operatingSystemVersionString)
        - 核心状态: \(appState.v2rayTurnOn ? "已开启" : "已关闭")
        
        ## 诊断结果
        """
        
        for category in DiagnosticCategory.allCases {
            let failedItems = itemsForCategory(category).filter { !$0.ok }
            if !failedItems.isEmpty {
                report += "\n### \(category.rawValue)\n"
                for item in failedItems {
                    let problem = item.problem.map { "\n  问题: \($0)" } ?? ""
                    report += "- ❌ \(item.title): \(item.subtitle ?? item.defaultSubtitle)\(problem)\n"
                }
            }
        }
        
        if !logContent.isEmpty && logContent != "无 INFO 及以上级别日志" {
            let truncatedLog = String(logContent.prefix(1500))
            report += "\n---\n\n## 错误日志\n```\n\(truncatedLog)\n```"
        }
        
        return report
    }
    
    func submitToGitHub() {
        let report = generateReport()
        let title = "[Bug Report] V2rayU 诊断报告 - \(Date().formatted(date: .abbreviated, time: .shortened))"
        let encodedTitle = title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedBody = report.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        if let url = URL(string: "https://github.com/yanue/V2rayU/issues/new?title=\(encodedTitle)&body=\(encodedBody)") {
            NSWorkspace.shared.open(url)
        }
    }
}
