//
//  General.swift
//  V2rayU
//
//  Created by yanue on 2024/12/18.
//

import Foundation
import SwiftUI
import KeyboardShortcuts

struct GeneralView: View {

    @State private var v2rayShortcut: String = ""
    @State private var proxyModeShortcut: String = ""

    @ObservedObject var appState = AppState.shared // 引用单例
    @ObservedObject var themeManager: ThemeManager = ThemeManager()
    @ObservedObject var languageManager: LanguageManager = LanguageManager()


    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Form {
                Section {
                    Toggle("Launch V2rayU at login", isOn: $appState.launchAtLogin)
                    Toggle("Check for updates automatically", isOn: $appState.checkForUpdates)
                    Toggle("Automatically update servers from subscriptions", isOn: $appState.autoUpdateServers)
                    Toggle("Automatically select fastest server", isOn: $appState.selectFastestServer)
                }
                Spacer()

                // 语言选择器
                Picker("Language", selection: $languageManager.selectedLanguage) {
                    ForEach(Language.allCases, id: \.self) { item in
                       Text(item.localized).tag(item.rawValue)
                    }
                }
               .padding()


                Picker("Theme", selection: $themeManager.selectedTheme) {
                    ForEach(Theme.allCases, id: \.self) { item in
                        Text(item.localized).tag(item.rawValue)
                    }
                }
                .pickerStyle(SegmentedPickerStyle()) // 分段选择样式
                .padding()

                Spacer()
                Section(header: Text("Shortcuts")) {
                    HStack {
                        KeyboardShortcuts.Recorder("Toggle V2ray On/Off:", name: .toggleV2rayOnOff)
                    }
                    HStack {
                        KeyboardShortcuts.Recorder("Switch Proxy Mode:", name: .swiftProxyMode)
                    }
                }
                Spacer()
                Section(header: Text("Related file locations")) {
                    Text("~/.V2rayU/")
                    Text("~/Library/Preferences/net.yanue.V2rayU.plist")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }

            HStack {
                Button("Check for Updates...") {
                    // Implement update check logic
                }
                Spacer()
                Button("Feedback...") {
                    // Implement feedback logic
                }
            }
            .padding()
        }
        .frame(width: 500, height: 400)

    }
}
