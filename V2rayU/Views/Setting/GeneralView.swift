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
    @StateObject private var languageManager = LanguageManager.shared
    @ObservedObject var settings = AppSettings.shared // 引用单例

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Form {
                Section {
                    Toggle(String(localized: .LaunchAtLogin), isOn: $settings.launchAtLogin)
                    Toggle(String(localized: .CheckForUpdateAutomatically), isOn: $settings.checkForUpdates)
                    Toggle(String(localized: .AutoUpdateServersFromSubscriptions), isOn: $settings.autoUpdateServers)
                    Toggle(String(localized: .AutomaticallySelectFastestServer), isOn: $settings.selectFastestServer)
                    Toggle(String(localized: .ShowProxySpeedOnTrayIcon), isOn: $settings.showSpeedOnTray)
                    Toggle(String(localized: .EnableProxyStatistics), isOn: $settings.enableStat)
                }
                Spacer()

                // 语言选择器
                Picker(String(localized: .Language), selection: $languageManager.selectedLanguage) {
                    ForEach(Language.allCases, id: \.self) { item in
                        localized(item.rawValue).tag(item.rawValue)
                    }
                }
               .padding()

                localized(.Language)
                localized(.Theme)
                    
                Picker(String(localized: .Theme), selection: $themeManager.selectedTheme) {
                    ForEach(Theme.allCases, id: \.self) { item in
                        localized(item.rawValue).tag(item.rawValue)
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
