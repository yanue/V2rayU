//
//  General.swift
//  V2rayU
//
//  Created by yanue on 2024/12/18.
//

import Foundation
import SwiftUI

struct GeneralView: View {

    @StateObject private var languageManager = LanguageManager.shared
    @ObservedObject var settings = AppSettings.shared
    @ObservedObject var state = AppState.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                generalSection
                languageSection
                Spacer()
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onDisappear {
            AppSettings.shared.saveSettings()
        }
    }

    private var generalSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: .General))
                .font(.headline)
                .foregroundColor(.secondary)

            Toggle(String(localized: .LaunchAtLogin), isOn: $settings.launchAtLogin)
            Toggle(String(localized: .CheckForUpdateAutomatically), isOn: $settings.checkForUpdates)
            Toggle(String(localized: .AutoUpdateServersFromSubscriptions), isOn: $settings.autoUpdateServers)
            Toggle(String(localized: .AutomaticallySelectFastestServer), isOn: $settings.selectFastestServer)
            Toggle(String(localized: .ShowProxySpeedOnTrayIcon), isOn: $settings.showSpeedOnTray)
            Toggle(String(localized: .ShowLatencyOnTrayIcon), isOn: $settings.showLatencyOnTray)
            Toggle(String(localized: .EnableProxyStatistics), isOn: $settings.enableStat)
        }
    }

    private var languageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: .Language) + " & " + String(localized: .Theme))
                .font(.headline)
                .foregroundColor(.secondary)

            Picker(String(localized: .Language), selection: $languageManager.selectedLanguage) {
                ForEach(Language.allCases, id: \.self) { item in
                    localized(item.rawValue).tag(item.rawValue)
                }
            }

            Picker(String(localized: .Theme), selection: $settings.selectedTheme) {
                ForEach(Theme.allCases, id: \.self) { item in
                    localized(item.rawValue).tag(item.rawValue)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
        }
    }
}
