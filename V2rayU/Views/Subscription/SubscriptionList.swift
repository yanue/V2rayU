//
//  SubList.swift
//  V2rayU
//
//  Created by yanue on 2024/11/30.
//

import SwiftUI

struct SubscriptionListView: View {
    @StateObject private var viewModel = SubViewModel()

    @State private var list: [SubDTO] = []
    @State private var sortOrder: [KeyPathComparator<SubDTO>] = []
    @State private var selection: Set<SubModel.ID> = []
    @State private var selectedRow: SubModel? = nil
    @State private var draggedRow: SubModel?
    @State private var syncingRow: SubModel? = nil
    @State private var syncingAll: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "personalhotspot")
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

                Button(action: { withAnimation { self.selectedRow = SubModel(from: SubDTO()) } }) {
                    Label("新增", systemImage: "plus")
                }
                .buttonStyle(.bordered)
                Button(action: {
                    if showConfirmAlertSync(title: "Are you sure you want to delete the selected subscriptions?", message: "This action cannot be undone.") {
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

            
            Spacer()

            // 将复杂的 Table 表达式提取到单独的计算属性以降低类型检查复杂度
            subscriptionTable

        }
        .padding(8)
        .sheet(item: $selectedRow) { row in
            SubscriptionFormView(item: row) {
                selectedRow = nil
                loadData()
            }
        }
        .sheet(item: $syncingRow) { row in
            SubscriptionSyncView(subscription: row.dto, isAll: false) { syncingRow = nil }
        }
        .sheet(isPresented: $syncingAll) {
            SubscriptionSyncView(subscription: nil, isAll: true) { syncingAll = false }
        }
        .task { loadData() }
    }

    // 处理拖拽排序逻辑:
    // 参考: https://levelup.gitconnected.com/swiftui-enable-drag-and-drop-for-table-rows-with-custom-transferable-aa0e6eb9f5ce
    // 去掉这个没用的状态
    // @State private var list: [SubDTO] = []

    func handleDrop(index: Int, rows: [SubDTO]) {
        let uuids = rows.map(\.uuid)

        // 先移除拖拽的元素
        viewModel.list.removeAll { uuids.contains($0.uuid) }

        // 计算安全的插入位置
        let safeIndex = min(max(index, 0), viewModel.list.count)

        // 插入拖拽的元素
        viewModel.list.insert(contentsOf: rows, at: safeIndex)

        logger.info("handleDrop: \(index) \(rows.count)")
        viewModel.updateSortOrderInDBAsync()
    }


    private func contextMenuProvider(item: SubDTO) -> some View {
        Group {
            Button("Edit") {
                self.selectedRow = SubModel(from: item)
            }
            Button("Sync") {
                self.syncingRow = SubModel(from: item)
            }
            Divider()
            Button("Delete") {
                if showConfirmAlertSync(title: "Are you sure you want to delete this subscription?", message: "This action cannot be undone.") {
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

    // 提取的 Table 子视图，减少主视图表达式复杂度
    private var subscriptionTable: some View {
        ZStack {
            Table(of: SubDTO.self, selection: $selection, sortOrder: $sortOrder) {
                TableColumn("#") { (row: SubDTO) in
                    HStack(spacing: 4) {
                        Image(systemName: "line.3.horizontal")

                        if let idx = viewModel.list.firstIndex(where: { $0.uuid == row.uuid }) {
                            Text("\(idx + 1)")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                    }
                    .contentShape(Rectangle())   // 扩大点击/拖拽区域
                    .draggable(row)              // 整个区域作为拖拽手柄
                    .onTapGesture { }            // 吃掉点击事件，避免触发行选择
                    .onHover { inside in
                        if inside {
                            NSCursor.openHand.push()
                        } else {
                            NSCursor.pop()
                        }
                    }
                }
                .width(40)
                
                TableColumn("Remark") { (row: SubDTO) in
                    HStack(spacing: 4) {
                        Image(systemName: "square.and.pencil")
                        Text(row.remark)
                    }
                    .contentShape(Rectangle())   // 扩大点击/拖拽区域
                    .onTapGesture() { selectedRow = SubModel(from: row) }
                    .onHover { inside in
                        if inside {
                            NSCursor.pointingHand.push()
                        } else {
                            NSCursor.pop()
                        }
                    }
                }
                .width(min: 100,max: 200)

                TableColumn("Url") { (row: SubDTO) in
                    Text(row.url)
                }
                .width(min: 200,max: 400)

                TableColumn("Interval") { (row: SubDTO) in
                    Text("\(row.updateInterval)")
                }
                .width(100)

                TableColumn("Updatetime") { (row: SubDTO) in
                    Text("\(row.updateTime)")
                }
                .width(160)

            } rows: {
                ForEach(viewModel.list) { row in
                    TableRow(row)
                        .contextMenu { contextMenuProvider(item: row) }
                }
                .dropDestination(for: SubDTO.self) { index, items in
                    handleDrop(index: index, rows: items)
                }

            }
        }
    }
}
