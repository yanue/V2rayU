//
//  General.swift
//  V2rayU
//
//  Created by yanue on 2024/12/18.
//

import Foundation
import SwiftUI
import KeyboardShortcuts

enum Theme: String, CaseIterable {
    case System = "Follow System"
    case Light = "Light"
    case Dark = "Dark"
    var localized: String {
        return NSLocalizedString(rawValue, comment: "")
    }
}

enum Language: String, CaseIterable {
    case system = "System Default"  // 跟随系统语言
    case en = "English"
    case zhHans = "Simplified Chinese" // 简体中文
    case zhHant = "Traditional Chinese" // 繁体中文
    
    var localeIdentifier: String {
        switch self {
        case .en:
            return "en"
        case .zhHans:
            return "zh-Hans"
        case .zhHant:
            return "zh-Hant"
        case .system:
            return Locale.preferredLanguages.first ?? "en"  // 默认跟随系统语言
        }
    }
    
    var localized: String {
        return NSLocalizedString(self.rawValue, comment: "")
    }
}

struct GeneralView: View {
    @State private var launchAtLogin = true
    @State private var checkForUpdates = false
    @State private var autoUpdateServers = true
    @State private var selectFastestServer = false
    @State private var v2rayShortcut: String = ""
    @State private var proxyModeShortcut: String = ""
    @State private var theme = Theme.System // 默认设置为浅色模式
    @AppStorage("selectedLanguage") private var language: String = Language.system.rawValue

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Form {
                Section {
                    Toggle("Launch V2rayU at login", isOn: $launchAtLogin)
                    Toggle("Check for updates automatically", isOn: $checkForUpdates)
                    Toggle("Automatically update servers from subscriptions", isOn: $autoUpdateServers)
                    Toggle("Automatically select fastest server", isOn: $selectFastestServer)
                }
                Spacer()
                // 语言选择器
               Picker("Language", selection: $language) {
                   ForEach(Language.allCases, id: \.self) { item in
                       Text(item.localized).tag(item.rawValue)
                   }
               }
               .padding()
               .onChange(of: language) {
                   setLanguage(language)
               }
               
               
                Picker("Theme", selection: $theme) {
                    ForEach(Theme.allCases, id: \.self) { item in
                        Text(item.localized).tag(item)
                    }
                }
                .pickerStyle(SegmentedPickerStyle()) // 分段选择样式
                .padding(0)
                .onChange(of: theme) {
                    // 在这里确保外观变更
                    setAppearance(for: theme)
                }

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
                Section(header: Text("Related file locations")) {
                    Text("~/.V2rayU/")
                    Text("~/Library/Preferences/net.yanue.V2rayU.plist")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }

            HStack {
                Button("Check for Updates...") {
                    // Implement update check logic
                }
                Spacer()
                Button("Feedback...") {
                    // Implement feedback logic
                }
            }
            .padding()
        }
        .frame(width: 500, height: 400)
    }

    // 更新应用外观的方法
    private func setAppearance(for theme: Theme) {
        print("setAppearance", theme)
        if #available(macOS 10.14, *) {
            switch theme {
            case .Light:
                // 浅色模式
                NSApp.appearance = NSAppearance(named: .aqua)
            case .Dark:
                // 深色模式
                NSApp.appearance = NSAppearance(named: .darkAqua)
            default:
                // 系统默认模式
                NSApp.appearance = nil
            }
        }
    }
    
   // 设置语言
    private func setLanguage(_ languageRawValue: String) {
        if let language = Language(rawValue: languageRawValue) {
            if language == .system {
                // 如果选择系统语言，直接使用系统语言
                let systemLanguage = Locale.preferredLanguages.first ?? "en"
                UserDefaults.standard.set([systemLanguage], forKey: "AppleLanguages")
                UserDefaults.standard.synchronize()
            } else {
                // 设置其他语言
                let locale = Locale(identifier: language.localeIdentifier)
                UserDefaults.standard.set([locale.identifier], forKey: "AppleLanguages")
                UserDefaults.standard.synchronize()
            }
        }
   }
}
