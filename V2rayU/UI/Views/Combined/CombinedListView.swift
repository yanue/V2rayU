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

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: isRunning ? "checkmark.circle.fill" : "rectangle.stack")
                .foregroundColor(isRunning ? .green : .secondary)
                .font(.system(size: 16))
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.displayName)
                    .font(.headline)
                ForEach(item.groups) { group in
                    HStack(spacing: 6) {
                        Text(group.inboundType.rawValue.uppercased())
                            .font(.caption2.bold())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.15))
                            .cornerRadius(4)
                        Text(":\(group.port)")
                            .font(.caption.monospaced())
                        Text("→ \(group.outboundProfileUUIDs.count) outbound(s)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            HStack(spacing: 6) {
                Button(action: onActivate) {
                    Label(String(localized: .SetActive), systemImage: "play.circle")
                }
                .buttonStyle(.borderless)
                Button(action: onEdit) {
                    Label(String(localized: .Edit), systemImage: "pencil")
                }
                .buttonStyle(.borderless)
                Button(action: onDelete) {
                    Label(String(localized: .Delete), systemImage: "trash")
                        .foregroundColor(.red)
                }
                .buttonStyle(.borderless)
            }
            .labelStyle(.iconOnly)
            .font(.system(size: 15))
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture(count: 2, perform: onEdit)
    }
}
