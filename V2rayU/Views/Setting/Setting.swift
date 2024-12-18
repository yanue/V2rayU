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
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header Section
            Text("Setting")
                .font(.title)
                .fontWeight(.bold)

            // Segmented Picker (Tabs)
            Picker("", selection: $selectedTab) {
                Text("General").tag(SettingTab.general)
                Text("Advance").tag(SettingTab.advance)
            }
            .pickerStyle(.segmented).padding(0)

            // Content based on Selected Tab
            VStack {
                switch selectedTab {
                case .general:
                    GeneralView()
                case .advance:
                    TrafficView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding()
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
