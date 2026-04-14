//
//  ImportView.swift
//  V2rayU
//
//  Created by yanue on 2025/1/15.
//  Copyright © 2025 yanue. All rights reserved.
//
//  服务器导入界面
//  支持从 URL 链接、JSON 配置、订阅链接导入服务器
//

import SwiftUI
import Yams

/// 导入来源类型
private enum ImportSource: String, CaseIterable {
    case legacy
    case uri
    case json
    case subscription
    case clash

    var label: LanguageLabel {
        switch self {
        case .legacy: return .ImportSourceLegacy
        case .uri: return .ImportSourceUri
        case .json: return .ImportSourceJson
        case .subscription: return .ImportSourceSubscription
        case .clash: return .ImportSourceClash
        }
    }

    var placeholder: LanguageLabel? {
        switch self {
        case .uri: return .ImportUriPlaceholder
        case .json: return .ImportJsonPlaceholder
        case .subscription: return .ImportSubscriptionPlaceholder
        case .clash: return .ImportClashPlaceholder
        case .legacy: return nil
        }
    }
}

struct ImportView: View {
    @State private var importSource: ImportSource = .legacy
    @State private var inputText: String = ""
    @State private var isImporting: Bool = false
    @State private var resultMessage: String = ""
    @State private var resultIsError: Bool = false
    @State private var newSubscription: SubscriptionModel?
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // 头部
            HStack(spacing: 12) {
                Image(systemName: "square.and.arrow.down")
                    .font(.system(size: 24))
                    .foregroundStyle(.blue)

                LocalizedTextLabelView(label: .ImportServersTitle)
                    .font(.headline)

                Spacer()

                Button(action: { onDismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .focusable(false)
                .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)

            Divider()

            // 导入操作栏
            VStack(spacing: 10) {
                HStack(spacing: 8) {
                    // 来源选择器
                    Picker("", selection: $importSource) {
                        ForEach(ImportSource.allCases, id: \.self) { source in
                            LocalizedTextLabelView(label: source.label).tag(source)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 300)
                    .focusable(false)
                    .onChange(of: importSource) { _, newValue in
                        inputText = ""
                        resultMessage = ""
                        resultIsError = false
                        if newValue == .subscription && newSubscription == nil {
                            let entity = SubscriptionEntity()
                            newSubscription = SubscriptionModel(from: entity)
                        }
                    }

                    Spacer()
                }

                // 输入区域
                if importSource == .subscription {
                    if let subscription = newSubscription {
                        SubscriptionFormView(item: subscription, showHeader: false) {
                            onDismiss()
                        } onSaveAndSync: {
                            onDismiss()
                        }
                    }
                } else if importSource == .legacy {
                    // 旧版导入
                    legacyImportContent
                } else {
                    // URL / JSON / Clash 用多行输入
                    VStack(spacing: 8) {
                        TextEditor(text: $inputText)
                            .font(.system(.body, design: .monospaced))
                            .frame(minHeight: 80, maxHeight: 160)
                            .padding(4)
                            .background(Color(NSColor.textBackgroundColor))
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                            .overlay(alignment: .topLeading) {
                                if let placeholder = importSource.placeholder, inputText.isEmpty {
                                    Text(String(localized: placeholder))
                                        .foregroundColor(.secondary.opacity(0.5))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 10)
                                        .allowsHitTesting(false)
                                }
                            }

                        HStack {
                            if importSource == .json || importSource == .clash {
                                Button(action: importFromFile) {
                                    Label(String(localized: .ImportFromFile), systemImage: "doc")
                                }
                                .buttonStyle(.bordered)
                                .focusable(false)
                            }
                            Spacer()
                            importButton
                        }
                    }
                }

                // 结果消息
                if !resultMessage.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: resultIsError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                            .foregroundColor(resultIsError ? .orange : .green)
                            .font(.system(size: 13))
                        Text(resultMessage)
                            .font(.subheadline)
                            .foregroundColor(resultIsError ? .orange : .green)
                            .lineLimit(2)
                        Spacer()
                    }
                    .padding(.top, 2)
                }
            }
            .padding(16)

            Spacer(minLength: 0)
        }
        .frame(width: 520)
    }

    // MARK: - 导入按钮

    private var importButton: some View {
        Button(action: doImport) {
            if isImporting {
                HStack(spacing: 4) {
                    ProgressView()
                        .controlSize(.small)
                    LocalizedTextLabelView(label: .ImportParsing)
                }
            } else {
                LocalizedTextLabelView(label: .ImportButton)
            }
        }
        .buttonStyle(.borderedProminent)
        .focusable(false)
        .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isImporting)
        .frame(minWidth: 80)
    }

    // MARK: - 导入操作

    private func doImport() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        resultMessage = ""
        resultIsError = false
        isImporting = true

        switch importSource {
        case .uri:
            importFromUri(text: text)
        case .json:
            importFromJsonText(text: text)
        case .subscription:
            break
        case .clash:
            importFromClash(text: text)
        case .legacy:
            break
        }
    }

    // MARK: - 旧版导入内容

    @State private var legacyServerCount: Int = 0
    @State private var legacySubCount: Int = 0
    @State private var showConfirmDialog = false
    @State private var legacyDebugInfo: String = ""
    @State private var migrationResult: LegacyMigrationResult?
    @State private var showResult = false

    private var legacyImportContent: some View {
        VStack(spacing: 20) {
            if isImporting {
                migratingView
            } else if showResult, let result = migrationResult {
                legacyResultView(result: result)
            } else {
                legacyDataContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .alert(String(localized: .ImportLegacyConfirmTitle), isPresented: $showConfirmDialog) {
            Button(String(localized: .Cancel), role: .cancel) { }
            Button(String(localized: .ImportLegacyData)) {
                performLegacyMigration()
            }
        } message: {
            Text(String(localized: .ImportLegacyConfirmMessage, arguments: legacyServerCount, legacySubCount))
        }
        .onAppear {
            checkLegacyData()
        }
    }

    private var legacyDataContent: some View {
        VStack(spacing: 16) {
            if legacyServerCount > 0 || legacySubCount > 0 {
                legacyDataCard
            } else {
                legacyNoDataCard
            }

            if !legacyDebugInfo.isEmpty {
                legacyDebugCard
            }
        }
    }

    private var legacyDataCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.orange)
                Text(String(localized: .ImportLegacyDataDetected))
                    .font(.headline)
                Spacer()
            }

            HStack(spacing: 24) {
                legacyDataItem(
                    icon: "server.rack",
                    title: String(localized: .ImportLegacyDataServerCount, arguments: legacyServerCount),
                    color: .blue
                )

                legacyDataItem(
                    icon: "list.bullet.rectangle",
                    title: String(localized: .ImportLegacyDataSubCount, arguments: legacySubCount),
                    color: .purple
                )
            }

            Button(action: { showConfirmDialog = true }) {
                HStack {
                    Image(systemName: "square.and.arrow.down.on.square")
                    Text(String(localized: .ImportLegacyData))
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(16)
        .background(Color.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func legacyDataItem(icon: String, title: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var legacyNoDataCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)
            Text(String(localized: .ImportLegacyDataNoData))
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .background(Color.green.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var legacyDebugCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Debug Info")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            ScrollView {
                Text(legacyDebugInfo)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .frame(maxHeight: 100)
        }
        .padding(12)
        .background(Color.gray.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var migratingView: some View {
        VStack(spacing: 16) {
            Spacer()

            ProgressView()
                .scaleEffect(1.5)
            Text(String(localized: .ImportLegacyDataMigrating))
                .font(.headline)
                .foregroundStyle(.secondary)

            if !legacyDebugInfo.isEmpty {
                Text(legacyDebugInfo)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: 300)
                    .multilineTextAlignment(.center)
            }

            Spacer()
        }
    }

    @ViewBuilder
    private func legacyResultView(result: LegacyMigrationResult) -> some View {
        switch result {
        case .success(let profiles, let subscriptions):
            VStack(spacing: 16) {
                Spacer()

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.green)
                Text(String(localized: .LegacyDataMigrationSuccess, arguments: profiles, subscriptions))
                    .font(.title3)
                    .multilineTextAlignment(.center)

                if !legacyDebugInfo.isEmpty {
                    Text(legacyDebugInfo)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: 300)
                        .multilineTextAlignment(.center)
                }

                Spacer()

                Button(String(localized: .Close)) {
                    onDismiss()
                }
                .focusable(false)
            }
            .padding()

        case .noData:
            VStack(spacing: 12) {
                Spacer()
                Image(systemName: "tray")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                Text(String(localized: .LegacyDataMigrationNoData))
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding()

        case .error(let message):
            VStack(spacing: 16) {
                Spacer()

                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.orange)
                Text(String(localized: .LegacyDataMigrationFailed, arguments: message))
                    .font(.title3)
                    .multilineTextAlignment(.center)

                if !legacyDebugInfo.isEmpty {
                    Text(legacyDebugInfo)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: 300)
                        .multilineTextAlignment(.center)
                }

                Spacer()
            }
            .padding()
        }
    }

    private func checkLegacyData() {
        Task {
            let defaults = UserDefaults(suiteName: "net.yanue.V2rayU") ?? .standard
            let serverList = defaults.array(forKey: "v2rayServerList") as? [String] ?? []
            let subList = defaults.array(forKey: "v2raySubList") as? [String] ?? []

            await MainActor.run {
                legacyServerCount = serverList.count
                legacySubCount = subList.count

                var info = String(localized: .ImportLegacyDetectedKeys) + "\n"
                info += String(localized: .ImportLegacyV2rayServerList) + "\(serverList.count)\n"
                info += String(localized: .ImportLegacyV2raySubList) + "\(subList.count)"

                if !serverList.isEmpty {
                    info += "\n\n" + String(localized: .ImportLegacyServerList) + "\n"
                    for (index, item) in serverList.enumerated() {
                        info += "  \(index + 1). \(item)\n"
                    }
                }

                if !subList.isEmpty {
                    info += "\n\n" + String(localized: .ImportLegacySubList) + "\n"
                    for (index, item) in subList.enumerated() {
                        info += "  \(index + 1). \(item)\n"
                    }
                }

                legacyDebugInfo = info
            }
        }
    }

    private func performLegacyMigration() {
        isImporting = true
        legacyDebugInfo = String(localized: .ImportLegacyMigratingStart) + "\n"

        Task {
            let result = await LegacyMigrationHandler.shared.migrate()

            await MainActor.run {
                isImporting = false
                migrationResult = result
                showResult = true

                switch result {
                case .success(let profiles, let subscriptions):
                    legacyDebugInfo = String(localized: .ImportLegacyMigratingComplete) + "\n\n"
                    legacyDebugInfo += String(localized: .ImportLegacySuccessServers, arguments: profiles) + "\n"
                    legacyDebugInfo += String(localized: .ImportLegacySuccessSubscriptions, arguments: subscriptions)
                case .noData:
                    legacyDebugInfo = String(localized: .ImportLegacyNoDataFound)
                case .error(let message):
                    legacyDebugInfo = String(localized: .ImportLegacyMigrationFailed) + message
                }
            }
        }
    }

    /// 从旧版导入 (保留旧的简单版本供兼容)
    private func importFromLegacy() {
        isImporting = true
        Task {
            let result = await LegacyMigrationHandler.shared.migrate()
            await MainActor.run {
                isImporting = false
                switch result {
                case .success(let profiles, let subs):
                    resultMessage = String(localized: .ImportSuccessCount, arguments: profiles)
                    resultIsError = false
                    legacyServerCount = 0
                    legacySubCount = 0
                case .noData:
                    resultMessage = String(localized: .ImportLegacyNoDataFound)
                    resultIsError = true
                case .error(let msg):
                    resultMessage = String(localized: .ImportLegacyMigrationFailed, arguments: msg)
                    resultIsError = true
                }
            }
        }
    }

    /// 跳过旧版导入
    private func skipLegacy() {
        LegacyMigrationHandler.shared.markAsMigrated()
        LegacyMigrationHandler.shared.markAsAsked()
        legacyServerCount = 0
        legacySubCount = 0
    }

    /// 从 Clash YAML 配置导入
    private func importFromClash(text: String) {
        do {
            let decoder = YAMLDecoder()
            let decoded = try decoder.decode(Clash.self, from: text)
            if decoded.proxies.isEmpty {
                isImporting = false
                resultMessage = String(localized: .ImportFailedDetail, arguments: "No proxies found in Clash config")
                resultIsError = true
                return
            }
            var successCount = 0
            for clash in decoded.proxies {
                if let item = clash.toProfile() {
                    ProfileStore.shared.insert(item)
                    successCount += 1
                }
            }
            isImporting = false
            if successCount > 0 {
                resultMessage = String(localized: .ImportSuccessCount, arguments: successCount)
                resultIsError = false
                inputText = ""
            } else {
                resultMessage = String(localized: .ImportFailedDetail, arguments: "No valid servers found")
                resultIsError = true
            }
        } catch {
            isImporting = false
            resultMessage = String(localized: .ImportFailedDetail, arguments: "Invalid Clash YAML format")
            resultIsError = true
        }
    }

    /// 从 URI 分享链接导入 (支持多行)
    private func importFromUri(text: String) {
        let lines = text.components(separatedBy: CharacterSet.newlines)
        var successCount = 0
        var errors: [String] = []

        for line in lines {
            let uri = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if uri.isEmpty { continue }

            let importTask = ImportUri(share_uri: uri)
            if let profile = importTask.doImport() {
                ProfileStore.shared.insert(profile)
                successCount += 1
            } else {
                errors.append(importTask.error)
            }
        }

        isImporting = false
        if successCount > 0 {
            resultMessage = String(localized: .ImportSuccessCount, arguments: successCount)
            resultIsError = false
            inputText = ""
        } else {
            let errorMsg = errors.first ?? "unknown error"
            resultMessage = String(localized: .ImportFailedDetail, arguments: errorMsg)
            resultIsError = true
        }
    }

    /// 从 JSON 配置文本导入
    private func importFromJsonText(text: String) {
        if let profile = importFromJson(json: text) {
            ProfileStore.shared.insert(profile)
            isImporting = false
            resultMessage = String(localized: .ImportSuccessCount, arguments: 1)
            resultIsError = false
            inputText = ""
        } else {
            isImporting = false
            resultMessage = String(localized: .ImportFailedDetail, arguments: "Invalid JSON config or no proxy outbound found")
            resultIsError = true
        }
    }

    /// 从订阅链接导入（不创建订阅记录，直接导入服务器到默认分组）
    private func importFromSubscription(url: String) {
        guard let reqUrl = URL(string: url), reqUrl.scheme != nil else {
            isImporting = false
            resultMessage = String(localized: .ImportFailedDetail, arguments: "Invalid URL")
            resultIsError = true
            return
        }

        Task {
            do {
                // 下载订阅内容
                let session = URLSession(configuration: getProxyUrlSessionConfigure())
                let (data, _) = try await session.data(for: URLRequest(url: reqUrl))
                guard let content = String(data: data, encoding: .utf8) else {
                    await MainActor.run {
                        isImporting = false
                        resultMessage = String(localized: .ImportFailedDetail, arguments: "Cannot decode response")
                        resultIsError = true
                    }
                    return
                }

                // base64 解码
                let decoded = content.trimmingCharacters(in: .whitespacesAndNewlines).base64Decoded() ?? content

                // 按行解析为 URI 列表
                let lines = decoded.trimmingCharacters(in: .newlines).components(separatedBy: CharacterSet.newlines)
                var successCount = 0
                for line in lines {
                    let uri = line.trimmingCharacters(in: .whitespacesAndNewlines)
                    if uri.isEmpty { continue }
                    let importTask = ImportUri(share_uri: uri)
                    if let profile = importTask.doImport() {
                        ProfileStore.shared.insert(profile)
                        successCount += 1
                    }
                }

                await MainActor.run {
                    isImporting = false
                    if successCount > 0 {
                        resultMessage = String(localized: .ImportSuccessCount, arguments: successCount)
                        resultIsError = false
                        inputText = ""
                    } else {
                        resultMessage = String(localized: .ImportFailedDetail, arguments: "No servers found in subscription")
                        resultIsError = true
                    }
                }
            } catch {
                await MainActor.run {
                    isImporting = false
                    resultMessage = String(localized: .ImportFailedDetail, arguments: error.localizedDescription)
                    resultIsError = true
                }
            }
        }
    }

    /// 从文件导入 JSON/Clash 配置
    private func importFromFile() {
        let panel = NSOpenPanel()
        
        if importSource == .clash {
            panel.allowedContentTypes = [.yaml, .plainText]
        } else {
            panel.allowedContentTypes = [.json, .plainText]
        }
        
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        if panel.runModal() == .OK, let url = panel.url {
            do {
                let content = try String(contentsOf: url, encoding: .utf8)
                inputText = content
            } catch {
                resultMessage = String(localized: .ImportFailedDetail, arguments: error.localizedDescription)
                resultIsError = true
            }
        }
    }
}

