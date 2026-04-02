//
//  SubList.swift
//  V2rayU
//
//  Created by yanue on 2024/11/30.
//

import SwiftUI

struct RoutingListView: View {
    @StateObject private var viewModel = RoutingViewModel()
    
    @State private var list: [RoutingEntity] = []
    @State private var sortOrder: [KeyPathComparator<RoutingEntity>] = []
    @State private var selection: Set<RoutingModel.ID> = []
    @State private var selectedRow: RoutingModel? = nil
    @State private var draggedRow: RoutingModel?
    @State private var tableOpacity: Double = 1.0

    private var isRunningRow: (RoutingEntity) -> Bool {
        { $0.uuid == AppState.shared.runningRouting }
    }
    
    private var filteredAndSortedItems: [RoutingEntity] {
        viewModel.list
    }
    
    private func resolveSelectedItems(for item: RoutingEntity) -> [RoutingEntity] {
        if selection.contains(item.uuid) && selection.count > 1 {
            return filteredAndSortedItems.filter { selection.contains($0.uuid) }
        }
        return [item]
    }
    
    var body: some View {
        VStack {
            PageHeader(
                icon: "arrow.triangle.branch",
                title: localizedString(.Routings),
                subtitle: localizedString(.RoutingSubHead)
            ) {
                HStack(spacing: 8) {
                    Button(action: { withAnimation {
                        let newProxy = RoutingModel(from: RoutingEntity())
                        self.selectedRow = newProxy
                    } }) {
                        Label(String(localized: .Add), systemImage: "plus")
                    }
                    .buttonStyle(.bordered)
                    .focusable(false)

                    Button(action: {
                        withAnimation(.easeOut(duration: 0.15)) {
                            tableOpacity = 0
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            loadData()
                            withAnimation(.easeIn(duration: 0.2)) {
                                tableOpacity = 1
                            }
                        }
                    }) {
                        Label(String(localized: .Refresh), systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                    .focusable(false)
                }
            }

            Spacer()
            routingTable
                .opacity(tableOpacity)
        }
        .padding(8)
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

    func handleDrop(index: Int, rows: [RoutingEntity]) {
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

    
    private func contextMenuProvider(item: RoutingEntity) -> some View {
        Group {
            Button {
                Task {
                    await AppState.shared.switchRouting(uuid: item.uuid)
                    loadData()
                }
            } label: {
                Label(String(localized: .SetActive), systemImage: "checkmark.circle")
            }
            .focusable(false)

            Divider()

            Button {
                self.selectedRow = RoutingModel(from: item)
            } label: {
                Label(String(localized: .Edit), systemImage: "pencil")
            }
            .focusable(false)

            Button {
                let itemsToDelete = resolveSelectedItems(for: item)
                if showConfirmAlertSync(title: String(localized: .DeleteSelectedConfirm), message: itemsToDelete.count > 1 ? String(localized: .DeleteMultipleConfirm, arguments: itemsToDelete.count) : String(localized: .DeleteTip)) {
                    for entity in itemsToDelete {
                        viewModel.delete(uuid: entity.uuid)
                    }
                }
            } label: {
                Label(String(localized: .Delete), systemImage: "trash")
                    .foregroundColor(.red)
            }
            .focusable(false)
        }
    }
    
    private func loadData() {
        withAnimation {
            viewModel.getList()
        }
    }
    
    // 提取的 Table 子视图，减少主视图表达式复杂度
    private var routingTable: some View {
        ZStack {
            Table(of: RoutingEntity.self, selection: $selection, sortOrder: $sortOrder) {
                TableColumn("#") { (row: RoutingEntity) in
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

                TableColumn(String(localized: .TableFieldSort)) { (row: RoutingEntity) in
                    HStack(spacing: 5) {
                        if isRunningRow(row) {
                            Image(systemName: "line.3.horizontal")
                                .foregroundColor(.green)
                        } else {
                            Image(systemName: "line.3.horizontal")
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
                .width(24)

                TableColumn(String(localized: .TableFieldRemark)) { (row: RoutingEntity) in
                    HStack(spacing: 4) {
                        if isRunningRow(row) {
                            Image(systemName: "square.and.pencil")
                                .foregroundColor(.green)
                                .font(.system(size: 13))
                            Text(row.remark)
                                .fontWeight(.semibold)
                        } else {
                            Image(systemName: "square.and.pencil")
                            Text(row.remark)
                        }
                    }
                    .contentShape(Rectangle())   // 扩大点击/拖拽区域
                    .onTapGesture() { selectedRow = RoutingModel(from: row) }
                    .onHover { inside in
                        if inside {
                            NSCursor.pointingHand.push()
                        } else {
                            NSCursor.pop()
                        }
                    }
                }
                .width(min: 200,max: 400)

                
                TableColumn(String(localized: .TableFieldDomainStrategy)) { row in
                    Text(row.domainStrategy)
                }
                .width(min: 90,max: 200)

                TableColumn(String(localized: .TableFieldDirect)) { row in
                    Text(row.direct)
                }
                .width(min: 100,max: 200)

                TableColumn(String(localized: .TableFieldBlock)) { row in
                    Text(row.block)
                }
                .width(min: 100,max: 200)

                TableColumn(String(localized: .TableFieldProxy)) { row in
                    Text(row.proxy)
                }
                .width(min: 100,max: 200)
            } rows: {
                ForEach(viewModel.list) { row in
                    TableRow(row).contextMenu { contextMenuProvider(item: row) }
                }
                .dropDestination(for: RoutingEntity.self) { index, items in
                    handleDrop(index: index, rows: items)
                }
            }
        }
    }
}

