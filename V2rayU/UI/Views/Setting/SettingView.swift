//
//  Setting.swift
//  V2rayU
//
//  Created by yanue on 2024/12/18.
//

import SwiftUI

struct SettingView: View {
    @ObservedObject var appState = AppState.shared // 引用单例

    // Enum for Tabs
    enum SettingTab {
        case general
        case shortcuts
        case advance
        case dns
        case pac
        case core
    }

    var body: some View {
        VStack {
            PageHeader(
                icon: "gear",
                title: String(localized: .Settings),
                subtitle: String(localized: .SettingsSubHead)
            )

            // Segmented Picker (Tabs)
            Picker("", selection: $appState.settingTab) {
                localized(.General).tag(SettingTab.general)
                localized(.Advanced).tag(SettingTab.advance)
                localized(.Shortcuts).tag(SettingTab.shortcuts)
                localized(.DNS).tag(SettingTab.dns)
                localized(.PAC).tag(SettingTab.pac)
                localized(.Core).tag(SettingTab.core)
            }
            .pickerStyle(.segmented)
            .focusable(false)
            .padding(.vertical, 12)

            VStack {
                // Content based on Selected Tab
                switch appState.settingTab {
                case .general:
                    GeneralView()
                case .advance:
                    AdvanceView()
                case .shortcuts:
                    ShortcutsView()
                case .dns:
                    DnsView()
                case .pac:
                    PacView()
                case .core:
                    CoreView()
                }
            }
            .background(.ultraThinMaterial)
            .border(Color.gray.opacity(0.1), width: 1)
            .cornerRadius(8)
        }
        .padding(8)
    }
}
