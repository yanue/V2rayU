//
//  Setting.swift
//  V2rayU
//
//  Created by yanue on 2024/12/18.
//

import KeyboardShortcuts
import SwiftUI


// Placeholder Views for Content
extension KeyboardShortcuts.Name {
    static let toggleV2rayOnOff = Self("toggleV2rayOnOff")
    static let swiftProxyMode = Self("swiftProxyMode")
}

struct SettingView: View {
    @State private var selectedTab: SettingTab = .general

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
                    Text("Settings")
                        .font(.title)
                        .fontWeight(.bold)
                    Text("aaaaas")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                
            }

            // Segmented Picker (Tabs)
            Picker("", selection: $selectedTab) {
                Text("General").tag(SettingTab.general)
                Text("Advance").tag(SettingTab.advance)
                Text("DNS").tag(SettingTab.dns)
                Text("PAC").tag(SettingTab.pac)
                Text("Core").tag(SettingTab.core)
            }
            .pickerStyle(.segmented)
            
            Spacer(minLength: 20) 
            // Content based on Selected Tab
            HStack{
                VStack {
                    switch selectedTab {
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
                }.padding() // 1. 内边距
                    .background() // 2. 然后背景
                    .clipShape(RoundedRectangle(cornerRadius: 8)) // 3. 内圆角
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                            .shadow(color: Color.primary.opacity(0.1), radius: 1, x: 0, y: 1)
                    ) // 4. 添加边框和阴影
            }
        }
        .padding(8)
    }
}

struct TrafficView: View {
    var body: some View {
        Text("Traffic Data")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.green.opacity(0.1))
            .cornerRadius(8)
    }
}

struct InterfacesView: View {
    var body: some View {
        Text("Interfaces Data")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.orange.opacity(0.1))
            .cornerRadius(8)
    }
}

struct SettingView_Previews: PreviewProvider {
    static var previews: some View {
        SettingView()
    }
}
