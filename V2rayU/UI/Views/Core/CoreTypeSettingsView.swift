//
//  CoreTypeSettingsView.swift
//  V2rayU
//
//  Created by yanue on 2026/5/25.
//

import SwiftUI

/// Tab 1: 核心类型设置 — 配置不同协议默认走哪个核心
struct CoreTypeSettingsView: View {
    @ObservedObject var vm: CoreViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                header

                protocolMatrix
            }
            .padding(16)
        }
    }

    // MARK: - 头部

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "slider.horizontal.3")
                .font(.title3)
                .foregroundColor(.accentColor)
                .frame(width: 24, height: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: .CoreTabType))
                    .font(.headline)
                Text(String(localized: .CoreTypeSettingsSubtitle))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - 协议 → 核心 选择

    private var protocolMatrix: some View {
        VStack(alignment: .leading, spacing: 8) {
            LazyVGrid(
                columns: [
                    GridItem(.flexible(minimum: 140, maximum: 220), alignment: .leading),
                    GridItem(.flexible(minimum: 180), alignment: .leading),
                ],
                alignment: .leading,
                spacing: 8
            ) {
                ForEach(vm.coreSelectionProtocols, id: \.self) { proto in
                    Text(proto.rawValue)
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .background(Color.secondary.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 6))

                    Picker("", selection: Binding(
                        get: { vm.coreSelection(for: proto) },
                        set: { vm.setCoreSelection($0, for: proto) }
                    )) {
                        ForEach(ProfileCoreSelection.allCases) { selection in
                            Text(selection.displayName).tag(selection)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: 240, alignment: .leading)
                    .focusable(false)
                }
            }
        }
    }

    // MARK: - 本地核心文件

    private var localCoreSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(String(localized: .LocalCoreVersionDetail))
                .font(.headline)

            LocalCoreFileRow(
                title: "Xray-core",
                directory: CoreUpdateKind.xray.coreDirectory,
                displayText: "\(CoreUpdateKind.xray.binaryName)  ·  v\(vm.xrayCoreVersion)"
            )

            LocalCoreFileRow(
                title: "Sing-box",
                directory: CoreUpdateKind.singbox.coreDirectory,
                displayText: "\(CoreUpdateKind.singbox.binaryName)  ·  v\(vm.singboxCoreVersion)"
            )
        }
    }
}
