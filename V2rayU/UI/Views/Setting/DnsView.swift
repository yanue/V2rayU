import SwiftUI

enum DnsCoreTab: String, CaseIterable, Identifiable, Hashable {
    case basic
    case xray
    case singbox

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .basic: return LocalizedStringKey(LanguageLabel.DnsBasic.rawValue)
        case .xray: return "DnsXray"
        case .singbox: return "DnsSingbox"
        }
    }

    var iconSystemName: String {
        switch self {
        case .basic: return "slider.horizontal.3"
        case .xray: return "network"
        case .singbox: return "shippingbox"
        }
    }
}

struct DnsView: View {
    @StateObject private var settings = AppSettings.shared
    @State private var dnsJson: String = ""
    @State private var tips: String = ""
    @State private var showAlert: Bool = false
    @State private var selectedTab: DnsCoreTab = .basic
    private let labelWidth: CGFloat = 170

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $selectedTab) {
                ForEach(DnsCoreTab.allCases) { tab in
                    Label(tab.title, systemImage: tab.iconSystemName)
                        .tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .focusable(false)
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 12)

            Divider()

            ZStack(alignment: .topLeading) {
                switch selectedTab {
                case .basic:
                    dnsBasicSettings
                case .xray, .singbox:
                    dnsJsonEditor
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .onAppear { loadDns() }
        .onChange(of: selectedTab) { oldTab, newTab in
            if oldTab == .basic {
                normalizeDnsBasicSettings()
                AppSettings.shared.saveSettings()
            }
            if newTab != .basic {
                loadDns()
            }
        }
        .onDisappear {
            normalizeDnsBasicSettings()
            AppSettings.shared.saveSettings()
        }
        .alert(isPresented: $showAlert) {
            Alert(title: Text(String(localized: .Notification)), message: Text(tips), dismissButton: .default(Text(String(localized: .Confirm))))
        }
    }

    private var dnsBasicSettings: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(String(localized: .DnsBasicSettings))
                    .font(.headline)
                    .foregroundColor(.secondary)

                getPlainTextFieldWithLabel(label: String(localized: .DnsDirect), text: $settings.dnsDirect, labelWidth: labelWidth)
                getPlainTextFieldWithLabel(label: String(localized: .DnsRemote), text: $settings.dnsRemote, labelWidth: labelWidth)
                getPlainTextFieldWithLabel(label: "Bootstrap DNS", text: $settings.dnsBootstrap, labelWidth: labelWidth)

                HStack() {
                    Text(String(localized: .DnsDirectStrategy))
                        .frame(width: labelWidth, alignment: .leading)
                    dnsStrategyPicker(selection: $settings.dnsDirectStrategy)

                }
                
                HStack() {
                    Text(String(localized: .DnsProxyStrategy))
                        .frame(width: labelWidth, alignment: .leading)
                    dnsStrategyPicker(selection: $settings.dnsProxyStrategy)
                }

                Text(String(localized: .DnsBasicSettingsTip))
                    .font(.caption)
                    .foregroundColor(.secondary)

                Divider()

                HStack {
                    Button(String(localized: .Save)) {
                        normalizeDnsBasicSettings()
                        AppSettings.shared.saveSettings()
                        tips = String(localized: .DnsSaveSuccess)
                        showAlert = true
                    }
                    .buttonStyle(.borderedProminent)
                    .focusable(false)

                    if !tips.isEmpty {
                        Text(tips)
                            .foregroundColor(tips.hasPrefix("Error") ? .red : .green)
                            .font(.callout)
                            .padding(.horizontal, 20)
                    }
                    Spacer()
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var dnsJsonEditor: some View {
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
                .focusable(false)
                Button(action: { goHelp(self) }) {
                    Label(String(localized: .Help), systemImage: "questionmark.circle")
                }
                .buttonStyle(.bordered)
                .focusable(false)
            }

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
                Text("( {} = 使用系统 DNS )")
                    .font(.caption)
                    .foregroundColor(.secondary)

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
    }

    private func dnsStrategyPicker(selection: Binding<String>) -> some View {
        Picker("", selection: selection) {
            Text("Default").tag("Default")
            Text("AsIs").tag("AsIs")
            Text("UseIP").tag("UseIP")
            Text("UseIPv4").tag("UseIPv4")
            Text("UseIPv6").tag("UseIPv6")
        }
        .focusable(false)
    }

    private func loadDefault() {
        normalizeDnsBasicSettings()
        switch selectedTab {
        case .basic:
            break
        case .xray:
            dnsJson = buildDefaultDnsSetting(directDns: settings.dnsDirect, remoteDns: settings.dnsRemote, bootstrapDns: settings.dnsBootstrap)
        case .singbox:
            dnsJson = buildDefaultSingboxDnsSetting(directDns: settings.dnsDirect, remoteDns: settings.dnsRemote, bootstrapDns: settings.dnsBootstrap)
        }
    }

    private func normalizeDnsBasicSettings() {
        settings.dnsDirect = normalizedText(settings.dnsDirect, defaultValue: defaultDirectDns)
        settings.dnsRemote = normalizedText(settings.dnsRemote, defaultValue: defaultRemoteDns)
        settings.dnsBootstrap = normalizedText(settings.dnsBootstrap, defaultValue: defaultBootstrapDns)
        settings.dnsDirectStrategy = normalizeDnsTargetStrategy(settings.dnsDirectStrategy)
        settings.dnsProxyStrategy = normalizeDnsTargetStrategy(settings.dnsProxyStrategy)
    }

    private func normalizedText(_ value: String, defaultValue: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? defaultValue : trimmed
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
        case .basic:
            break
        case .xray:
            dnsJson = AppSettings.shared.dnsJson
        case .singbox:
            dnsJson = AppSettings.shared.dnsJsonSingbox
        }
    }

    @MainActor
    private func saveDns() {
        normalizeDnsBasicSettings()
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
                case .basic:
                    break
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
        case .basic, .xray:
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
