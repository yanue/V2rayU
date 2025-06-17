//
//  SubList.swift
//  V2rayU
//
//  Created by yanue on 2024/11/30.
//

import SwiftUI

struct SubscriptionListView: View {
    @StateObject private var viewModel = SubViewModel()

    @State private var list: [SubModel] = []
    @State private var sortOrder: [KeyPathComparator<SubModel>] = []
    @State private var selection: Set<SubModel.ID> = []
    @State private var selectedRow: SubModel? = nil
    @State private var draggedRow: SubModel?
    @State private var syncingRow: SubModel? = nil
    @State private var syncingAll: Bool = false

    var filteredAndSortedItems: [SubModel] {
        let filtered = viewModel.list.sorted(using: sortOrder)
        // 循环增加序号
        filtered.enumerated().forEach { index, item in
            item.index = index
        }
        return filtered
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "link.circle.fill")
                    .resizable()
                    .frame(width: 28, height: 28)
                    .foregroundColor(.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Subscriptions")
                        .font(.title)
                        .fontWeight(.bold)
                    Text("Manage your subscription list")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()

                Button(action: { withAnimation { self.selectedRow = SubModel(remark: "", url: "") } }) {
                    Label("新增", systemImage: "plus")
                }
                .buttonStyle(.bordered)
                Button(action: {
                    let alert = NSAlert()
                    alert.messageText = "Are you sure you want to delete the selected subscriptions?"
                    alert.informativeText = "This action cannot be undone."
                    alert.alertStyle = .warning
                    alert.addButton(withTitle: "Delete")
                    alert.addButton(withTitle: "Cancel")
                    if alert.runModal() == .alertFirstButtonReturn {
                        withAnimation {
                            for selectedID in self.selection {
                                viewModel.delete(uuid: selectedID)
                            }
                            selection.removeAll()
                        }
                    }
                }) {
                    Label("删除", systemImage: "trash")
                }
                .disabled(selection.isEmpty)
                .buttonStyle(.bordered)

                Button(action: { syncingAll = true }) {
                    Label("SyncAll", systemImage: "arrow.triangle.2.circlepath")
                }
                .disabled(viewModel.list.isEmpty)
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            Spacer()
            ZStack {
                Table(of: SubModel.self, selection: $selection, sortOrder: $sortOrder) {
                    TableColumn("#") { row in
                        Text("\(row.index + 1)")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(.secondary)
                            .onTapGesture(count: 2) { selectedRow = row }
                    }
                    .width(30)
                    TableColumn("Remark") { row in
                        Text(row.remark)
                            .font(.system(size: 13))
                            .onTapGesture(count: 2) { selectedRow = row }
                    }
                    TableColumn("Url") { row in
                        Text(row.url)
                            .font(.system(size: 13))
                            .onTapGesture(count: 2) { selectedRow = row }
                    }.width(300)
                    TableColumn("Port") { row in
                        Text("\(row.enable)")
                            .font(.system(size: 13))
                            .onTapGesture(count: 2) { selectedRow = row }
                    }
                    TableColumn("Interval") { row in
                        Text("\(row.updateInterval)")
                            .font(.system(size: 13))
                            .onTapGesture(count: 2) { selectedRow = row }
                    }
                    TableColumn("Updatetime") { row in
                        Text("\(row.updateTime)")
                            .font(.system(size: 13))
                            .onTapGesture(count: 2) { selectedRow = row }
                    }
                } rows: {
                    ForEach(filteredAndSortedItems) { row in
                        TableRow(row)
                            .draggable(row)
                            .contextMenu { contextMenuProvider(item: row) }
                    }
                    .dropDestination(for: SubModel.self, action: handleDrop)
                }
                .padding(8)
            }
        }
        .sheet(item: $selectedRow) { row in
            SubscriptionFormView(item: row) {
                selectedRow = nil
                loadData()
            }
        }
        .sheet(item: $syncingRow) { row in
            SubscriptionSyncView(subscription: row, isAll: false) { syncingRow = nil }
        }
        .sheet(isPresented: $syncingAll) {
            SubscriptionSyncView(subscription: nil, isAll: true) { syncingAll = false }
        }
        .task { loadData() }
    }

    // 处理拖拽排序逻辑:
    // 参考: https://levelup.gitconnected.com/swiftui-enable-drag-and-drop-for-table-rows-with-custom-transferable-aa0e6eb9f5ce
    func handleDrop(index: Int, rows: [SubModel]) {
        guard let firstRow = rows.first, let firstRemoveIndex = list.firstIndex(where: { $0.uuid == firstRow.uuid }) else { return }

        list.removeAll(where: { row in
            rows.contains(where: { insertRow in insertRow.uuid == row.uuid })
        })

        list.insert(contentsOf: rows, at: index > firstRemoveIndex ? (index - 1) : index)
    }

    private func contextMenuProvider(item: SubModel) -> some View {
        Group {
            Button("Edit") {
                self.selectedRow = item
            }
            Button("Sync") {
                self.syncingRow = item
            }
            Divider()
            Button("Delete") {
                let alert = NSAlert()
                alert.messageText = "Are you sure you want to delete this subscription?"
                alert.informativeText = "This action cannot be undone."
                alert.alertStyle = .warning
                alert.addButton(withTitle: "Delete")
                alert.addButton(withTitle: "Cancel")
                if alert.runModal() == .alertFirstButtonReturn {
                    viewModel.delete(uuid: item.uuid)
                }
            }
        }
    }

    private func loadData() {
        withAnimation {
            viewModel.getList()
        }
    }
}

#Preview {
    SubscriptionListView()
}
