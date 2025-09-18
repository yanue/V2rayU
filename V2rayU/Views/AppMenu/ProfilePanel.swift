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
    @State private var isTransitioning: Bool = false
    
    var count: Int {
        return filteredAndSortedItems.count
    }
    var name: String {
        return appState.runningServer?.remark ?? "No Profile Selected"
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
                // 标题和按钮始终固定
                Button(action: {
                    if isTransitioning { return }
                    isTransitioning = true
                    isExpanded.toggle()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        isTransitioning = false
                    }
                }) {
                    HStack {
                        HStack(spacing: 12) {
                            Image(systemName: "wifi")
                                .foregroundColor(.white)
                                .frame(width: 16, height: 16)
                                .padding(8)
                                .background(appState.v2rayTurnOn ? Color.blue : Color.gray)
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
                    .padding(.horizontal,8)
                    .padding(.vertical,4)
                    .contentShape(Rectangle())
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .buttonStyle(.plain)

                if isExpanded {
                    VStack {
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
                                            AppState.shared.switchServer(uuid: item.uuid)
                                        }
                                }
                            }
                        }
                        .frame(height:  200)
                    }
                    .padding(.top, 4)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .animation(.easeInOut(duration: 0.3), value: isExpanded)
                }
            }
        }
        .id("profile-panel")
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
                .foregroundColor(isSelected ? .blue : .primary)
            
            Spacer()
            
            // Connected Check
            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundColor(.blue)
            }
        }
        .contentShape(Rectangle()) // Ensures full area is tappable
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
