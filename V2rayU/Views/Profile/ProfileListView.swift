//
//  ConfigList.swift
//  V2rayU
//
//  Created by yanue on 2024/11/30.
//

import SwiftUI

struct ProfileListView: View {
    @StateObject private var viewModel = ProfileViewModel()
    @State private var list: [ProfileModel] = []
    @State private var sortOrder: [KeyPathComparator<ProfileModel>] = []
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

    var filteredAndSortedItems: [ProfileModel] {
        let filtered = viewModel.list.filter { item in
            (selectGroup == "" || selectGroup == item.subid) &&
                (searchText.isEmpty || item.address.lowercased().contains(searchText.lowercased()) || item.remark.lowercased().contains(searchText.lowercased()))
        }
        .sorted(using: sortOrder)
        // 循环增加序号
        filtered.enumerated().forEach { index, item in
            item.index = index
        }
        return filtered
    }

    var body: some View {
        VStack() {
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
                Picker("选择组", selection: $selectGroup) {
                    Text("全部分组").tag("")
                    ForEach(viewModel.groups, id: \.self) { group in
                        Text(group).tag(group)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .frame(width: 140)
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search by Address or Remark", text: $searchText)
                        .frame(width: 200)
                }
            }

            Spacer()
            VStack {
                Spacer()
                HStack {
                    // checkbox
                    Toggle(isOn: $selectAll) {
                        Text("全选")
                    }
                    Spacer()
                    Button(action: { withAnimation {
                        let newProxy = ProfileModel(remark: "", protocol: .trojan, address: "", port: 443, password: UUID().uuidString, encryption: "auto")
                        self.selectedRow = newProxy
                    }}) {
                        Label("新增", systemImage: "plus")
                    }
                    .buttonStyle(.bordered)
                    Button(action: {
                        if showConfirmAlertSync(title: "Are you sure you want to delete the selected Proxy Profiles?", message: "This action cannot be undone.") {
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

                    Button(action: { showPingSheet = true }) {
                        Label("PingAll", systemImage: "lasso.badge.sparkles")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.list.isEmpty)
                    // 分享
                    Button(action: {
                    }) {
                        Label("分享", systemImage: "square.and.arrow.up")
                    }.disabled(selection.isEmpty)
                        .buttonStyle(.bordered)
                }.padding(.horizontal, 10)
                // 表格主体
                Table(of: ProfileModel.self, selection: $selection, sortOrder: $sortOrder) {
                    TableColumn("#") { item in
                        Text("\(item.index + 1)")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(.secondary)
                            .onTapGesture(count: 2) { selectedRow = item }
                    }
                    .width(30)
                    TableColumn("Type") { row in
                        Text(row.protocol == .shadowsocks ? "ss" : row.protocol.rawValue)
                            .font(.system(size: 13))
                            .onTapGesture(count: 2) { selectedRow = row }
                    }
                    .width(40)
                    TableColumn("Remark") { row in
                        Text(row.remark)
                            .font(.system(size: 13))
                            .onTapGesture(count: 2) { selectedRow = row }
                    }
                    .width(150)
                    TableColumn("Address") { row in
                        Text(row.address)
                            .font(.system(size: 13))
                            .onTapGesture(count: 2) { selectedRow = row }
                    }
                    .width(120)
                    TableColumn("Port") { row in
                        Text("\(row.port)")
                            .font(.system(size: 13))
                            .onTapGesture(count: 2) { selectedRow = row }
                    }
                    .width(40)
                    TableColumn("Network") { row in
                        Text(row.network.rawValue)
                            .font(.system(size: 13))
                            .onTapGesture(count: 2) { selectedRow = row }
                    }.width(50)
                    TableColumn("TLS") { row in
                        Text(row.security.rawValue)
                            .font(.system(size: 13))
                            .onTapGesture(count: 2) { selectedRow = row }
                    }.width(40)
                    TableColumn("latency(KB/s)") { row in
                        Text(String(format: "%d", row.speed))
                            .font(.system(size: 13))
                            .onTapGesture(count: 2) { selectedRow = row }
                    }.width(76)
                } rows: {
                    ForEach(filteredAndSortedItems) { row in
                        TableRow(row)
                            .draggable(row)
                            .contextMenu { contextMenuProvider(item: row) }
                    }
                    .dropDestination(for: ProfileModel.self, action: handleDrop)
                }
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
            ProfilePingView(profile: pingRow, isAll: false) {
                pingRow = nil
            }
        }
        .sheet(isPresented: $showPingSheet) {
            ProfilePingView(profile: nil, isAll: true) {
                showPingSheet = false
            }
        }
        .sheet(item: $shareRow) { _ in
            ProfileShareView(profile: shareRow, isAll: false) {
                shareRow = nil
            }
        }
        .sheet(isPresented: $showShareSheet) {
            ProfileShareView(profile: nil, isAll: true) {
                showShareSheet = false
            }
        }
        .task { loadData() }
    }

    // 处理拖拽排序逻辑:
    // 参考: https://levelup.gitconnected.com/swiftui-enable-drag-and-drop-for-table-rows-with-custom-transferable-aa0e6eb9f5ce
    func handleDrop(index: Int, rows: [ProfileModel]) {
        guard let firstRow = rows.first, let firstRemoveIndex = viewModel.list.firstIndex(where: { $0.uuid == firstRow.uuid }) else { return }

        viewModel.list.removeAll(where: { row in
            rows.contains(where: { insertRow in insertRow.uuid == row.uuid })
        })

        viewModel.list.insert(contentsOf: rows, at: index > firstRemoveIndex ? (index - 1) : index)
        logger.info("handleDrop: \(index) \(rows.count)")
        // 更新排序
        viewModel.updateSortOrderInDBAsync()
    }

    private func contextMenuProvider(item: ProfileModel) -> some View {
        Group {
            Button {
                chooseItem(item: item)
            } label: {
                Label("Choose", systemImage: "checkmark.circle")
            }

            Button {
                self.pingRow = item
            } label: {
                Label("Test Latency", systemImage: "speedometer")
            }

            Divider()

            Button {
                copyItem(item: item)
            } label: {
                Label("Copy URI", systemImage: "doc.on.doc")
            }

            Button {
                self.shareRow = item
            } label: {
                Label("QRCode", systemImage: "qrcode")
            }

            Divider()

            Button(action: {
                moveToTop(item: item)
            }) {
                Label("Move to Top", systemImage: "arrow.up.to.line")
            }

            Button(action: {
                moveToBottom(item: item)
            }) {
                Label("Move to Bottom", systemImage: "arrow.down.to.line")
            }

            Button(action: {
                moveUp(item: item)
            }) {
                Label("Move Up", systemImage: "chevron.up")
            }

            Button(action: {
                moveDown(item: item)
            }) {
                Label("Move Down", systemImage: "chevron.down")
            }

            Divider()

            Button {
                duplicateItem(item: item)
            } label: {
                Label("Duplicate", systemImage: "plus.square.on.square")
            }

            Button {
                self.selectedRow = item
            } label: {
                Label("Edit", systemImage: "pencil")
            }

            Button {
                if showConfirmAlertSync(title: "Are you sure you want to delete this Proxy Profile?", message: "This action cannot be undone.") {
                    viewModel.delete(uuid: item.uuid)
                }
            } label: {
                Label("Delete", systemImage: "trash")
                    .foregroundColor(.red)
            }
        }
    }

    private func chooseItem(item: ProfileModel) {
        // 选择当前配置
        AppState.shared.switchServer(uuid: item.uuid)
    }

    private func duplicateItem(item: ProfileModel) {
        guard let index = viewModel.list.firstIndex(where: { $0.id == item.id }) else { return }
        let newItem = item.clone()
        newItem.index = index + 1 // 设置新的索引
        viewModel.upsert(item: newItem)
        viewModel.updateSortOrderInDBAsync()
    }

    private func copyItem(item: ProfileModel) {
        // 复制到剪贴板
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        let profileString = ShareUri.generateShareUri(item: item)
        if pasteboard.setString(profileString, forType: .string) {
            logger.info("Copied to clipboard: \(profileString)")
            alertDialog(title: "Copied", message: "")
        } else {
            logger.info("Failed to copy to clipboard")
            alertDialog(title: "Failed to copy to clipboard", message: "")
        }
    }

    private func moveToTop(item: ProfileModel) {
        guard let index = viewModel.list.firstIndex(where: { $0.id == item.id }) else { return }
        viewModel.list.remove(at: index)
        viewModel.list.insert(item, at: 0)
        viewModel.updateSortOrderInDBAsync()
    }

    private func moveToBottom(item: ProfileModel) {
        guard let index = viewModel.list.firstIndex(where: { $0.id == item.id }) else { return }
        viewModel.list.remove(at: index)
        viewModel.list.append(item)
        viewModel.updateSortOrderInDBAsync()
    }

    private func moveUp(item: ProfileModel) {
        guard let index = viewModel.list.firstIndex(where: { $0.id == item.id }), index > 0 else { return }
        viewModel.list.swapAt(index, index - 1)
        viewModel.updateSortOrderInDBAsync()
    }

    private func moveDown(item: ProfileModel) {
        guard let index = viewModel.list.firstIndex(where: { $0.id == item.id }), index < viewModel.list.count - 1 else { return }
        viewModel.list.swapAt(index, index + 1)
        viewModel.updateSortOrderInDBAsync()
    }

    private func loadData() {
        viewModel.getList() // Load data when the view appears
    }
}

#Preview {
    ProfileListView()
}
