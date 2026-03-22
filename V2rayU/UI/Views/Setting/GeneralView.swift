//
//  General.swift
//  V2rayU
//
//  Created by yanue on 2024/12/18.
//

import Foundation
import SwiftUI
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let toggleV2rayOnOff = Self("toggleV2rayOnOff")
    static let swiftProxyMode = Self("swiftProxyMode")
}

struct GeneralView: View {

    @State private var v2rayShortcut: String = ""
    @State private var proxyModeShortcut: String = ""

    @StateObject private var languageManager = LanguageManager.shared
    @ObservedObject var settings = AppSettings.shared
    @ObservedObject var state = AppState.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(String(localized: .LaunchAtLogin), isOn: $settings.launchAtLogin)
            Toggle(String(localized: .CheckForUpdateAutomatically), isOn: $settings.checkForUpdates)
            Toggle(String(localized: .AutoUpdateServersFromSubscriptions), isOn: $settings.autoUpdateServers)
            Toggle(String(localized: .AutomaticallySelectFastestServer), isOn: $settings.selectFastestServer)
            Toggle(String(localized: .ShowProxySpeedOnTrayIcon), isOn: $settings.showSpeedOnTray)
            Toggle(String(localized: .ShowLatencyOnTrayIcon), isOn: $settings.showLatencyOnTray)
            Toggle(String(localized: .EnableProxyStatistics), isOn: $settings.enableStat)

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Picker(String(localized: .Language), selection: $languageManager.selectedLanguage) {
                    ForEach(Language.allCases, id: \.self) { item in
                        localized(item.rawValue).tag(item.rawValue)
                    }
                }

                Picker(String(localized: .Theme), selection: $settings.selectedTheme) {
                    ForEach(Theme.allCases, id: \.self) { item in
                        Text(String(localized: item.rawValue)).tag(item)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text(String(localized: .KeyboardShortcuts))
                    .font(.headline)

                HStack {
                    Text(String(localized: .ToggleV2rayOnOff))
                    KeyboardShortcuts.Recorder(String(localized: .ToggleV2rayOnOff), name: .toggleV2rayOnOff)
                }

                HStack {
                    Text(String(localized: .SwitchProxyMode))
                    KeyboardShortcuts.Recorder(String(localized: .SwitchProxyMode), name: .swiftProxyMode)
                }
            }
        }
        .padding()
        .onDisappear {
            AppSettings.shared.saveSettings()
        }
    }
}
