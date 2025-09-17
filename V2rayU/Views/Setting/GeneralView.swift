//
//  General.swift
//  V2rayU
//
//  Created by yanue on 2024/12/18.
//

import Foundation
import SwiftUI
import KeyboardShortcuts

// Placeholder Views for Content
extension KeyboardShortcuts.Name {
    static let toggleV2rayOnOff = Self("toggleV2rayOnOff")
    static let swiftProxyMode = Self("swiftProxyMode")
}

struct GeneralView: View {

    @State private var v2rayShortcut: String = ""
    @State private var proxyModeShortcut: String = ""

    @StateObject private var languageManager = LanguageManager.shared
    @ObservedObject var settings = AppSettings.shared // 引用单例
    @ObservedObject var state = AppState.shared // 引用单例

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Form {
                Section {
                    Toggle(String(localized: .LaunchAtLogin), isOn: $settings.launchAtLogin)
                    Toggle(String(localized: .CheckForUpdateAutomatically), isOn: $settings.checkForUpdates)
                    Toggle(String(localized: .AutoUpdateServersFromSubscriptions), isOn: $settings.autoUpdateServers)
                    Toggle(String(localized: .AutomaticallySelectFastestServer), isOn: $settings.selectFastestServer)
                    Toggle(String(localized: .ShowProxySpeedOnTrayIcon), isOn: $settings.showSpeedOnTray)
                    Toggle(String(localized: .ShowLatencyOnTrayIcon), isOn: $settings.showLatencyOnTray)
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
                    
                Picker(String(localized: .Theme), selection: $settings.selectedTheme) {
                    ForEach(Theme.allCases, id: \.self) { item in
                        localized(item.rawValue).tag(item.rawValue)
                    }
                }
                .pickerStyle(SegmentedPickerStyle()) // 分段选择样式
                .padding()

                Spacer()
                Section(header: localized(.KeyboardShortcuts)) {
                    HStack {
                        KeyboardShortcuts.Recorder(String(localized: .ToggleV2rayOnOff), name: .toggleV2rayOnOff)
                    }
                    HStack {
                        KeyboardShortcuts.Recorder(String(localized: .SwitchProxyMode), name: .swiftProxyMode)
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
