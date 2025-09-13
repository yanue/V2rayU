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
        case advance
        case dns
        case pac
        case core
    }

    var body: some View {
        VStack() {
            HStack {
                Image(systemName: "gear")
                    .resizable()
                    .frame(width: 28, height: 28)
                    .foregroundColor(.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    localized(.Settings)
                        .font(.title)
                        .fontWeight(.bold)
                    localized(.SettingsSubHead)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                
            }.padding(.bottom, 10)
            
            // Segmented Picker (Tabs)
            Picker("", selection: $appState.settingTab) {
                localized(.General).tag(SettingTab.general)
                localized(.Advanced).tag(SettingTab.advance)
                localized(.DNS).tag(SettingTab.dns)
                localized(.PAC).tag(SettingTab.pac)
                localized(.Core).tag(SettingTab.core)
            }
            .pickerStyle(.segmented)
            
            Spacer(minLength: 20) 
            // Content based on Selected Tab
            HStack{
                VStack {
                    switch appState.settingTab {
                    case .general:
                        GeneralView()
                    case .advance:
                        AdvanceView()
                    case .dns:
                        DnsView()
                    case .pac:
                        PacView()
                    case .core:
                        CoreView()
                    }
                }
            }
        }
    }
}
