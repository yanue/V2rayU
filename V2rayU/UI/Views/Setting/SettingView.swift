//
//  Setting.swift
//  V2rayU
//
//  Created by yanue on 2024/12/18.
//

import SwiftUI

struct SettingView: View {
    @StateObject private var navigationState = NavigationState.shared

    var body: some View {
        VStack {
            PageHeader(
                icon: "gear",
                title: String(localized: .Settings),
                subtitle: String(localized: .SettingsSubHead)
            )

            // Segmented Picker (Tabs)
            Picker("", selection: $navigationState.settingTab) {
                localized(.General).tag(SettingsTab.general)
                localized(.Advanced).tag(SettingsTab.advance)
                localized(.Tun).tag(SettingsTab.tun)
                localized(.Shortcuts).tag(SettingsTab.shortcuts)
                localized(.DNS).tag(SettingsTab.dns)
                localized(.PAC).tag(SettingsTab.pac)
                localized(.Core).tag(SettingsTab.core)
            }
            .pickerStyle(.segmented)
            .focusable(false)
            .padding(.vertical, 12)

            VStack {
                // Content based on Selected Tab
                switch navigationState.settingTab {
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
                case .tun:
                    TunView()
                }
            }
            .background(.ultraThinMaterial)
            .border(Color.gray.opacity(0.1), width: 1)
            .cornerRadius(8)
        }
        .padding(8)
    }
}
