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
    @State private var kindFilter: KindFilter = .all
    @State private var expandedKeys: Set<String> = []

    enum KindFilter: Hashable, Identifiable {
        case all
        case kind(XrayCapabilityKind)

        var id: String {
            switch self {
            case .all: return "all"
            case .kind(let k): return k.rawValue
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            sourceConfigSection

            Divider()

            statusCards

            Divider()

            coreSwitcher

            filterBar

            capabilitiesList
        }
        .padding(16)
    }

    // MARK: - 头部

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "checklist")
                .font(.title3)
                .foregroundColor(.accentColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: .CapabilityRulesSettingsTitle))
                    .font(.headline)
                Text(String(localized: .CapabilityRulesRemoteBaseURLHint))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
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

    // MARK: - 来源状态卡片

    @ViewBuilder
    private var statusCards: some View {
        HStack(alignment: .top, spacing: 12) {
            if let xrayStatus = vm.xrayCapabilityRulesStatus {
                CapabilityRulesStatusCard(item: xrayStatus)
            }
            if let singboxStatus = vm.singboxCapabilityRulesStatus {
                CapabilityRulesStatusCard(item: singboxStatus)
            }
        }
    }

    // MARK: - xray / sing-box 切换

    private var coreSwitcher: some View {
        Picker("", selection: $coreTab) {
            ForEach(CoreUpdateKind.allCases) { kind in
                Text(kind.displayName).tag(kind)
            }
        }
        .pickerStyle(.segmented)
        .focusable(false)
        .frame(maxWidth: 360)
    }

    // MARK: - 过滤栏

    private var filterBar: some View {
        HStack(spacing: 10) {
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
            .frame(maxWidth: 320)

            Picker("", selection: $kindFilter) {
                Text(String(localized: .CoreRulesFilterAll)).tag(KindFilter.all)
                ForEach(XrayCapabilityKind.allCases, id: \.self) { kind in
                    Text(displayName(for: kind)).tag(KindFilter.kind(kind))
                }
            }
            .pickerStyle(.menu)
            .focusable(false)
            .frame(maxWidth: 180)

            Spacer()

            Text("\(filteredCapabilities.count) / \(allCapabilities.count)")
                .font(.caption)
                .foregroundColor(.secondary)
                .monospacedDigit()
        }
    }

    // MARK: - 明细列表

    @ViewBuilder
    private var capabilitiesList: some View {
        if filteredCapabilities.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "tray")
                    .font(.title)
                    .foregroundColor(.secondary)
                Text(String(localized: .CoreRulesEmpty))
                    .font(.callout)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 200)
        } else {
            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(filteredCapabilities, id: \.key) { cap in
                        CapabilityRowView(
                            capability: cap,
                            expanded: expandedKeys.contains(cap.key),
                            kindLabel: displayName(for: cap.kind),
                            statusLabel: displayName(for: cap.rule.type),
                            statusColor: color(for: cap.rule.type)
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if expandedKeys.contains(cap.key) {
                                expandedKeys.remove(cap.key)
                            } else {
                                expandedKeys.insert(cap.key)
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    // MARK: - 数据计算

    private var allCapabilities: [CapabilityPayload] {
        vm.loadCapabilityRulesDocument(for: coreTab)?.capabilities ?? []
    }

    private var filteredCapabilities: [CapabilityPayload] {
        let kw = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return allCapabilities.filter { cap in
            if case .kind(let k) = kindFilter, cap.kind != k { return false }
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

// MARK: - 单行能力规则

private struct CapabilityRowView: View {
    let capability: CapabilityPayload
    let expanded: Bool
    let kindLabel: String
    let statusLabel: String
    let statusColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: expanded ? "chevron.down" : "chevron.right")
                    .foregroundColor(.secondary)
                    .frame(width: 12)

                Text(capability.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)

                Text(capability.key)
                    .font(.caption.monospaced())
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                Spacer()

                Badge(text: kindLabel, color: .accentColor.opacity(0.85))
                Badge(text: statusLabel, color: statusColor)
            }

            if expanded {
                VStack(alignment: .leading, spacing: 6) {
                    if !capability.rule.note.isEmpty {
                        HStack(alignment: .top, spacing: 6) {
                            Text("\(String(localized: .CoreRulesNote)):")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(capability.rule.note)
                                .font(.caption)
                                .foregroundColor(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    if let appSupport = capability.appSupport {
                        HStack(alignment: .top, spacing: 6) {
                            Text("\(String(localized: .CoreRulesAppSupport)):")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("[\(appSupport.level.rawValue)] \(appSupport.note)")
                                .font(.caption)
                                .foregroundColor(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    if let evidence = capability.evidence, !evidence.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(String(localized: .CoreRulesEvidence)):")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            ForEach(evidence, id: \.id) { ev in
                                evidenceRow(ev)
                            }
                        }
                    }
                }
                .padding(.leading, 22)
                .padding(.top, 4)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(Color.secondary.opacity(expanded ? 0.10 : 0.06))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private func evidenceRow(_ ev: CapabilityEvidence) -> some View {
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
