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
func getTextLabel(label: LanguageLabel, labelWidth: CGFloat = 150) -> some View {
    Text(String(localized: label)).frame(width: labelWidth, alignment: .trailing)
}

@MainActor
func getTextFieldWithLabel(label: LanguageLabel, text: Binding<String>, labelWidth: CGFloat = 150) -> some View {
    HStack {
        LocalizedTextLabelView(label:label).frame(width: labelWidth, alignment: .trailing)
        Spacer()
        TextField(String(localized: label), text: text)
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .padding(.leading, 7)
    }
}

@MainActor
func getNumFieldWithLabel(label: LanguageLabel, num: Binding<Int>, labelWidth: CGFloat = 150) -> some View {
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
    case sidebarStatus = "sidebar-status"
    case sidebarConnections = "sidebar-connections"
    case sidebarLogs = "sidebar-logs"
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
func getPickerWithLabel<T: CaseIterable & RawRepresentable & Hashable>(label: LanguageLabel, selection: Binding<T>,ignore: [T] = [], labelWidth: CGFloat = 150) -> some View where T.RawValue == String, T.AllCases: RandomAccessCollection {
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
func getBoolFieldWithLabel(label: LanguageLabel, isOn: Binding<Bool>, labelWidth: CGFloat = 150) -> some View {
    HStack {
        LocalizedTextLabelView(label:label).frame(width: labelWidth, alignment: .trailing)
        Toggle("", isOn: isOn).frame(alignment: .leading)
            .toggleStyle(SwitchToggleStyle(tint: .blue))
            .frame(alignment: .leading)
        Spacer()
    }
}


@MainActor
func getTextEditorWithLabel(label: LanguageLabel, text: Binding<String>, labelWidth: CGFloat = 150) -> some View {
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

// MARK: - 表格铺满样式

extension View {
    /// 表格固定用铺满样式。
    /// 系统默认是两边缩进的圆角行, 只有列宽超出、出现横向滚动时才变成铺满,
    /// 结果列多的页面(路由/订阅)和列少的页面(组合)样子不一样, 切换时能看出来。
    func fullWidthTable() -> some View {
        background(TableStyleProbe())
    }
}

/// 挂在表格背景上: 找到和自己重叠的那个 NSTableView, 改成 .fullWidth
private struct TableStyleProbe: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { Probe() }
    func updateNSView(_ nsView: NSView, context: Context) { (nsView as? Probe)?.apply() }

    final class Probe: NSView {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            apply()
        }

        func apply() {
            // 等表格挂进窗口后再找
            DispatchQueue.main.async { [weak self] in
                guard let self, let root = self.window?.contentView else { return }
                let mine = self.convert(self.bounds, to: nil)
                var tables: [NSTableView] = []
                Self.collect(root, into: &tables)
                // 探针和表格同一个 frame, 取重叠面积最大的, 不会改到别的表格
                guard let table = tables.max(by: { Self.overlap($0, mine) < Self.overlap($1, mine) }),
                      Self.overlap(table, mine) > 0,
                      table.style != .fullWidth else { return }
                table.style = .fullWidth
            }
        }

        static func overlap(_ table: NSTableView, _ rect: NSRect) -> CGFloat {
            guard let sv = table.enclosingScrollView else { return 0 }
            let i = sv.convert(sv.bounds, to: nil).intersection(rect)
            return i.isNull ? 0 : i.width * i.height
        }

        static func collect(_ view: NSView, into out: inout [NSTableView]) {
            if let t = view as? NSTableView { out.append(t) }
            for sub in view.subviews { collect(sub, into: &out) }
        }
    }
}
