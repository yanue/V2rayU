//
//  Common.swift
//  V2rayU
//
//  Created by yanue on 2024/11/30.
//

import SwiftUI

// 公共的 getTextField 函数，接受 name 和绑定的文本
@MainActor
func getTextField(name: LanguageLabel, text: Binding<String>) -> some View {
    TextField(String(localized: name), text: text)
        .textFieldStyle(RoundedBorderTextFieldStyle())
        .padding(.leading, 8)
}

// 公共的 getTextField 函数，接受 name
@MainActor
func getTextLabel(label: LanguageLabel, labelWidth: CGFloat = 100) -> some View {
    Text(String(localized: label)).frame(width: labelWidth, alignment: .trailing)
}

@MainActor
func getTextFieldWithLabel(label: LanguageLabel, text: Binding<String>, labelWidth: CGFloat = 100) -> some View {
    HStack {
        LocalizedTextLabelView(label:label).frame(width: labelWidth, alignment: .trailing)
        Spacer()
        TextField(String(localized: label), text: text)
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .padding(.leading, 7)
    }
}

@MainActor
func getNumFieldWithLabel(label: LanguageLabel, num: Binding<Int>, labelWidth: CGFloat = 100) -> some View {
        HStack {
            LocalizedTextLabelView(label:label).frame(width: labelWidth, alignment: .trailing)
            Spacer()
            TextField(String(localized: label), value: num, formatter: NumberFormatter())
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.leading, 7)
    }
}

enum ViewAccessibilityIdentifier: String {
    case sidebarSubscription = "sidebar-subscription"
    case sidebarServer = "sidebar-server"
    case sidebarCombination = "sidebar-combination"
    case sidebarRouting = "sidebar-routing"
    case sidebarCore = "sidebar-core"
    case sidebarSetting = "sidebar-setting"
    case sidebarDiagnostic = "sidebar-diagnostic"
    case sidebarAbout = "sidebar-about"

    case profileAddButton = "profile-add"
    case profileImportButton = "profile-import"
    case profileMoreButton = "profile-more"
    case profileTable = "profile-table"
    case profileSearchField = "profile-search"
    case profileGroupPicker = "profile-group-picker"

    case settingTabGeneral = "setting-tab-general"
    case settingTabAdvanced = "setting-tab-advanced"
    case settingTabTun = "setting-tab-tun"
    case settingTabShortcuts = "setting-tab-shortcuts"
    case settingTabDns = "setting-tab-dns"
    case settingTabPac = "setting-tab-pac"
    case settingTabCore = "setting-tab-core"

    case toggleCoreMenu = "toggle-core"
    case proxyModeMenu = "proxy-mode"
}

@MainActor
func getPickerWithLabel<T: CaseIterable & RawRepresentable & Hashable>(label: LanguageLabel, selection: Binding<T>,ignore: [T] = [], labelWidth: CGFloat = 100) -> some View where T.RawValue == String, T.AllCases: RandomAccessCollection {
    HStack {
        LocalizedTextLabelView(label:label).frame(width: labelWidth, alignment: .trailing)
        Spacer()
        Picker("", selection: selection) {
            ForEach(T.allCases.filter { !ignore.contains($0) }, id: \.self) { pick in
                Text(pick.rawValue)
            }
        }
        .pickerStyle(MenuPickerStyle())  // 可以根据需要修改样式
    }
}

@MainActor
func getBoolFieldWithLabel(label: LanguageLabel, isOn: Binding<Bool>, labelWidth: CGFloat = 100) -> some View {
    HStack {
        LocalizedTextLabelView(label:label).frame(width: labelWidth, alignment: .trailing)
        Toggle("", isOn: isOn).frame(alignment: .leading)
            .toggleStyle(SwitchToggleStyle(tint: .blue))
            .frame(alignment: .leading)
        Spacer()
    }
}


@MainActor
func getTextEditorWithLabel(label: LanguageLabel, text: Binding<String>, labelWidth: CGFloat = 100) -> some View {
    HStack {
        LocalizedTextLabelView(label:label).frame(width: labelWidth, alignment: .trailing)
        Spacer()

        TextEditor(text: text)
            .frame(height: 60)
            .background(Color(NSColor.textBackgroundColor))
            .padding(.all, 4)
            .border(Color(NSColor.separatorColor), width: 1)
            .cornerRadius(4)
            .padding(.leading, 7)
            // 设置行间距
            .lineSpacing(4)
    }
}

struct PageHeader<Actions: View>: View {
    let icon: String
    let title: String
    let subtitle: String
    @ViewBuilder let actions: () -> Actions

    init(icon: String, title: String, subtitle: String, @ViewBuilder actions: @escaping () -> Actions = { EmptyView() }) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.actions = actions
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: icon)
                .resizable()
                .frame(width: 28, height: 28)
                .foregroundColor(.accentColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.title2)
                    .fontWeight(.bold)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            actions()
        }
        .padding(.vertical, 8)
    }
}

struct RunDiagnosticButton: View {
    @Binding var checking: Bool
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                ZStack {
                    if checking {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(0.5)
                            .frame(width: 16, height: 16)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .frame(width: 16, height: 16)
                
                Text(String(localized: .RunDiagnostic))
            }
        }
        .focusable(false)
    }
}
