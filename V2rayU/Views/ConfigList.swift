//
//  ConfigList.swift
//  V2rayU
//
//  Created by yanue on 2024/11/30.
//

import SwiftUI

struct ConfigListView: View {
    let list = [
        ProxyModel(protocol: .trojan, address: "dss111", port: 443, id: "aaa", security: "auto2", remark: "test01"),
        ProxyModel(protocol: .trojan, address: "dss222", port: 443, id: "bbbs", security: "auto1", remark: "test02"),
    ]

    @State private var sortOrder: [KeyPathComparator<ProxyModel>] = []
    @State private var showDetails = false // Whether to show the detail view
    @State private var selection: Set<ProxyModel.ID> = []
    @State private var searchText = ""
    @State private var selectedProxy: ProxyModel? = nil // For holding selected ProxyModel for detail view

    var body: some View {
        let filteredItems = list.filter { item in
            searchText.isEmpty || item.address.lowercased().contains(searchText.lowercased()) ||
                item.id.lowercased().contains(searchText.lowercased()) ||
                item.remark.lowercased().contains(searchText.lowercased())
        }

        Table(filteredItems, selection: $selection, sortOrder: $sortOrder) {
            TableColumn("Address", value: \.address)
            TableColumn("Id", value: \.id)
            TableColumn("Path", value: \.path)
            TableColumn("Remark", value: \.remark)
            TableColumn("Security", value: \.security)
        }
        .searchable(text: $searchText, prompt: "Search by Address, Id & Remark")
        .contextMenu(forSelectionType: ProxyModel.ID.self) { _ in
            // Add custom context menu items here if needed
        } primaryAction: { items in
            // This is executed when the row is double-clicked
            if let selectedItem = items.first {
                if let proxy = list.first(where: { $0.id == selectedItem }) {
                    self.selectedProxy = proxy // Set the selected ProxyModel
                    self.showDetails = true // Show the details view
                    print("primaryAction", proxy.id, self.showDetails)
                }
            }
        }

        .onChange(of: sortOrder) { newOrder in
            print("Sort order changed: \(newOrder)")
        }

        .onChange(of: showDetails) { newValue in
            print("showDetails changed: \(newValue)")
        }

        .sheet(isPresented: $showDetails) {
            if let proxy = selectedProxy {
                VStack {
                    Button("Close") {
                        showDetails.toggle() // 关闭模态视图
                    }.padding()
                    ConfigView(item: proxy)
                        .padding()
                        .presentationDetents([.large])
                   
                }
            }
        }
    }
}

struct ArticlesView: View {
    @State var shouldPresentSheet = false

    var body: some View {
        VStack {
            Button("Present Sheet") {
                shouldPresentSheet.toggle()
            }
            /// Present a sheet once `shouldPresentSheet` becomes `true`.
            .sheet(isPresented: $shouldPresentSheet) {
                print("Sheet dismissed!")
            } content: {
            }
        }
        .padding()
        .frame(width: 400, height: 300)
    }
}

#Preview {
    ConfigListView()
}
