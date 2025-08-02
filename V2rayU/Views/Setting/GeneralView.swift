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

    @ObservedObject var themeManager: ThemeManager = ThemeManager()
    @ObservedObject var languageManager: LanguageManager = LanguageManager()
    @ObservedObject var settings = AppSettings.shared // 引用单例

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Form {
                Section {
                    Toggle("Launch V2rayU at login", isOn: $settings.launchAtLogin)
                    Toggle("Check for updates automatically", isOn: $settings.checkForUpdates)
                    Toggle("Automatically update servers from subscriptions", isOn: $settings.autoUpdateServers)
                    Toggle("Automatically select fastest server", isOn: $settings.selectFastestServer)
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
              
            }
        }
        .frame(width: 500, height: 400)
        .onDisappear {
            AppSettings.shared.saveSettings()
        }
    }
}
