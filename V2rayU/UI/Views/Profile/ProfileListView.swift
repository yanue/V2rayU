//
//  ConfigList.swift
//  V2rayU
//
//  Created by yanue on 2024/11/30.
//

import SwiftUI

struct ProfileListView: View {
    @StateObject private var viewModel = ProfileViewModel()
    @State private var list: [ProfileEntity] = []
    @State private var sortOrder: [KeyPathComparator<ProfileEntity>] = []
    @State private var selection: Set<ProfileModel.ID> = []
    @State private var selectedRow: ProfileModel? = nil
    @State private var pingRow: ProfileModel? = nil
    @State private var shareRow: ProfileModel? = nil
    @State private var selectGroup: String = ""
    @State private var searchText = ""
    @State private var draggedRow: ProfileModel?
    @State private var selectAll: Bool = false
    @State private var showPingSheet: Bool = false
    @State private var showShareSheet: Bool = false

    var filteredAndSortedItems: [ProfileEntity] {
        let filtered = viewModel.list.filter { item in
            (selectGroup == "" || selectGroup == item.subid) &&
                (searchText.isEmpty || item.address.lowercased().contains(searchText.lowercased()) || item.remark.lowercased().contains(searchText.lowercased()))
        }
        return filtered
    }

    var body: some View {
        VStack {
            HStack {
                Image(systemName: "shield.lefthalf.filled")
                    .resizable()
                    .frame(width: 28, height: 28)
                    .foregroundColor(.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    localized(.Servers)
                        .font(.title)
                        .fontWeight(.bold)
                    localized(.ServerSubHead)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Picker(String(localized: .SelectGroup), selection: $selectGroup) {
                    Text(String(localized: .AllGroup)).tag("")
                    ForEach(viewModel.groups, id: \.self) { group in
                        Text(group).tag(group)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .frame(width: 140)
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField(String(localized: .SearchTip), text: $searchText)
                        .frame(width: 200)
                }
            }

            Spacer()
            VStack {
                Spacer()
                HStack {
                    Button(action: { withAnimation {
                        let newProxy = ProfileModel(from: ProfileEntity())
                        self.selectedRow = newProxy
                    }}) {
                        Label(String(localized: .Add), systemImage: "plus")
                    }
                    .buttonStyle(.bordered)
                    Button(action: {
                        if showConfirmAlertSync(title: String(localized: .DeleteSelectedConfirm), message: String(localized: .DeleteTip)) {
                            withAnimation {
                                for selectedID in self.selection {
                                    viewModel.delete(uuid: selectedID)
                                }
                                selection.removeAll()
                            }
                        }
                    }) {
                        Label(String(localized: .Delete), systemImage: "trash")
                    }
                    .disabled(selection.isEmpty)
                    .buttonStyle(.bordered)

                    Button(action: { showPingSheet = true }) {
                        Label(String(localized: .Ping), systemImage: "lasso.badge.sparkles")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.list.isEmpty)
                    // 分享
                    Button(action: {
                    }) {
                        Label(String(localized: .Export), systemImage: "square.and.arrow.up")
                    }.disabled(selection.isEmpty)
                        .buttonStyle(.bordered)
                }.padding(.horizontal, 10)
                tableView
            }
            .background(.ultraThinMaterial)
            .border(Color.gray.opacity(0.1), width: 1)
            .cornerRadius(8)
        }
        .padding(8)
        .sheet(item: $selectedRow) { row in
            ConfigFormView(item: row) {
                selectedRow = nil
                loadData()                
            }
        }
        .sheet(item: $pingRow) { _ in
            ProfilePingView(profile: pingRow?.toEntity(), isAll: false) {
                pingRow = nil
            }
        }
        .sheet(isPresented: $showPingSheet) {
            ProfilePingView(profile: nil, isAll: true) {
                showPingSheet = false
            }
        }
        .sheet(item: $shareRow) { _ in
        }
        .sheet(isPresented: $showShareSheet) {
        }
        .task { loadData() }
    }

    // 处理拖拽排序逻辑:
    // 参考: https://levelup.gitconnected.com/swiftui-enable-drag-and-drop-for-table-rows-with-custom-transferable-aa0e6eb9f5ce
    func handleDrop(index: Int, rows: [ProfileEntity]) {
        guard let firstRow = rows.first, let firstRemoveIndex = viewModel.list.firstIndex(where: { $0.uuid == firstRow.uuid }) else { return }

        viewModel.list.removeAll(where: { row in
            rows.contains(where: { insertRow in insertRow.uuid == row.uuid })
        })

        viewModel.list.insert(contentsOf: rows, at: index > firstRemoveIndex ? (index - 1) : index)
        logger.info("handleDrop: \(index) \(rows.count)")
        // 更新排序
        viewModel.updateSortOrderInDBAsync()
    }

    private func contextMenuProvider(item: ProfileEntity) -> some View {
        Group {
            Button {
                chooseItem(item: ProfileModel(from: item))
            } label: {
                Label(String(localized: .Select), systemImage: "checkmark.circle")
            }

            Button {
                self.pingRow = ProfileModel(from: item)
            } label: {
                Label(String(localized: .Ping), systemImage: "speedometer")
            }

            Divider()

            Button {
                copyItem(item: item)
            } label: {
                Label(String(localized: .CopyURI), systemImage: "doc.on.doc")
            }

            Button {
                self.shareRow = ProfileModel(from: item)
            } label: {
                Label(String(localized: .ShareQrCode), systemImage: "qrcode")
            }

            Divider()

            Button(action: {
                moveToTop(item: item)
            }) {
                Label(String(localized: .MoveToTop), systemImage: "arrow.up.to.line")
            }

            Button(action: {
                moveToBottom(item: item)
            }) {
                Label(String(localized: .MoveToBottom), systemImage: "arrow.down.to.line")
            }

            Button(action: {
                moveUp(item: item)
            }) {
                Label(String(localized: .MoveUp), systemImage: "chevron.up")
            }

            Button(action: {
                moveDown(item: item)
            }) {
                Label(String(localized: .MoveDown), systemImage: "chevron.down")
            }

            Divider()

            Button {
                duplicateItem(item: ProfileModel(from: item))
            } label: {
                Label(String(localized: .Duplicate), systemImage: "plus.square.on.square")
            }

            Button {
                self.selectedRow = ProfileModel(from: item)
            } label: {
                Label(String(localized: .Edit), systemImage: "pencil")
            }

            Button {
                if showConfirmAlertSync(title: String(localized: .DeleteSelectedConfirm), message: String(localized: .DeleteTip)) {
                    viewModel.delete(uuid: item.uuid)
                }
            } label: {
                Label(String(localized: .Delete), systemImage: "trash")
                    .foregroundColor(.red)
            }
        }
    }

    // 提取的 Table 子视图，减少主视图表达式复杂度
    private var tableView: some View {
        // 表格主体
        Table(of: ProfileEntity.self, selection: $selection, sortOrder: $sortOrder) {
            Group {
                TableColumn("#") { (row: ProfileEntity) in
                    HStack(spacing: 4) {
                        if let idx = viewModel.list.firstIndex(where: { $0.uuid == row.uuid }) {
                            Text("\(idx + 1)")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .width(20)

                TableColumn(String(localized: .TableFieldSort)) { (row: ProfileEntity) in
                    HStack(spacing: 5) {
                        Image(systemName: "line.3.horizontal")
                    }
                    .contentShape(Rectangle()) // 扩大点击/拖拽区域
                    .draggable(row) // 整个区域作为拖拽手柄
                    .onTapGesture { } // 吃掉点击事件，避免触发行选择
                    .onHover { inside in
                        if inside {
                            NSCursor.openHand.push()
                        } else {
                            NSCursor.pop()
                        }
                    }
                }
                .width(26)

                TableColumn(String(localized: .TableFieldRemark)) { (row: ProfileEntity) in
                    HStack(spacing: 4) {
                        Image(systemName: "square.and.pencil")
                        Text(row.remark)
                    }
                    .contentShape(Rectangle()) // 扩大点击/拖拽区域
                    .onTapGesture { selectedRow = ProfileModel(from: row) }
                    .onHover { inside in
                        if inside {
                            NSCursor.pointingHand.push()
                        } else {
                            NSCursor.pop()
                        }
                    }
                }
                .width(min: 120, max: 300)

                TableColumn(String(localized: .TableFieldType)) { row in
                    Text(row.protocol == .shadowsocks ? "ss" : row.protocol.rawValue)
                }
                .width(40)

                TableColumn(String(localized: .TableFieldAddress)) { row in
                    Text(row.address)
                }
                .width(min: 120, max: 300)

                TableColumn(String(localized: .TableFieldLatency)) { (row: ProfileEntity) in
                    Text("\(row.speed)")
                        .foregroundColor(Color(getSpeedColor(latency: Double(row.speed))))
                }
                .width(76)

                TableColumn(String(localized: .TableFieldPort)) { row in
                    Text("\(row.port)")
                }
                .width(40)
                TableColumn(String(localized: .TableFieldNetwork)) { row in
                    Text(row.network.rawValue)
                }.width(50)
                TableColumn(String(localized: .TableFieldSecurity)) { row in
                    Text(row.security.rawValue)
                }.width(40)
            }
            Group {
                TableColumn(String(localized: .TableFieldTodayDown)) { (row: ProfileEntity) in
                    Text(row.todayDown.humanSize)
                }
                .width(min: 40, max: 100)

                TableColumn(String(localized: .TableFieldTodayUp)) { (row: ProfileEntity) in
                    Text(row.todayUp.humanSize)
                }
                .width(min: 40, max: 100)

                TableColumn(String(localized: .TableFieldTodayDown)) { (row: ProfileEntity) in
                    Text(row.totalDown.humanSize)
                }
                .width(min: 40, max: 100)

                TableColumn(String(localized: .TableFieldTodayUp)) { (row: ProfileEntity) in
                    Text(row.totalUp.humanSize)
                }
                .width(min: 40, max: 100)
            }
        } rows: {
            ForEach(filteredAndSortedItems) { row in
                TableRow(row)
                    .draggable(row)
                    .contextMenu { contextMenuProvider(item: row) }
            }
            .dropDestination(for: ProfileEntity.self, action: handleDrop)
        }
    }

    private func chooseItem(item: ProfileModel) {
        // 选择当前配置
        Task {
            await AppState.shared.switchServer(uuid: item.uuid)
        }
    }

    private func duplicateItem(item: ProfileModel) {
        let newItem = item.clone()
        viewModel.upsert(item: newItem.entity)
        viewModel.updateSortOrderInDBAsync()
    }

    private func copyItem(item: ProfileEntity) {
        // 复制到剪贴板
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        let profileString = ShareUri.generateShareUri(item: item)
        if pasteboard.setString(profileString, forType: .string) {
            logger.info("Copied to clipboard: \(profileString)")
            alertDialog(title: String(localized: .Copied), message: "")
        } else {
            logger.info("Failed to copy to clipboard")
            alertDialog(title: String(localized: .CopyFailed), message: "")
        }
    }

    private func moveToTop(item: ProfileEntity) {
        guard let index = viewModel.list.firstIndex(where: { $0.id == item.id }) else { return }
        viewModel.list.remove(at: index)
        viewModel.list.insert(item, at: 0)
        viewModel.updateSortOrderInDBAsync()
    }

    private func moveToBottom(item: ProfileEntity) {
        guard let index = viewModel.list.firstIndex(where: { $0.id == item.id }) else { return }
        viewModel.list.remove(at: index)
        viewModel.list.append(item)
        viewModel.updateSortOrderInDBAsync()
    }

    private func moveUp(item: ProfileEntity) {
        guard let index = viewModel.list.firstIndex(where: { $0.id == item.id }), index > 0 else { return }
        viewModel.list.swapAt(index, index - 1)
        viewModel.updateSortOrderInDBAsync()
    }

    private func moveDown(item: ProfileEntity) {
        guard let index = viewModel.list.firstIndex(where: { $0.id == item.id }), index < viewModel.list.count - 1 else { return }
        viewModel.list.swapAt(index, index + 1)
        viewModel.updateSortOrderInDBAsync()
    }

    private func loadData() {
        viewModel.getList() // Load data when the view appears
    }
}
