//
//  SubList.swift
//  V2rayU
//
//  Created by yanue on 2024/11/30.
//

import SwiftUI

struct RoutingListView: View {
    @StateObject private var viewModel = RoutingViewModel()

    @State private var list: [RoutingModel] = []
    @State private var sortOrder: [KeyPathComparator<RoutingModel>] = []
    @State private var selection: Set<RoutingModel.ID> = []
    @State private var selectedRow: RoutingModel? = nil
    @State private var draggedRow: RoutingModel?

    var filteredAndSortedItems: [RoutingModel] {
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
                Image(systemName: "bonjour")
                    .resizable()
                    .frame(width: 28, height: 28)
                    .foregroundColor(.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Routing")
                        .font(.title)
                        .fontWeight(.bold)
                    Text("匹配优先级: 域名阻断 -> 域名代理 -> 域名直连 -> IP阻断 -> IP代理 -> IP直连")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button(action: { withAnimation {
                    let newProxy = RoutingModel(name: "newRouting", remark: "newRouting")
                    self.selectedRow = newProxy
                } }) {
                    Label("新增", systemImage: "plus")
                }
                .buttonStyle(.bordered)
                Button(action: {
                    let alert = NSAlert()
                    alert.messageText = "Are you sure you want to delete the selected routings?"
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
                Button(action: { withAnimation { loadData() } }) {
                    Label("刷新", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            Divider()
            ZStack {
                Table(of: RoutingModel.self, selection: $selection, sortOrder: $sortOrder) {
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
                    }.width(180)
                    TableColumn("domainStrategy") { row in
                        Text(row.domainStrategy)
                            .font(.system(size: 13))
                            .onTapGesture(count: 2) { selectedRow = row }
                    }
                    TableColumn("direct") { row in
                        Text(row.direct)
                            .font(.system(size: 13))
                            .onTapGesture(count: 2) { selectedRow = row }
                    }
                    TableColumn("block") { row in
                        Text(row.block)
                            .font(.system(size: 13))
                            .onTapGesture(count: 2) { selectedRow = row }
                    }
                    TableColumn("proxy") { row in
                        Text(row.proxy)
                            .font(.system(size: 13))
                            .onTapGesture(count: 2) { selectedRow = row }
                    }
                } rows: {
                    ForEach(filteredAndSortedItems) { row in
                        TableRow(row)
                            .draggable(row)
                            .contextMenu {
                                Button("Edit") { self.selectedRow = row }
                                Divider()
                                Button("Delete") {
                                    let alert = NSAlert()
                                    alert.messageText = "Are you sure you want to delete this routing?"
                                    alert.informativeText = "This action cannot be undone."
                                    alert.alertStyle = .warning
                                    alert.addButton(withTitle: "Delete")
                                    alert.addButton(withTitle: "Cancel")
                                    if alert.runModal() == .alertFirstButtonReturn {
                                        viewModel.delete(uuid: row.uuid)
                                    }
                                }
                            }
                    }
                    .dropDestination(for: RoutingModel.self, action: handleDrop)
                }
                .padding(8)
            }
        }
        .sheet(item: $selectedRow) { row in
            RoutingFormView(item: row, onClose: {
                selectedRow = nil
                loadData()
            })
        }
        .task {
            loadData()
        }
    }

    // 处理拖拽排序逻辑:
    // 参考: https://levelup.gitconnected.com/swiftui-enable-drag-and-drop-for-table-rows-with-custom-transferable-aa0e6eb9f5ce
    func handleDrop(index: Int, rows: [RoutingModel]) {
        guard let firstRow = rows.first, let firstRemoveIndex = list.firstIndex(where: { $0.uuid == firstRow.uuid }) else { return }

        list.removeAll(where: { row in
            rows.contains(where: { insertRow in insertRow.uuid == row.uuid })
        })

        list.insert(contentsOf: rows, at: index > firstRemoveIndex ? (index - 1) : index)
    }

    private func contextMenuProvider(item: RoutingModel) -> some View {
        Group {
            Button("Edit") {
                self.selectedRow = item
            }

            Divider()

            Button("Delete") {
                viewModel.delete(uuid: item.uuid)
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
    RoutingListView()
}
