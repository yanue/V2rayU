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
        VStack {
            HStack {
                Button("刷新") {
                    withAnimation {
                        loadData()
                    }
                }
                Spacer()

                Button("删除") {
                    withAnimation {
                        // 删数据
                        for selectedID in self.selection {
                            viewModel.delete(uuid: selectedID) // 使用找到的模型的 uuid 字段
                        }
                        // 移除选择
                        selection.removeAll()
                    }
                }
                .disabled(selection.isEmpty)
                Button("新增") {
                    withAnimation {
                        let newProxy = RoutingModel(name: "newRouting", remark: "newRouting")
                        self.selectedRow = newProxy
                    }
                }
            }

            Table(of: RoutingModel.self, selection: $selection, sortOrder: $sortOrder) {
                TableColumn("#") { item in
                    Text("\(item.index + 1)") // 显示 1-based 索引
                }
                .width(30)
                TableColumn("Remark") { row in
                    // 双击事件
                    Text(row.remark).onTapGesture(count: 2) {
                        selectedRow = row
                    }
                }
                TableColumn("name", value: \.name).width(300)
                TableColumn("domainStrategy", value: \.domainStrategy)
                TableColumn("proxy", value: \.proxy)
                TableColumn("block", value: \.block)
                TableColumn("direct", value: \.direct)
            } rows: {
                ForEach(filteredAndSortedItems) { row in
                    TableRow(row)
                        // 启用拖拽功能
                        .draggable(row)
                        // 右键菜单
                        .contextMenu {
                            contextMenuProvider(item: row)
                        }
                }
                // 处理拖动逻辑
                .dropDestination(for: RoutingModel.self, action: handleDrop)
            }
        }
        .sheet(item: $selectedRow) { row in
            VStack {
                Button("Close") {
                    print("upsert, \(row)")
                    viewModel.upsert(item: row)
                    // 如果需要关闭 `sheet`，将 `selectedRow` 设置为 `nil`
                    selectedRow = nil
                }
                RoutingFormView(item: row).padding()
            }
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

struct RoutingFormView: View {
    @ObservedObject var item: RoutingModel

    var body: some View {
        HStack {
            VStack {
                Section(header: Text("Routing Settings")) {
                    getTextFieldWithLabel(label: "Name", text: $item.name)
                    getTextFieldWithLabel(label: "Remark", text: $item.remark)
                    getTextFieldWithLabel(label: "domainStrategy", text: $item.domainStrategy)
                    getTextFieldWithLabel(label: "block", text: $item.block)
                    getTextFieldWithLabel(label: "proxy", text: $item.proxy)
                    getTextFieldWithLabel(label: "direct", text: $item.direct)
                }
            }
        }
    }
}

#Preview {
    RoutingListView()
}
