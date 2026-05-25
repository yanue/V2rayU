//
//  CoreCapabilityRulesView.swift
//  V2rayU
//
//  Created by yanue on 2026/5/25.
//

import SwiftUI

/// Tab 2: 功能支持规则 — xray / sing-box 列表明细
struct CoreCapabilityRulesView: View {
    @ObservedObject var vm: CoreViewModel

    @State private var coreTab: CoreUpdateKind = .xray
    @State private var searchText: String = ""
    @State private var kindFilter: XrayCapabilityKind? = nil
    @State private var selectedKey: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            sourceConfigSection

            Divider()


            filterBar
            
            capabilitiesTable

            if let key = selectedKey, let cap = allCapabilities.first(where: { $0.key == key }) {
                Divider()
                capabilityDetailView(cap)
            }
        }
        .padding(16)
        .onChange(of: coreTab) { _,_ in
            selectedKey = nil
            kindFilter = nil
            searchText = ""
        }
    }

    // MARK: - 头部

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "checklist")
                .font(.title3)
                .foregroundColor(.accentColor)
                .frame(width: 24, height: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: .CapabilityRulesSettingsTitle))
                    .font(.headline)
                Text(String(localized: .CapabilityRulesRemoteBaseURLHint))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - 远程基地址 + 更新按钮

    private var sourceConfigSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: .CapabilityRulesRemoteBaseURL))
                .font(.subheadline)
                .foregroundColor(.secondary)

            HStack(spacing: 8) {
                TextField(defaultCapabilityRulesBaseURL, text: $vm.capabilityRulesBaseURL)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { vm.saveCapabilityRulesBaseURL() }

                Button(action: { vm.updateCapabilityRules() }) {
                    Label(String(localized: .UpdateCapabilityRules), systemImage: "arrow.clockwise.circle")
                }
                .buttonStyle(.borderedProminent)
                .focusable(false)
                .disabled(vm.isUpdatingCapabilityRules)

                Button(action: { vm.openCapabilityRulesDirectory() }) {
                    Label(String(localized: .OpenCapabilityRulesDirectory), systemImage: "folder")
                }
                .buttonStyle(.bordered)
                .focusable(false)

                if vm.isUpdatingCapabilityRules {
                    ProgressView()
                        .controlSize(.small)
                }
            }
        }
    }

    // MARK: - 核心切换 + 状态卡片 (按 core 切换显示)

    private var coreSwitcher: some View {
        Picker("", selection: $coreTab) {
            ForEach(CoreUpdateKind.allCases) { kind in
                Text(kind.displayName).tag(kind)
            }
        }
        .pickerStyle(.segmented)
        .focusable(false)
        .labelsHidden()
        .fixedSize()
    }

    @ViewBuilder
    private func statusCard(for kind: CoreUpdateKind) -> some View {
        let item: CoreViewModel.CapabilityRulesDisplayItem? = {
            switch kind {
            case .xray: return vm.xrayCapabilityRulesStatus
            case .singbox: return vm.singboxCapabilityRulesStatus
            }
        }()
        if let item = item {
            CapabilityRulesStatusCard(item: item)
                .transition(.opacity)
        }
    }

    // MARK: - 过滤栏

    private var filterBar: some View {
        HStack(spacing: 10) {
            coreSwitcher
            
            Picker(String(localized: .CoreRulesKind), selection: $kindFilter) {
                Text(String(localized: .CoreRulesFilterAll)).tag(nil as XrayCapabilityKind?)
                ForEach(XrayCapabilityKind.allCases, id: \.self) { k in
                    Text(displayName(for: k)).tag(k as XrayCapabilityKind?)
                }
            }
            .pickerStyle(.menu)
            .focusable(false)
            .labelsHidden()
            .fixedSize()

            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField(String(localized: .CoreRulesSearchPlaceholder), text: $searchText)
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .focusable(false)
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(Color.secondary.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .frame(maxWidth: 220)

            Spacer()

            Text("\(filteredCapabilities.count) / \(allCapabilities.count)")
                .font(.caption)
                .foregroundColor(.secondary)
                .monospacedDigit()
        }
    }

    // MARK: - 表格展示

    private var capabilitiesTable: some View {
        VStack(spacing: 0) {
            if filteredCapabilities.isEmpty {
                emptyState
            } else {
                tableHeader
                Divider()
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredCapabilities, id: \.key) { cap in
                            tableRow(cap)
                            Divider().padding(.leading, 10)
                        }
                    }
                }
            }
        }
        .background(Color.secondary.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
        )
    }

    private var tableHeader: some View {
        HStack(spacing: 10) {
            Text("Key")
                .frame(width: 150, alignment: .leading)
            Text(String(localized: .CoreRulesKind))
                .frame(width: 70, alignment: .leading)
            Text(String(localized: .CoreRulesStatus))
                .frame(width: 80, alignment: .leading)
            Text(String(localized: .CoreRulesNote))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.caption)
        .foregroundColor(.secondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    private func tableRow(_ cap: CapabilityPayload) -> some View {
        let isSelected = selectedKey == cap.key
        return HStack(spacing: 10) {
            Text(cap.key)
                .font(.caption.monospaced())
                .foregroundColor(.secondary)
                .frame(width: 120, alignment: .leading)
                .lineLimit(1)

            Text(displayName(for: cap.kind))
                .font(.caption2)
                .foregroundColor(.accentColor)
                .frame(width: 70, alignment: .leading)

            Text(displayName(for: cap.rule.type))
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundColor(color(for: cap.rule.type))
                .frame(width: 100, alignment: .leading)

            HStack(spacing: 6) {
                Text(cap.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                if !cap.rule.note.isEmpty {
                    Text(cap.rule.note)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.accentColor)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(isSelected ? Color.accentColor.opacity(0.10) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedKey = selectedKey == cap.key ? nil : cap.key
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "tray")
                .font(.title)
                .foregroundColor(.secondary)
            Text(String(localized: .CoreRulesEmpty))
                .font(.callout)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }

    // MARK: - 详细面板 (选中行展开)

    @ViewBuilder
    private func capabilityDetailView(_ cap: CapabilityPayload) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // 标题行
            HStack {
                Text(cap.displayName)
                    .font(.headline)
                Text(cap.key)
                    .font(.caption.monospaced())
                    .foregroundColor(.secondary)
                Badge(text: displayName(for: cap.kind), color: .accentColor.opacity(0.85))
                Badge(text: displayName(for: cap.rule.type), color: color(for: cap.rule.type))
                Spacer()
                Button(action: { selectedKey = nil }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .focusable(false)
            }

            // 备注
            if !cap.rule.note.isEmpty {
                HStack(alignment: .top, spacing: 6) {
                    Text("\(String(localized: .CoreRulesNote)):")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 70, alignment: .trailing)
                    Text(cap.rule.note)
                        .font(.callout)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            // 应用支持信息
            if let appSupport = cap.appSupport {
                HStack(alignment: .top, spacing: 6) {
                    Text("\(String(localized: .CoreRulesAppSupport)):")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 70, alignment: .trailing)
                    Text("[\(appSupport.level.rawValue)] \(appSupport.note)")
                        .font(.callout)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            // 引用证据
            if let evidence = cap.evidence, !evidence.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text(String(localized: .CoreRulesEvidence))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    ForEach(evidence, id: \.id) { ev in
                        detailEvidenceRow(ev)
                    }
                }
                .padding(.leading, 70)
            }
        }
        .padding(12)
        .background(Color.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    @ViewBuilder
    private func detailEvidenceRow(_ ev: CapabilityEvidence) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Text("[\(ev.kind)]")
                    .font(.caption2.monospaced())
                    .foregroundColor(.accentColor)
                Text(ev.sourceTitle)
                    .font(.caption)
                    .lineLimit(1)
                if !ev.sourceURL.isEmpty {
                    Button(action: { openURL(ev.sourceURL) }) {
                        Image(systemName: "arrow.up.right.square")
                            .font(.caption2)
                    }
                    .buttonStyle(.plain)
                    .focusable(false)
                }
            }
            if !ev.quote.isEmpty {
                Text("\u{201C}\(ev.quote)\u{201D}")
                    .font(.caption2)
                    .italic()
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func openURL(_ urlStr: String) {
        guard let url = URL(string: urlStr) else { return }
        NSWorkspace.shared.open(url)
    }

    // MARK: - 数据计算

    private var allCapabilities: [CapabilityPayload] {
        vm.loadCapabilityRulesDocument(for: coreTab)?.capabilities ?? []
    }

    private var filteredCapabilities: [CapabilityPayload] {
        let kw = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return allCapabilities.filter { cap in
            if let filterKind = kindFilter, cap.kind != filterKind { return false }
            if kw.isEmpty { return true }
            return cap.key.lowercased().contains(kw)
                || cap.displayName.lowercased().contains(kw)
                || cap.rule.note.lowercased().contains(kw)
        }
    }

    // MARK: - 显示工具

    private func displayName(for kind: XrayCapabilityKind) -> String {
        switch kind {
        case .inboundProtocol: return String(localized: .CapabilityKindInbound)
        case .outboundProtocol: return String(localized: .CapabilityKindOutbound)
        case .transportMethod: return String(localized: .CapabilityKindTransport)
        case .transportSecurity: return String(localized: .CapabilityKindSecurity)
        case .additionalConfig: return String(localized: .CapabilityKindAdditional)
        case .flow: return String(localized: .CapabilityKindFlow)
        }
    }

    private func displayName(for status: CapabilityRuleStatus) -> String {
        switch status {
        case .supported: return String(localized: .CapabilityStatusSupported)
        case .legacy: return String(localized: .CapabilityStatusLegacy)
        case .compatibility: return String(localized: .CapabilityStatusCompatibility)
        case .unsupported: return String(localized: .CapabilityStatusUnsupported)
        case .removed: return String(localized: .CapabilityStatusRemoved)
        case .pendingReview: return String(localized: .CapabilityStatusPendingReview)
        }
    }

    private func color(for status: CapabilityRuleStatus) -> Color {
        switch status {
        case .supported: return .green
        case .legacy, .compatibility: return .blue
        case .pendingReview: return .orange
        case .unsupported, .removed: return .red
        }
    }
}

// MARK: - 小标签徽章

private struct Badge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.vertical, 2)
            .padding(.horizontal, 6)
            .background(color.opacity(0.18))
            .foregroundColor(color)
            .clipShape(Capsule())
    }
}
