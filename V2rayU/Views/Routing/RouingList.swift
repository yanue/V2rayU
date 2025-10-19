//
//  SubList.swift
//  V2rayU
//
//  Created by yanue on 2024/11/30.
//

import SwiftUI

struct RoutingListView: View {
    @StateObject private var viewModel = RoutingViewModel()
    
    @State private var list: [RoutingDTO] = []
    @State private var sortOrder: [KeyPathComparator<RoutingDTO>] = []
    @State private var selection: Set<RoutingModel.ID> = []
    @State private var selectedRow: RoutingModel? = nil
    @State private var draggedRow: RoutingModel?
    
    var body: some View {
        VStack() {
            HStack {
                Image(systemName: "bonjour")
                    .resizable()
                    .frame(width: 28, height: 28)
                    .foregroundColor(.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    localized(.Routings)
                        .font(.title)
                        .fontWeight(.bold)
                    localized(.RoutingSubHead)
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
            
            routingTable
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

    func handleDrop(index: Int, rows: [RoutingDTO]) {
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

    
    private func contextMenuProvider(item: RoutingDTO) -> some View {
        Group {
            Button("Edit") {
                self.selectedRow = RoutingModel(from: item)
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
    private var routingTable: some View {
        ZStack {
            Table(of: RoutingDTO.self, selection: $selection, sortOrder: $sortOrder) {
                TableColumn("#") { (row: RoutingDTO) in
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
                
                TableColumn("Remark") { (row: RoutingDTO) in
                    HStack(spacing: 4) {
                        Image(systemName: "square.and.pencil")
                        Text(row.remark)
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

                
                TableColumn("domainStrategy") { row in
                    Text(row.domainStrategy)
                        .font(.system(size: 13))
                }
                .width(min: 90,max: 200)

                TableColumn("direct") { row in
                    Text(row.direct)
                        .font(.system(size: 13))
                }
                .width(min: 100,max: 200)

                TableColumn("block") { row in
                    Text(row.block)
                        .font(.system(size: 13))
                }
                .width(min: 100,max: 200)

                TableColumn("proxy") { row in
                    Text(row.proxy)
                        .font(.system(size: 13))
                }
                .width(min: 100,max: 200)
            } rows: {
                ForEach(viewModel.list) { row in
                    TableRow(row).contextMenu { contextMenuProvider(item: row) }
                }
                .dropDestination(for: RoutingDTO.self) { index, items in
                    handleDrop(index: index, rows: items)
                }
            }
        }
    }
}

