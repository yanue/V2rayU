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
    @ObservedObject var settings = AppSettings()

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

            TextEditor(text: $dnsJson)
                .font(.system(.body, design: .monospaced))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                )

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
        .padding()
        .onAppear { loadDnsServers() }
        .alert(isPresented: $showAlert) {
            Alert(title: Text(String(localized: .Notification)), message: Text(tips), dismissButton: .default(Text(String(localized: .Confirm))) )
        }
    }

    private func loadDnsServers() {
        dnsJson = AppSettings.shared.dnsJson
    }

    private func saveDnsServers() {
        var str = dnsJson.trimmingCharacters(in: .whitespacesAndNewlines)

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

        if let dict = jsonObj as? [String: Any], let dnsConfig = dict["dns"] {
            jsonObj = dnsConfig
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]

        do {
            let formattedData = try encoder.encode(AnyCodable(jsonObj))

            if let formattedStr = String(data: formattedData, encoding: .utf8) {
                AppSettings.shared.dnsJson = formattedStr
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
