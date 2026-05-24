import JavaScriptCore
import SwiftUI

enum DnsCoreTab: String, CaseIterable {
    case xray
    case singbox
}

struct DnsView: View {
    @State private var dnsJson: String = ""
    @State private var tips: String = ""
    @State private var showAlert: Bool = false
    @State private var selectedTab: DnsCoreTab = .xray

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
        .alert(isPresented: $showAlert) {
            Alert(title: Text(String(localized: .Notification)), message: Text(tips), dismissButton: .default(Text(String(localized: .Confirm))))
        }
    }

    private func loadDefault() {
        switch selectedTab {
        case .xray:
            dnsJson = defaultDns
        case .singbox:
            dnsJson = defaultSingboxDns
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

        // unwrap {"dns": {...}} for xray
        if selectedTab == .xray, let dict = jsonObj as? [String: Any], let dnsConfig = dict["dns"] {
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
        let confUrl = getConfigUrl()
        if let url = URL(string: confUrl) {
            NSWorkspace.shared.open(url)
        }
    }
}
