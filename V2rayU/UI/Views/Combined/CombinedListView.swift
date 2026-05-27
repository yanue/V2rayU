//
//  CombinedConfigListView.swift
//  V2rayU
//
//  Created by yanue on 2026/5/22.
//

import SwiftUI


// MARK: - 组合配置 (Combined inbound + outbound profile groups)

struct CombinedConfigListView: View {
    @StateObject private var viewModel = CombinedConfigViewModel()
    @State private var editingItem: CombinedConfigEntity?
    @State private var pendingDeleteUUID: String?
    @State private var showDeleteConfirm = false

    private func isRunning(_ item: CombinedConfigEntity) -> Bool {
        item.uuid == AppState.shared.runningCombination
    }

    var body: some View {
        VStack {
            PageHeader(
                icon: "rectangle.stack.badge.person.crop",
                title: localizedString(.Combinations),
                subtitle: localizedString(.CombinationSubHead)
            ) {
                HStack(spacing: 8) {
                    Button(action: {
                        editingItem = CombinedConfigEntity()
                    }) {
                        Label(String(localized: .Add), systemImage: "plus")
                    }
                    .buttonStyle(.bordered)
                    .focusable(false)

                    Button(action: { viewModel.getList() }) {
                        Label(String(localized: .Refresh), systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                    .focusable(false)
                }
            }

            // Default ports & current node
            HStack(spacing: 12) {
                Label("SOCKS:\(getSocksProxyPort())", systemImage: "rectangle.connected.to.line.below")
                Label("HTTP:\(getHttpProxyPort())", systemImage: "rectangle.connected.to.line.below")
                Spacer()
                if AppState.shared.v2rayTurnOn, let server = AppState.shared.runningServer {
                    Label(server.remark.isEmpty ? server.address : server.remark,
                          systemImage: "point.3.connected.trianglepath.dotted")
                        .foregroundColor(.accentColor)
                } else {
                    Label("-", systemImage: "point.3.connected.trianglepath.dotted")
                        .foregroundColor(.secondary)
                }
            }
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color.secondary.opacity(0.06))
            .cornerRadius(6)

            if viewModel.list.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "rectangle.stack.badge.plus")
                        .font(.system(size: 38))
                        .foregroundColor(.secondary)
                    Text(String(localized: .CombinationSubHead))
                        .font(.callout)
                        .foregroundColor(.secondary)
                }
                Spacer()
            } else {
                List {
                    ForEach(viewModel.list) { item in
                        CombinedConfigRow(
                            item: item,
                            isRunning: isRunning(item),
                            onEdit: { editingItem = item },
                            onActivate: {
                                Task { await AppState.shared.switchCombination(uuid: item.uuid) }
                            },
                            onDelete: {
                                pendingDeleteUUID = item.uuid
                                showDeleteConfirm = true
                            }
                        )
                    }
                }
                .listStyle(.inset)
            }
        }
        .padding(8)
        .sheet(item: $editingItem) { item in
            CombinedConfigFormView(
                item: item,
                profiles: viewModel.profiles,
                onSave: { newItem in
                    viewModel.upsert(item: newItem)
                    editingItem = nil
                },
                onCancel: { editingItem = nil }
            )
        }
        .alert(String(localized: .DeleteConfirm), isPresented: $showDeleteConfirm) {
            Button(String(localized: .Delete), role: .destructive) {
                if let uuid = pendingDeleteUUID {
                    viewModel.delete(uuid: uuid)
                }
                pendingDeleteUUID = nil
            }
            Button(String(localized: .Cancel), role: .cancel) {
                pendingDeleteUUID = nil
            }
        } message: {
            Text(String(localized: .DeleteTip))
        }
        .task { viewModel.getList() }
    }
}

private struct CombinedConfigRow: View {
    let item: CombinedConfigEntity
    let isRunning: Bool
    let onEdit: () -> Void
    let onActivate: () -> Void
    let onDelete: () -> Void

    private var comboColor: Color {
        (CombinationColor(rawValue: item.colorName) ?? .blue).color
    }

    private var coreBadge: String {
        guard let core = item.coreType, core != .auto else { return "" }
        return core.displayName
    }

    var body: some View {
        HStack(spacing: 10) {
            // 左侧状态指示
            if isRunning {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.system(size: 14))
                    .frame(width: 18)
            } else {
                Circle()
                    .fill(comboColor)
                    .frame(width: 10, height: 10)
                    .frame(width: 18)
            }

            // 中间信息区
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Text(item.displayName)
                        .font(.body)
                        .fontWeight(.medium)
                    if !coreBadge.isEmpty {
                        Text(coreBadge)
                            .font(.caption2)
                            .foregroundColor(comboColor)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(comboColor.opacity(0.12))
                            .cornerRadius(3)
                    }
                }
                HStack(spacing: 8) {
                    ForEach(item.groups) { group in
                        HStack(spacing: 2) {
                            Text(group.inboundType.rawValue.uppercased())
                                .font(.caption2.bold())
                            Text(":\(group.port)")
                                .font(.caption.monospaced())
                            Text("\(group.outboundProfileUUIDs.count)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .padding(.leading, 4)
                        }
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Color.secondary.opacity(0.08))
                        .cornerRadius(3)
                    }
                }
            }

            Spacer(minLength: 8)

            // 右侧操作
            HStack(spacing: 4) {
                Button(action: onActivate) {
                    Label(String(localized: .SetActive), systemImage: "bolt")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                Button(action: onEdit) {
                    Label(String(localized: .Edit), systemImage: "pencil")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                Button(action: onDelete) {
                    Label(String(localized: .Delete), systemImage: "trash")
                        .font(.caption)
                        .foregroundColor(.red)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 4)
        .background(isRunning ? comboColor.opacity(0.06) : Color.clear)
        .cornerRadius(6)
        .contentShape(Rectangle())
        .onTapGesture(count: 2, perform: onEdit)
    }
}
