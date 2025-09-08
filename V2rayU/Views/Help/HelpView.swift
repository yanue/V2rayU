//
//  LogsPage.swift
//  V2rayU
//
//  Created by yanue on 2025/7/15.
//

import SwiftUI
import AppKit

struct HelpView: View {
    @ObservedObject var appState = AppState.shared // 引用单例

    @State private var v2rayCoreInstalled: Bool = false
    @State private var v2rayCoreVersion: String = ""
    @State private var v2rayCoreRunning: Bool = false
    @State private var v2rayUToolPermission: Bool = false
    @State private var geoipExists: Bool = false
    @State private var pingStatus: Bool = false
    @State private var showOpenSettingsAlert = false
    @State private var checking: Bool = false

    // 问题描述
    var v2rayUToolProblem: String? {
        v2rayUToolPermission ? nil : LanguageManager.shared.localizedString(LanguageLabel.V2rayUToolProblem.rawValue)
    }
    var v2rayCoreProblem: String? {
        v2rayCoreInstalled ? nil : LanguageManager.shared.localizedString(LanguageLabel.V2rayCoreProblem.rawValue)
    }
    var backgroundProblem: String? {
        v2rayCoreRunning ? nil : LanguageManager.shared.localizedString(LanguageLabel.BackgroundProblem.rawValue)
    }
    var geoipProblem: String? {
        geoipExists ? nil : LanguageManager.shared.localizedString(LanguageLabel.GeoipProblem.rawValue)
    }
    var pingProblem: String? {
        appState.latency > 0 ? nil : LanguageManager.shared.localizedString(LanguageLabel.PingProblem.rawValue)
    }

    func fixBackgroundActivity() {
        // 尝试打开系统设置的后台活动页面（不同系统版本可能不同）
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.general") {
            NSWorkspace.shared.open(url)
        } else if let url2 = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
            NSWorkspace.shared.open(url2)
        } else {
            showOpenSettingsAlert = true
        }
    }

    func fixInstallAll() {
        // 调用安装器检查并弹出安装对话
        Task {
            await AppInstaller.shared.checkInstall()
            await MainActor.run {
                runAllChecks()
            }
        }
    }

    func fixV2rayUTool() {
        Task {
            await AppInstaller.shared.checkInstall()
            await MainActor.run { runAllChecks() }
        }
    }

    func fixGeoip() {
        Task {
            await AppInstaller.shared.checkInstall()
            await MainActor.run { runAllChecks() }
        }
    }

    func restartCore() {
        Task {
            V2rayLaunch.stopV2rayCore()
            // small delay to allow stop
            try? await Task.sleep(nanoseconds: 300_000_000)
            AppState.shared.turnOnCore()
            await MainActor.run { runAllChecks() }
        }
    }

    func toggleCoreOnOff() {
        if appState.v2rayTurnOn {
            AppState.shared.turnOffCore()
        } else {
            AppState.shared.turnOnCore()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { runAllChecks() }
    }

    func doPingNow() {
        Task {
            checking = true
            await PingAll.shared.run()
            // 等待 ping 结果更新
            try? await Task.sleep(nanoseconds: 500_000_000)
            checking = false
            await MainActor.run { runAllChecks() }
        }
    }

    func checkV2rayCore() {
        v2rayCoreInstalled = FileManager.default.fileExists(atPath: v2rayCoreFile) && FileManager.default.isExecutableFile(atPath: v2rayCoreFile)
        v2rayCoreVersion = getCoreVersion()
    }

    func checkV2rayCoreRunning() {
        let task = Process()
        let pipe = Pipe()
        task.launchPath = "/bin/ps"
        task.arguments = ["aux"]
        task.standardOutput = pipe
        try? task.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        // 更严格匹配 v2ray 可执行路径或 v2ray-core 名称
        v2rayCoreRunning = output.contains("v2ray") || output.contains("xray")
    }

    func checkV2rayUTool() {
        v2rayUToolPermission = FileManager.default.fileExists(atPath: v2rayUTool) && checkFileIsRootAdmin(file: v2rayUTool)
    }

    func checkGeoip() {
        geoipExists = FileManager.default.fileExists(atPath: v2rayCorePath + "/geoip.dat")
    }

    func checkPing() {
        // 使用 appState.latency 作为判断依据
        pingStatus = appState.latency > 0
    }

    func runAllChecks() {
        checking = true
        checkV2rayCore()
        checkV2rayCoreRunning()
        checkV2rayUTool()
        checkGeoip()
        checkPing()
        // 小延迟确保 UI 更新
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            checking = false
        }
    }

    // 简洁的状态行组件
    @ViewBuilder
    func statusRow(title: String, subtitle: String?, ok: Bool, problem: String?, actionTitle: String? = nil, action: (() -> Void)? = nil) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: ok ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                .resizable()
                .frame(width: 24, height: 24)
                .foregroundColor(ok ? .green : .orange)
                .padding(.top, 4)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(title).font(.headline)
                    Spacer()
                    if let actionTitle = actionTitle, let action = action {
                        Button(actionTitle) { action() }
                            .background(Color.accentColor.opacity(0.12))
                            .cornerRadius(6)
                    }
                }
                if let subtitle = subtitle {
                    if ok {
                        Text(subtitle).font(.subheadline).foregroundColor(.green)
                    }
                }
                if let problem = problem {
                    Text(problem).font(.caption).foregroundColor(.red)
                }
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(NSColor.windowBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.08)))
    }

    var body: some View {
        VStack {
            VStack(spacing: 14) {
                HStack {
                    VStack(alignment: .leading) {
                        Text(LanguageManager.shared.localizedString(LanguageLabel.HelpDiagnosticsTitle.rawValue)).font(.largeTitle).bold()
                        Text(LanguageManager.shared.localizedString(LanguageLabel.HelpDiagnosticsSubHead.rawValue)).foregroundColor(.secondary)
                    }
                    Spacer()
                    Button(action: runAllChecks) {
                        HStack {
                            if checking { ProgressView().scaleEffect(0.8) }
                            Text(LanguageManager.shared.localizedString(LanguageLabel.Refresh.rawValue))
                        }
                    }
                    .buttonStyle(BorderlessButtonStyle())
                }
                ScrollView{
                    VStack(spacing: 10) {
                        statusRow(title: LanguageManager.shared.localizedString(LanguageLabel.V2rayCoreSwitchStatus.rawValue), subtitle: appState.v2rayTurnOn ? LanguageManager.shared.localizedString(LanguageLabel.Installed.rawValue) : LanguageManager.shared.localizedString(LanguageLabel.Missing.rawValue), ok: appState.v2rayTurnOn, problem: appState.v2rayTurnOn ? nil : LanguageManager.shared.localizedString(LanguageLabel.V2rayCoreNotInstalled.rawValue), actionTitle: appState.v2rayTurnOn ? LanguageManager.shared.localizedString(LanguageLabel.TurnCoreOff.rawValue) : LanguageManager.shared.localizedString(LanguageLabel.TurnCoreOn.rawValue)) {
                             toggleCoreOnOff()
                         }
                         
                        statusRow(title: LanguageManager.shared.localizedString(LanguageLabel.V2rayCoreRunningStatus.rawValue), subtitle: v2rayCoreRunning ? LanguageManager.shared.localizedString(LanguageLabel.BackgroundActivitySubtitleRunning.rawValue) : LanguageManager.shared.localizedString(LanguageLabel.BackgroundActivitySubtitleNotRunning.rawValue), ok: v2rayCoreRunning, problem: backgroundProblem, actionTitle: LanguageManager.shared.localizedString(LanguageLabel.Restart.rawValue)) {
                             restartCore()
                         }
                         
                        statusRow(title: LanguageManager.shared.localizedString(LanguageLabel.BackgroundActivity.rawValue), subtitle: v2rayCoreRunning ? LanguageManager.shared.localizedString(LanguageLabel.BackgroundActivitySubtitleRunning.rawValue) : LanguageManager.shared.localizedString(LanguageLabel.BackgroundActivitySubtitleNotRunning.rawValue), ok: v2rayCoreRunning, problem: backgroundProblem, actionTitle: LanguageManager.shared.localizedString(LanguageLabel.OpenSettings.rawValue)) {
                             fixBackgroundActivity()
                         }
                         
                        statusRow(title: LanguageManager.shared.localizedString(LanguageLabel.RunPingNow.rawValue), subtitle: pingStatus ? String(format: "%.0f ms", appState.latency) : LanguageManager.shared.localizedString(LanguageLabel.Missing.rawValue), ok: pingStatus, problem: pingProblem, actionTitle: LanguageManager.shared.localizedString(LanguageLabel.RunPingNow.rawValue)) {
                             doPingNow()
                         }
                         
                        statusRow(title: LanguageManager.shared.localizedString(LanguageLabel.V2rayCoreInstallAndVersion.rawValue), subtitle: v2rayCoreVersion, ok: v2rayCoreInstalled, problem: v2rayCoreProblem, actionTitle: LanguageManager.shared.localizedString(LanguageLabel.Fix.rawValue)) {
                             fixInstallAll()
                         }
                         
                        statusRow(title: LanguageManager.shared.localizedString(LanguageLabel.V2rayUToolPermission.rawValue), subtitle: v2rayUToolPermission ? LanguageManager.shared.localizedString(LanguageLabel.PermissionException.rawValue) : LanguageManager.shared.localizedString(LanguageLabel.Missing.rawValue), ok: v2rayUToolPermission, problem: v2rayUToolProblem, actionTitle: LanguageManager.shared.localizedString(LanguageLabel.Fix.rawValue)) {
                             fixV2rayUTool()
                         }
                         
                        statusRow(title: LanguageManager.shared.localizedString(LanguageLabel.GeoipFile.rawValue), subtitle: geoipExists ? LanguageManager.shared.localizedString(LanguageLabel.Installed.rawValue) : LanguageManager.shared.localizedString(LanguageLabel.Missing.rawValue), ok: geoipExists, problem: geoipProblem, actionTitle: LanguageManager.shared.localizedString(LanguageLabel.Fix.rawValue)) {
                             fixGeoip()
                         }
                     }
                     .padding(.top, 6)
                 }
             }
             .padding()
         }
         .onAppear { runAllChecks() }
         .alert(isPresented: $showOpenSettingsAlert) {
            Alert(title: Text(LanguageManager.shared.localizedString(LanguageLabel.UnableToOpenSystemSettings.rawValue)), message: Text(LanguageManager.shared.localizedString(LanguageLabel.PleaseManuallyOpenBackgroundActivity.rawValue)), dismissButton: .default(Text(LanguageManager.shared.localizedString(LanguageLabel.Confirm.rawValue))))
        }
     }
 }
