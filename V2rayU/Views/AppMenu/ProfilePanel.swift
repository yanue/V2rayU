//
//  ProfilePanel.swift
//  V2rayU
//
//  Created by yanue on 2025/1/8.
//

import SwiftUI

// WiFi Panel Component
struct MenuProfilePanel: View {
    @ObservedObject private var appState = AppState.shared // 引用单例
    @StateObject private var viewModel = ProfileViewModel()

    @State var isExpanded: Bool = false
    @State var isEnabled: Bool = false
    @State var searchText: String = ""
    
    var count: Int {
        return filteredAndSortedItems.count
    }
    var name: String {
        return viewModel.list.first(where: { $0.uuid == appState.runningProfile })?.remark ?? ""
    }
    var filteredAndSortedItems: [ProfileModel] {
        let filtered = viewModel.list.filter { item in
            (searchText.isEmpty || item.address.lowercased().contains(searchText.lowercased()) || item.remark.lowercased().contains(searchText.lowercased()))
        }
        // 循环增加序号
        filtered.enumerated().forEach { index, item in
            item.index = index
        }
        return filtered
    }

    var body: some View {
        VStack(spacing: 0) {
            GroupBox("Profiles") {
                Button(action: { withAnimation(.spring()) { isExpanded.toggle() }}) {
                    HStack {
                        HStack(spacing: 12) {
                            Image(systemName: "wifi")
                                .foregroundColor(.white)
                                .frame(width: 16, height: 16)
                                .padding(8)
                                .background(isEnabled ? Color.blue : Color.gray)
                                .clipShape(Circle())
                            
                            VStack(alignment: .leading) {
                                HStack {
                                    Text("Profiles")
                                        .font(.system(size: 13))
                                    Text("(\(count))")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.gray)
                                }
                                Text(name)
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.blue)
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    }
                    .padding(12)
                }
                .contentShape(Rectangle()) // 扩展点击区域
                .buttonStyle(.plain)

                // Expanded WiFi Panel
                if isExpanded {
                    VStack() {
                        // Network List
                        // Bottom Options
                        HStack() {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.white)
                                .frame(width: 16, height: 16)
                            Spacer()
                            TextField("Search by Address or Remark", text: $searchText)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                        .padding(.horizontal,16)
                        .padding(.top,8)
                        Divider()
                        ScrollView {
                            VStack(spacing: 4) {
                                ForEach(filteredAndSortedItems) { item in
                                    MenuProfileRow(item: item, isSelected: item.uuid == appState.runningProfile)
                                        .padding(.horizontal)
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            appState.runProfile(uuid: item.uuid)
                                        }
                                }
                            }
                        }
                        .frame(height:  160)
                        
                    }
                    //                .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(.top, 4)
                }
            }
        }
        .padding(.horizontal, 16)
        .onAppear{
            viewModel.getList()
        }
    }
}


// Supporting Components and Models
struct MenuProfileRow: View {
    let item: ProfileModel
    let isSelected: Bool
    
    var body: some View {
        HStack {
            // Network Icon
            Image(systemName: "wifi")
                .foregroundColor(isSelected ? .blue : .primary)
            
            // Network Name
            Text(item.remark)
                .font(.system(size: 13))
            
            Spacer()
            
            // Connected Check
            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundColor(.blue)
            }
        }
        .padding(.vertical, 6)
    }
}

struct ControlButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(.windowBackground) // macOS 深色模式下接近 GroupBox 背景
            .cornerRadius(8) // 圆角
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.6), lineWidth: 0.4) // 边框样式
            )
            .opacity(configuration.isPressed ? 0.4 : 8.0)

    }
}
