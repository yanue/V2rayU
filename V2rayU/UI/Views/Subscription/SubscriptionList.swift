//
//  SubList.swift
//  V2rayU
//
//  Created by yanue on 2024/11/30.
//

import SwiftUI

struct SubscriptionListView: View {
    @StateObject private var viewModel = SubscriptionViewModel()

    @State private var list: [SubscriptionEntity] = []
    @State private var sortOrder: [KeyPathComparator<SubscriptionEntity>] = []
    @State private var selection: Set<SubscriptionModel.ID> = []
    @State private var selectedRow: SubscriptionModel? = nil
    @State private var draggedRow: SubscriptionModel?
    @State private var syncingRow: SubscriptionModel? = nil
    @State private var syncingAll: Bool = false
    @State private var tableOpacity: Double = 1.0
    
    var body: some View {
        VStack(spacing: 0) {
            PageHeader(
                icon: "personalhotspot",
                title: localizedString(.Subscriptions),
                subtitle: localizedString(.SubscriptionSubHead)
            ) {
                HStack(spacing: 8) {
                    Button(action: { syncingAll = true }) {
                        Label(localizedString(.SyncAll), systemImage: "arrow.triangle.2.circlepath")
                    }
                    .buttonStyle(.borderedProminent)
                    .focusable(false)
                    .disabled(viewModel.list.isEmpty)

                    Button(action: { withAnimation { self.selectedRow = SubscriptionModel(from: SubscriptionEntity()) } }) {
                        Label(localizedString(.Add), systemImage: "plus")
                    }
                    .buttonStyle(.bordered)
                    .focusable(false)

                    Divider()
                        .frame(height: 20)

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

            // 将复杂的 Table 表达式提取到单独的计算属性以降低类型检查复杂度
            subscriptionTable
                .opacity(tableOpacity)

        }
        .padding(8)
        .sheet(item: $selectedRow) { row in
            SubscriptionFormView(item: row) {
                selectedRow = nil
                loadData()
            } onSaveAndSync: { [row] in
                Task {
                    await SubscriptionHandler.shared.syncOne(item: row.entity)
                    loadData()
                }
            }
        }
        .sheet(item: $syncingRow) { row in
            SubscriptionSyncView(subscription: row.entity, isAll: false) { syncingRow = nil }
        }
        .sheet(isPresented: $syncingAll) {
            SubscriptionSyncView(subscription: nil, isAll: true) { syncingAll = false }
        }
        .task { loadData() }
    }

    // 处理拖拽排序逻辑:
    // 参考: https://levelup.gitconnected.com/swiftui-enable-drag-and-drop-for-table-rows-with-custom-transferable-aa0e6eb9f5ce
    // 去掉这个没用的状态
    // @State private var list: [SubscriptionEntity] = []

    func handleDrop(index: Int, rows: [SubscriptionEntity]) {
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

    private func contextMenuProvider(item: SubscriptionEntity) -> some View {
        Group {
            Button {
                self.selectedRow = SubscriptionModel(from: item)
            } label: {
                Label(localizedString(.Edit), systemImage: "pencil")
            }
            .focusable(false)

            Button {
                self.syncingRow = SubscriptionModel(from: item)
            } label: {
                Label(localizedString(.SyncSubscriptionNow), systemImage: "arrow.triangle.2.circlepath")
            }
            .focusable(false)

            Divider()
            Button {
                if showConfirmAlertSync(title: localizedString(.DeleteConfirm), message: localizedString(.DeleteTip)) {
                    viewModel.delete(uuid: item.uuid)
                }
            } label: {
                Label(localizedString(.Delete), systemImage: "trash")
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
    private var subscriptionTable: some View {
        ZStack {
            Table(of: SubscriptionEntity.self, selection: $selection, sortOrder: $sortOrder) {
                TableColumn("#") { (row: SubscriptionEntity) in
                    HStack(spacing: 4) {
                        if let idx = viewModel.list.firstIndex(where: { $0.uuid == row.uuid }) {
                            Text("\(idx + 1)")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .width(10)
                
                TableColumn(String(localized: .TableFieldSort)) { (row: SubscriptionEntity) in
                    HStack(spacing: 4) {
                        Image(systemName: "line.3.horizontal")
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
                .width(30)
                
                TableColumn(String(localized: .TableFieldRemark)) { (row: SubscriptionEntity) in
                    HStack(spacing: 4) {
                        Image(systemName: "square.and.pencil")
                        Text(row.remark)
                    }
                    .contentShape(Rectangle())   // 扩大点击/拖拽区域
                    .onTapGesture() { selectedRow = SubscriptionModel(from: row) }
                    .onHover { inside in
                        if inside {
                            NSCursor.pointingHand.push()
                        } else {
                            NSCursor.pop()
                        }
                    }
                }
                .width(min: 100,max: 200)

                TableColumn(String(localized: .TableFieldUrl)) { (row: SubscriptionEntity) in
                    Text(row.url)
                }
                .width(min: 200,max: 400)

                TableColumn(String(localized: .TableFieldInterval)) { (row: SubscriptionEntity) in
                    Text(row.updateInterval.localizedInterval(locale: LanguageManager.shared.currentLocale))
                }
                .width(100)

                TableColumn(String(localized: .TableFieldUpdateTime)) { (row: SubscriptionEntity) in
                    Text(row.updateTime.formattedDate)
                }
                .width(160)

            } rows: {
                ForEach(viewModel.list) { row in
                    TableRow(row)
                        .contextMenu { contextMenuProvider(item: row) }
                }
                .dropDestination(for: SubscriptionEntity.self) { index, items in
                    handleDrop(index: index, rows: items)
                }

            }
        }
    }
}
