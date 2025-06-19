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
    @State private var selectGroup: String = ""
    @State private var searchText = ""
    @State private var draggedRow: ProfileModel?
    @State private var selectAll: Bool = false
    @State private var showPingSheet: Bool = false

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
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "shield.lefthalf.filled")
                    .resizable()
                    .frame(width: 28, height: 28)
                    .foregroundColor(.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Proxies")
                        .font(.title)
                        .fontWeight(.bold)
                    Text("Manage your proxy list")
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
                Button(action: { loadData() }) {
                    Label("刷新", systemImage: "arrow.clockwise")
                }
            }
            .padding(.vertical, 6)
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
                        withAnimation {
                            for selectedID in self.selection {
                                viewModel.delete(uuid: selectedID)
                            }
                            selection.removeAll()
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
                        Text(row.`protocol` == .shadowsocks ? "ss" : row.`protocol`.rawValue)
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
        .sheet(item: $selectedRow) { row in
            ConfigFormView(item: row) {
                selectedRow = nil
                loadData()
            }
        }
        .sheet(item: $pingRow) { row in
            ProfilePingView(profile: pingRow, isAll: false) {
                pingRow = nil
            }
        }
        .sheet(isPresented: $showPingSheet) {
            ProfilePingView(profile: nil, isAll: true) {
                showPingSheet = false
            }
        }.task { loadData() }
    }

    // 处理拖拽排序逻辑:
    // 参考: https://levelup.gitconnected.com/swiftui-enable-drag-and-drop-for-table-rows-with-custom-transferable-aa0e6eb9f5ce
    func handleDrop(index: Int, rows: [ProfileModel]) {
        guard let firstRow = rows.first, let firstRemoveIndex = list.firstIndex(where: { $0.id == firstRow.id }) else { return }

        list.removeAll(where: { row in
            rows.contains(where: { insertRow in insertRow.id == row.id })
        })

        list.insert(contentsOf: rows, at: index > firstRemoveIndex ? (index - 1) : index)
    }

    private func contextMenuProvider(item: ProfileModel) -> some View {
        Group {
            Button("Edit") {
                self.selectedRow = item
            }
            Divider()
            Button("Ping") {
                self.pingRow = item
            }
            Button("Delete") {
                // Handle another action
                print("item.uuid", item.id, item.uuid)
                viewModel.delete(uuid: item.uuid)
            }
        }
    }

    private func loadData() {
        viewModel.getList() // Load data when the view appears
    }
}

#Preview {
    ProfileListView()
}
