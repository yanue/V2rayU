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
    @State private var sortOrder: [KeyPathComparator<CombinedConfigEntity>] = []
    @State private var searchText = ""
    @State private var editingItem: CombinedConfigEntity?
    @State private var pendingDeleteUUID: String?
    @State private var showDeleteConfirm = false

    private var isRunningRow: (CombinedConfigEntity) -> Bool {
        { $0.uuid == AppState.shared.runningCombination }
    }

    private var filteredAndSortedItems: [CombinedConfigEntity] {
        let filteredItems: [CombinedConfigEntity]
        if searchText.isEmpty {
            filteredItems = viewModel.list
        } else {
            filteredItems = viewModel.list.filter { item in
                item.remark.lowercased().contains(searchText.lowercased())
            }
        }
        guard !sortOrder.isEmpty else { return filteredItems }
        return filteredItems.sorted(using: sortOrder)
    }

    private func comboColor(_ item: CombinedConfigEntity) -> Color {
        (CombinationColor(rawValue: item.colorName) ?? .blue).color
    }

    private func coreBadge(_ item: CombinedConfigEntity) -> String {
        guard let core = item.coreType, core != .auto else { return "" }
        return core.displayName
    }

    private func strategyLabel(_ strategy: String) -> String {
        guard !strategy.isEmpty else { return "roundRobin" }
        return strategy
    }

    private func inboundSummary(_ item: CombinedConfigEntity) -> String {
        item.groups.map { group in
            "\(group.inboundType.rawValue.uppercased()):\(group.port)(\(group.outboundProfileUUIDs.count))"
        }
        .joined(separator: ", ")
    }

    var body: some View {
        VStack(spacing: 0) {
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

            // Search bar
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                        .font(.system(size: 13))
                    TextField(String(localized: .SearchTip), text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
                .frame(width: 200)

                Spacer()

                // Summary stats
                Text(String(localized: .CombinationCountFormat, arguments: viewModel.list.count))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 6)

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
            .padding(.horizontal, 8)

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
                tableView
                    .padding(.horizontal, 8)
                    .padding(.top, 4)
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

    @ViewBuilder
    private func contextMenuProvider(item: CombinedConfigEntity) -> some View {
        let isRunning = isRunningRow(item)
        Group {
            Button {
                performAfterMenuDismiss {
                    Task {
                        await AppState.shared.switchCombination(uuid: item.uuid)
                        viewModel.getList()
                    }
                }
            } label: {
                Label(isRunning ? "Deactivate" : String(localized: .SetActive),
                      systemImage: isRunning ? "stop.circle" : "bolt")
            }
            .focusable(false)

            Divider()

            Button {
                performAfterMenuDismiss {
                    editingItem = item
                }
            } label: {
                Label(String(localized: .Edit), systemImage: "pencil")
            }
            .focusable(false)

            Button {
                performAfterMenuDismiss {
                    pendingDeleteUUID = item.uuid
                    showDeleteConfirm = true
                }
            } label: {
                Label(String(localized: .Delete), systemImage: "trash")
                    .foregroundColor(.red)
            }
            .focusable(false)
        }
    }

    private func performAfterMenuDismiss(_ action: @escaping () -> Void) {
        DispatchQueue.main.async(execute: action)
    }

    private var tableView: some View {
        Table(of: CombinedConfigEntity.self, sortOrder: $sortOrder) {
            TableColumn("#") { (row: CombinedConfigEntity) in
                HStack(spacing: 4) {
                    if isRunningRow(row) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.system(size: 13))
                    } else if let idx = viewModel.list.firstIndex(where: { $0.uuid == row.uuid }) {
                        Text("\(idx + 1)")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .width(28)

            TableColumn(String(localized: .TableFieldSort)) { (row: CombinedConfigEntity) in
                HStack(spacing: 5) {
                    if isRunningRow(row) {
                        Image(systemName: "line.3.horizontal")
                            .foregroundColor(.green)
                    } else {
                        Image(systemName: "line.3.horizontal")
                    }
                }
                .contentShape(Rectangle())
                .draggable(row)
                .onHover { inside in
                    if inside { NSCursor.openHand.push() } else { NSCursor.pop() }
                }
            }
            .width(26)

            TableColumn(String(localized: .TableFieldRemark)) { (row: CombinedConfigEntity) in
                HStack(spacing: 4) {
                    if isRunningRow(row) {
                        Image(systemName: "square.and.pencil")
                            .foregroundColor(.green)
                            .font(.system(size: 13))
                        Text(row.displayName)
                            .fontWeight(.semibold)
                            .foregroundColor(.green)
                    } else {
                        Image(systemName: "square.and.pencil")
                        Text(row.displayName)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { editingItem = row }
                .onHover { inside in
                    if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                }
            }
            .width(min: 120, max: 300)

            TableColumn("Color") { (row: CombinedConfigEntity) in
                Circle()
                    .fill(comboColor(row))
                    .frame(width: 10, height: 10)
            }
            .width(36)

            TableColumn("Core") { (row: CombinedConfigEntity) in
                let badge = coreBadge(row)
                if !badge.isEmpty {
                    Text(badge)
                        .font(.caption2)
                        .foregroundColor(comboColor(row))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(comboColor(row).opacity(0.12))
                        .cornerRadius(3)
                }
            }
            .width(60)

            TableColumn("Combinations") { (row: CombinedConfigEntity) in
                Text(inboundSummary(row))
                    .font(.caption.monospaced())
            }
            .width(min: 100, max: 200)

            TableColumn("Strategy") { (row: CombinedConfigEntity) in
                Text(strategyLabel(row.balancerStrategy))
                    .font(.caption)
            }
            .width(70)
        } rows: {
            ForEach(filteredAndSortedItems) { row in
                TableRow(row)
                    .draggable(row)
                    .contextMenu { contextMenuProvider(item: row) }
            }
            .dropDestination(for: CombinedConfigEntity.self, action: handleDrop)
        }
    }

    func handleDrop(index: Int, rows: [CombinedConfigEntity]) {
        guard let firstRow = rows.first,
              let firstRemoveIndex = viewModel.list.firstIndex(where: { $0.uuid == firstRow.uuid })
        else { return }

        viewModel.list.removeAll(where: { row in
            rows.contains(where: { $0.uuid == row.uuid })
        })
        viewModel.list.insert(contentsOf: rows, at: index > firstRemoveIndex ? (index - 1) : index)
        viewModel.updateSortOrderInDB()
    }
}
