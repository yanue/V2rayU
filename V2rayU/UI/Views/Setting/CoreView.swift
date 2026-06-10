//
//  CoreView.swift
//  V2rayU
//
//  Created by yanue on 2025/7/20.
//

import Foundation
import SwiftUI

enum CoreSettingTab: String, CaseIterable, Identifiable, Hashable {
    case type
    case rules
    case download

    var id: String { rawValue }

    var titleLabel: LanguageLabel {
        switch self {
        case .type: return .CoreTabType
        case .rules: return .CoreTabRules
        case .download: return .CoreTabDownload
        }
    }

    var iconSystemName: String {
        switch self {
        case .type: return "slider.horizontal.3"
        case .rules: return "checklist"
        case .download: return "arrow.down.app"
        }
    }
}

struct CoreView: View {
    @ObservedObject private var vm = CoreViewModel.shared
    @State private var selectedTab: CoreSettingTab = .type

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $selectedTab) {
                ForEach(CoreSettingTab.allCases) { tab in
                    Label(String(localized: tab.titleLabel), systemImage: tab.iconSystemName)
                        .tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .focusable(false)
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 12)

            Divider()

            ZStack {
                switch selectedTab {
                case .type:
                    CoreTypeSettingsView(vm: vm)
                case .rules:
                    CoreCapabilityRulesView(vm: vm)
                case .download:
                    CoreDownloadView(vm: vm)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .onAppear {
            vm.loadCoreVersions()
            // Navigate to requested subtab (from compatibility alert)
            if let requestedTab = NavigationState.shared.coreSettingTab {
                selectedTab = requestedTab
                NavigationState.shared.coreSettingTab = nil
            }
        }
        .onDisappear {
            vm.saveCapabilityRulesBaseURL()
        }
        .onChange(of: NavigationState.shared.coreSettingTab) { _, newValue in
            if let tab = newValue {
                selectedTab = tab
                NavigationState.shared.coreSettingTab = nil
            }
        }
    }
}

// MARK: - 共用小组件

/// 能力规则状态卡片 (供"功能支持规则" tab 使用)
struct CapabilityRulesStatusCard: View {
    let item: CoreViewModel.CapabilityRulesDisplayItem

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.title)
                .font(.subheadline)
                .fontWeight(.semibold)
            HStack(spacing: 16) {
                Label("\(String(localized: .CapabilityRulesSource)): \(item.source)", systemImage: "shippingbox")
                Label("\(String(localized: .CapabilityRulesReviewedVersion)): \(item.reviewedVersion)", systemImage: "checkmark.seal")
                Label("\(String(localized: .CapabilityRulesCapabilities)): \(item.capabilityCount)", systemImage: "list.bullet.rectangle")
            }
            .font(.caption)
            .foregroundColor(.secondary)
            if let path = item.path {
                Text(path)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .textSelection(.enabled)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

/// 通用本地核心文件视图: 显示文件名 + 版本 + 打开目录
struct LocalCoreFileRow: View {
    let title: String
    let directory: String
    let displayText: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "terminal")
                .foregroundColor(.accentColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(displayText)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button(action: openDirectory) {
                Image(systemName: "folder")
            }
            .buttonStyle(.borderless)
            .focusable(false)
            .help(directory)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(Color.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func openDirectory() {
        NSWorkspace.shared.open(URL(fileURLWithPath: directory))
    }
}
