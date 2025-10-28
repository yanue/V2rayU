//
//  DnsView.swift
//  V2rayU
//
//  Created by yanue on 2025/7/20.
//

import JavaScriptCore
import SwiftUI

struct DnsView: View {
    @State private var dnsJson: String = ""
    @State private var tips: String = ""
    @State private var showAlert: Bool = false
    @ObservedObject var settings = AppSettings() // 引用单例

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    localized(.DnsConfiguration)
                        .font(.title2)
                    localized(.DnsJsonFormatTip)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button(action: { goViewConfig(self) }) {
                    Label(String(localized: .ViewConfiguration), systemImage: "doc.text.magnifyingglass")
                }
                .buttonStyle(.borderedProminent)
            }

            VStack {
                TextEditor(text: $dnsJson)
                    .font(.system(.body, design: .monospaced))
            }
            .background() // 2. 然后背景
            .clipShape(RoundedRectangle(cornerRadius: 8)) // 3. 内圆角
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                    .shadow(color: Color.primary.opacity(0.1), radius: 1, x: 0, y: 1)
            ) // 4. 添加边框和阴影

            HStack {
                Button(action: { goHelp(self) }) {
                    Label(String(localized: .Help), systemImage: "questionmark.circle")
                }
                .buttonStyle(.bordered)
                Spacer()

                if !tips.isEmpty {
                    Text(tips)
                        .foregroundColor(tips.hasPrefix("Error") ? .red : .green)
                        .font(.callout)
                        .padding(.horizontal, 20)
                        .transition(.opacity)
                }

                Spacer()
                Button(action: { saveDnsServers() }) {
                    Label(String(localized: .Save), systemImage: "tray.and.arrow.down")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .onAppear { loadDnsServers() }
        .alert(isPresented: $showAlert) {
            Alert(title: Text(String(localized: .Notification)), message: Text(tips), dismissButton: .default(Text(String(localized: .Confirm))) )
        }
    }

    private func loadDnsServers() {
        dnsJson = AppSettings.shared.dnsJson
    }

    // MARK: - 保存 DNS 配置（本地化 + 结构化）
    private func saveDnsServers() {
        // 去除首尾空白和换行
        var str = dnsJson.trimmingCharacters(in: .whitespacesAndNewlines)

        // 检查输入能否编码为 UTF-8
        guard let data = str.data(using: .utf8) else {
            tips = String(localized: .DnsInvalidUTF8) // 错误：输入内容无法编码为 UTF-8
            showAlert = true
            return
        }

        var jsonObj: Any

        // 尝试解析 JSON 内容
        do {
            jsonObj = try JSONSerialization.jsonObject(with: data, options: [])
        } catch {
            tips = "\(String(localized: .DnsJSONFormatError)): \(error.localizedDescription)")
            showAlert = true
            return
        }

        // 如果 JSON 顶层包含 dns 节点，提取其内部内容
        if let dict = jsonObj as? [String: Any], let dnsConfig = dict["dns"] {
            jsonObj = dnsConfig
        }

        // 重新编码 JSON（格式化输出，key 按字母排序）
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]

        do {
            let formattedData = try encoder.encode(JSONAny(jsonObj))

            if let formattedStr = String(data: formattedData, encoding: .utf8) {
                // 触发配置更新
                AppSettings.shared.dnsJson = formattedStr
                AppSettings.shared.saveSettings()

                // 提示成功
                tips = String(localized: .DnsSaveSuccess) // DNS 配置保存成功
            } else {
                // 再次编码为字符串失败
                tips = String(localized: .DnsFormatEncodingFail) // Error: 格式化后内容无法编码为字符串
            }

            showAlert = true

        } catch {
            // 保存失败
            tips = "\(String(localized: .DnsSaveFail)):\(error.localizedDescription)")
            showAlert = true
        }

        // 5 秒后自动清空提示信息
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            self.tips = ""
        }
    }

    func goHelp(_ sender: Any) {
        if let url = URL(string: "https://xtls.github.io/config/dns.html#dnsobject") {
            NSWorkspace.shared.open(url)
        }
    }

    func goViewConfig(_ sender: Any) {
        let confUrl = getConfigUrl()
        if let url = URL(string: confUrl) {
            NSWorkspace.shared.open(url)
        }
    }
}
