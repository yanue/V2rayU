import JavaScriptCore
import SwiftUI

enum DnsCoreTab: String, CaseIterable {
    case xray
    case singbox
}

struct DnsView: View {
    @StateObject private var settings = AppSettings.shared
    @State private var dnsJson: String = ""
    @State private var tips: String = ""
    @State private var showAlert: Bool = false
    @State private var selectedTab: DnsCoreTab = .xray
    private let labelWidth: CGFloat = 170

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            dnsBasicSettings

            Divider()

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
                .focusable(false)
                Button(action: { goHelp(self) }) {
                    Label(String(localized: .Help), systemImage: "questionmark.circle")
                }
                .buttonStyle(.bordered)
                .focusable(false)
            }

            Picker("", selection: $selectedTab) {
                localized(.DnsXray).tag(DnsCoreTab.xray)
                localized(.DnsSingbox).tag(DnsCoreTab.singbox)
            }
            .pickerStyle(.segmented)
            .focusable(false)

            TextEditor(text: $dnsJson)
                .font(.system(.body, design: .monospaced))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                )

            HStack {
                Button(action: { dnsJson = "{}" }) {
                    Label(String(localized: .DnsClear), systemImage: "trash")
                }
                .buttonStyle(.bordered)
                .focusable(false)

                Button(action: { loadDefault() }) {
                    Label(String(localized: .DnsDefault), systemImage: "checkmark.circle")
                }
                .buttonStyle(.bordered)
                .focusable(false)

                Spacer()

                if !tips.isEmpty {
                    Text(tips)
                        .foregroundColor(tips.hasPrefix("Error") ? .red : .green)
                        .font(.callout)
                        .padding(.horizontal, 20)
                }

                Spacer()

                Button(action: { saveDns() }) {
                    Label(String(localized: .Save), systemImage: "tray.and.arrow.down")
                }
                .buttonStyle(.borderedProminent)
                .focusable(false)
            }
        }
        .padding()
        .onAppear { loadDns() }
        .onChange(of: selectedTab) { _, _ in loadDns() }
        .onDisappear { persistDnsBasicSettings() }
        .alert(isPresented: $showAlert) {
            Alert(title: Text(String(localized: .Notification)), message: Text(tips), dismissButton: .default(Text(String(localized: .Confirm))))
        }
    }

    private func loadDefault() {
        persistDnsBasicSettings()
        switch selectedTab {
        case .xray:
            dnsJson = buildDefaultDnsSetting(directDns: settings.dnsDirect, remoteDns: settings.dnsRemote, bootstrapDns: settings.dnsBootstrap)
        case .singbox:
            dnsJson = buildDefaultSingboxDnsSetting(directDns: settings.dnsDirect, remoteDns: settings.dnsRemote, bootstrapDns: settings.dnsBootstrap)
        }
    }

    private func persistDnsBasicSettings() {
        saveDnsBasicSettings(
            direct: settings.dnsDirect,
            remote: settings.dnsRemote,
            bootstrap: settings.dnsBootstrap,
            directStrategy: settings.dnsDirectStrategy,
            proxyStrategy: settings.dnsProxyStrategy
        )
    }

    private var dnsBasicSettings: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("DNS 基础设置")
                .font(.headline)
                .foregroundColor(.secondary)

            getPlainTextFieldWithLabel(label: "直连 DNS", text: $settings.dnsDirect, labelWidth: labelWidth)
            getPlainTextFieldWithLabel(label: "远程 DNS", text: $settings.dnsRemote, labelWidth: labelWidth)
            getPlainTextFieldWithLabel(label: "Bootstrap DNS", text: $settings.dnsBootstrap, labelWidth: labelWidth)

            HStack(spacing: 12) {
                Text("直连目标解析策略")
                    .frame(width: labelWidth, alignment: .leading)
                Picker("", selection: $settings.dnsDirectStrategy) {
                    Text("Default").tag("Default")
                    Text("AsIs").tag("AsIs")
                    Text("UseIP").tag("UseIP")
                    Text("UseIPv4").tag("UseIPv4")
                    Text("UseIPv6").tag("UseIPv6")
                }
                .frame(width: 180)
                .focusable(false)

                Text("代理目标解析策略")
                    .frame(width: labelWidth, alignment: .leading)
                Picker("", selection: $settings.dnsProxyStrategy) {
                    Text("Default").tag("Default")
                    Text("AsIs").tag("AsIs")
                    Text("UseIP").tag("UseIP")
                    Text("UseIPv4").tag("UseIPv4")
                    Text("UseIPv6").tag("UseIPv6")
                }
                .frame(width: 180)
                .focusable(false)
                Spacer()
            }

            Text("说明：这些基础选项会用于生成默认 v2ray/sing-box DNS；如果下方保存了自定义 DNS JSON，则自定义 JSON 优先。修改基础选项后可点击“默认”重新生成当前标签页的 DNS JSON。")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private func getPlainTextFieldWithLabel(label: String, text: Binding<String>, labelWidth: CGFloat) -> some View {
        HStack {
            Text(label)
                .frame(width: labelWidth, alignment: .leading)
            TextField(label, text: text)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            Spacer()
        }
    }

    private func loadDns() {
        switch selectedTab {
        case .xray:
            dnsJson = AppSettings.shared.dnsJson
        case .singbox:
            dnsJson = AppSettings.shared.dnsJsonSingbox
        }
    }

    private func saveDns() {
        persistDnsBasicSettings()
        let str = dnsJson.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = str.data(using: .utf8) else {
            tips = String(localized: .DnsInvalidUTF8)
            showAlert = true
            return
        }

        var jsonObj: Any

        do {
            jsonObj = try JSONSerialization.jsonObject(with: data, options: [])
        } catch {
            tips = "\(String(localized: .DnsJSONFormatError)): \(error.localizedDescription)"
            showAlert = true
            return
        }

        // unwrap {"dns": {...}} for xray/sing-box full config paste
        if let dict = jsonObj as? [String: Any], let dnsConfig = dict["dns"] {
            jsonObj = dnsConfig
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]

        do {
            let formattedData = try encoder.encode(AnyCodable(jsonObj))

            if let formattedStr = String(data: formattedData, encoding: .utf8) {
                switch selectedTab {
                case .xray:
                    AppSettings.shared.dnsJson = formattedStr
                case .singbox:
                    AppSettings.shared.dnsJsonSingbox = formattedStr
                }
                AppSettings.shared.saveSettings()
                tips = String(localized: .DnsSaveSuccess)
            } else {
                tips = String(localized: .DnsFormatEncodingFail)
            }

            showAlert = true

        } catch {
            tips = "\(String(localized: .DnsSaveFail)):\(error.localizedDescription)"
            showAlert = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            self.tips = ""
        }
    }

    func goHelp(_ sender: Any) {
        let url: URL
        switch selectedTab {
        case .xray:
            url = URL(string: "https://xtls.github.io/config/dns.html#dnsobject")!
        case .singbox:
            url = URL(string: "https://sing-box.sagernet.org/configuration/dns")!
        }
        NSWorkspace.shared.open(url)
    }

    func goViewConfig(_ sender: Any) {
        let confUrl = getLocalConfigUrl()
        if let url = URL(string: confUrl) {
            NSWorkspace.shared.open(url)
        }
    }
}
