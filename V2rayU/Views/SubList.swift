//
//  SubList.swift
//  V2rayU
//
//  Created by yanue on 2024/11/30.
//

import SwiftUI

struct SubListView: View {
    @StateObject private var viewModel = SubViewModel()

    @State private var list: [SubModel] = []
    @State private var sortOrder: [KeyPathComparator<SubModel>] = []
    @State private var selection: Set<SubModel.ID> = []
    @State private var selectedRow: SubModel? = nil
    @State private var draggedRow: SubModel?

    var filteredAndSortedItems: [SubModel] {
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
                // Header Section
                Text("Subscription")
                    .font(.title)
                    .fontWeight(.bold)
                
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
                        self.selectedRow = SubModel(remark: "", url: "")
                    }
                }
            }

            Table(of: SubModel.self, selection: $selection, sortOrder: $sortOrder) {
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
                TableColumn("Url", value: \.url).width(300)
                TableColumn("Port", value: \.enable.description)
                TableColumn("Interval", value: \.updateInterval.description)
                TableColumn("Updatetime", value: \.updateTime.description)
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
                .dropDestination(for: SubModel.self, action: handleDrop)
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
                SubFormView(item: row).padding()
            }
        }
        .task {
            loadData()
        }
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

struct SubFormView: View {
    @ObservedObject var item: SubModel

    var body: some View {
        HStack {
            VStack {
                Section(header: Text("Sub Settings")) {
                    getTextFieldWithLabel(label: "Remark", text: $item.remark)
                    getTextFieldWithLabel(label: "Url", text: $item.url)
                    getNumFieldWithLabel(label: "sort", num: $item.sort)
                    getNumFieldWithLabel(label: "updateInterval", num: $item.updateInterval)
                }
            }
        }
    }
}

#Preview {
    SubListView()
}
