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
                    Text("DNS 配置")
                        .font(.title2)
                    Text("仅支持 JSON 格式, 请输入 DNS 节点内的json配置(`dns`: {内容部分})")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button(action: { goViewConfig(self) }) {
                    Label("查看配置", systemImage: "doc.text.magnifyingglass")
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
                    Label("帮助", systemImage: "questionmark.circle")
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
                    Label("保存", systemImage: "tray.and.arrow.down")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .onAppear { loadDnsServers() }
        .alert(isPresented: $showAlert) {
            Alert(title: Text("提示"), message: Text(tips), dismissButton: .default(Text("确定")))
        }
    }

    private func loadDnsServers() {
        dnsJson = AppSettings.shared.dnsJson
    }

    private func saveDnsServers() {
        var str = dnsJson.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = str.data(using: .utf8) else {
            tips = "Error: 输入内容无法编码为 UTF-8"
            showAlert = true
            return
        }
        var jsonObj: Any
        do {
            jsonObj = try JSONSerialization.jsonObject(with: data, options: [])
        } catch {
            tips = "Error: JSON 格式错误 - \(error.localizedDescription)"
            showAlert = true
            return
        }
        // 判断是否包含 `dns` 节点,如果包含,则取 `dns` 节点内的内容
        if let dict = jsonObj as? [String: Any], let dnsConfig = dict["dns"] {
            jsonObj = dnsConfig
        }
        // 重新编码为 JSON 字符串
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        do {
            let formattedData = try encoder.encode(JSONAny(jsonObj))
            if let formattedStr = String(data: formattedData, encoding: .utf8) {
                // 触发更新
                AppSettings.shared.dnsJson = formattedStr
                AppSettings.shared.saveSettings()
                tips = "DNS 配置保存成功"
            } else {
                tips = "Error: 格式化后内容无法编码为字符串"
            }
            showAlert = true
        } catch {
            tips = "Error: 保存 DNS 配置失败 - \(error.localizedDescription)"
            showAlert = true
        }
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
