//
//  ConfigList.swift
//  V2rayU
//
//  Created by yanue on 2024/11/30.
//

import SwiftUI

struct ConfigListView: View {
    @State private var list: [ProxyModel] = []
    @State private var sortOrder: [KeyPathComparator<ProxyModel>] = []
    @State private var selection: Set<ProxyModel.ID> = []
    @State private var selectedProxy: ProxyModel? = nil
    @State private var selectGroup: GroupModel = defaultGroup
    @State private var groups: [GroupModel] = []
    @State private var searchText = ""

    var filteredAndSortedItems: [ProxyModel] {
        let filtered = list.filter { item in
            (selectGroup.group == "" || selectGroup.group == item.subid) &&
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
        VStack {
            HStack {
                Picker("选择组", selection: $selectGroup) {
                    ForEach(groups) { group in // 使用 groups 数组并遍历
                        Text(group.name).tag(group as GroupModel) // 使用 .tag 来绑定选中的项
                    }
                }
                .pickerStyle(MenuPickerStyle()) // 可根据需要选择不同的 Picker 样式
                .padding()

                Text("搜索")
                TextField("Search by Address or Remark", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())

                Button("刷新") {
                    withAnimation {
                        loadData()
                    }
                }
                Button("Ping") {
                    withAnimation {
                    }
                }

                Button("删除") {
                    withAnimation {
                        list.removeAll { selection.contains($0.id) }
                        selection.removeAll()
                    }
                }
                .disabled(selection.isEmpty)

                Button("新增") {
                    withAnimation {
                        let newProxy = ProxyModel(protocol: .trojan, address: "newAddress", port: 443, id: UUID().uuidString, security: "auto", remark: "New Remark")
                        list.append(newProxy)
                    }
                }
            }

            Table(filteredAndSortedItems, selection: $selection, sortOrder: $sortOrder) {
                TableColumn("#") { item in
                    Text("\(item.index + 1)") // 显示 1-based 索引
                }
                .width(30)
                TableColumn("Type", value: \.`protocol`.rawValue)
                TableColumn("Remark", value: \.remark)
                TableColumn("Address", value: \.address)
                TableColumn("Port", value: \.port.description)
                TableColumn("Network", value: \.network.rawValue)
                TableColumn("TLS", value: \.streamSecurity.rawValue)
            }
            .contextMenu(forSelectionType: ProxyModel.ID.self) { items in
                if let selectedItem = items.first {
                    contextMenuProvider(item: selectedItem)
                }
            }
        }
        .sheet(item: $selectedProxy) { proxy in
            VStack {
                Button("Close") {
                    // 如果需要关闭 `sheet`，将 `selectedProxy` 设置为 `nil`
                    selectedProxy = nil
                }
                ConfigView(item: proxy)
                    .padding()
            }
        }
        .task {
            loadData()
        }
    }

    private func contextMenuProvider(item: ProxyModel.ID) -> some View {
        Group {
            if let proxy = list.first(where: { $0.id == item }) {
                Button("Edit") {
                    self.selectedProxy = proxy
                }
            }

            Divider()

            Button("Ping") {
                // Handle ping action
            }

            Button("Action 3") {
                // Handle another action
            }
        }
    }

    private func loadData() {
        // Simulate data fetching
        let fetchedData = [
            ProxyModel(protocol: .trojan, address: "dss111", port: 443, id: "aaa", security: "auto2", remark: "testa01"),
            ProxyModel(protocol: .trojan, address: "dss222", port: 443, id: "bbbs", security: "auto1", remark: "testb02"),
        ]
        let groupsData = [
            defaultGroup,
            GroupModel(name: "Yanue", group: "yanue"),
        ]
        withAnimation {
            list = fetchedData
            groups = groupsData
        }
    }
}

#Preview {
    ConfigListView()
}
