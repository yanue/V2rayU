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

/// 导入来源类型
private enum ImportSource: String, CaseIterable {
    case url
    case json
    case subscription

    var label: LanguageLabel {
        switch self {
        case .url: return .ImportSourceUrl
        case .json: return .ImportSourceJson
        case .subscription: return .ImportSourceSubscription
        }
    }

    var placeholder: LanguageLabel {
        switch self {
        case .url: return .ImportUrlPlaceholder
        case .json: return .ImportJsonPlaceholder
        case .subscription: return .ImportSubscriptionPlaceholder
        }
    }
}

struct ImportView: View {
    @State private var importSource: ImportSource = .url
    @State private var inputText: String = ""
    @State private var isImporting: Bool = false
    @State private var resultMessage: String = ""
    @State private var resultIsError: Bool = false
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
                    .frame(width: 240)
                    .onChange(of: importSource) { _ in
                        inputText = ""
                        resultMessage = ""
                        resultIsError = false
                    }

                    Spacer()

                    // JSON 模式下的文件导入按钮
                    if importSource == .json {
                        Button(action: importFromFile) {
                            Label(String(localized: .ImportFromFile), systemImage: "doc")
                        }
                        .buttonStyle(.bordered)
                        .focusable(false)
                    }
                }

                // 输入区域
                if importSource == .subscription {
                    // 订阅链接用单行输入
                    HStack(spacing: 8) {
                        TextField(String(localized: importSource.placeholder), text: $inputText)
                            .textFieldStyle(.roundedBorder)

                        importButton
                    }
                } else {
                    // URL / JSON 用多行输入
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
                                if inputText.isEmpty {
                                    Text(String(localized: importSource.placeholder))
                                        .foregroundColor(.secondary.opacity(0.5))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 10)
                                        .allowsHitTesting(false)
                                }
                            }

                        HStack {
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
        .frame(width: 520, minHeight: importSource == .subscription ? 190 : 280)
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
        case .url:
            importFromUrl(text: text)
        case .json:
            importFromJsonText(text: text)
        case .subscription:
            importFromSubscription(url: text)
        }
    }

    /// 从 URL 分享链接导入 (支持多行)
    private func importFromUrl(text: String) {
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

    /// 从文件导入 JSON 配置
    private func importFromFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json, .plainText]
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

