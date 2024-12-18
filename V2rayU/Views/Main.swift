//
//  Config.swift
//  V2rayU
//
//  Created by yanue on 2024/11/23.
//
import SwiftUI
struct ContentView: View {
    @State private var selectedTab: Tab = .activity // 当前选中的按钮

    // 定义 Tab 枚举
    enum Tab: String {
        case activity
        case server
        case subscription
        case routing
        case setting
    }

    var body: some View {
        HStack {
            // 左侧 Sidebar
            VStack {
                VStack {
                    Image("V2rayU")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 64, height: 64)

                    Text("V2rayU")
                    Text("v5.0.0").font(.footnote).foregroundColor(.secondary)
                }
                .padding(.vertical,20)

                SidebarButton(tab: .activity, title: "Activity", icon: "camera.filters", selectedTab: $selectedTab)
                SidebarButton(tab: .server, title: "proxies", icon: "network.badge.shield.half.filled", selectedTab: $selectedTab)
                SidebarButton(tab: .subscription, title: "Subscription", icon: "personalhotspot", selectedTab: $selectedTab)
                SidebarButton(tab: .routing, title: "Routing", icon: "bonjour", selectedTab: $selectedTab)
                SidebarButton(tab: .setting, title: "Settings", icon: "gear", selectedTab: $selectedTab)

                Spacer()
            }
            .frame(width: 160)
            .padding(.leading, 16)
            

            // 右侧内容区，根据选中状态切换
            VStack {
                switch selectedTab {
                case .activity:
                    ActivityView()
                case .server:
                    ConfigListView()
                case .subscription:
                    SubListView()
                case .routing:
                    RoutingListView()
                case .setting:
                    SettingView()
                }
                Spacer()
            }
            .padding(16)
            .background()
            .padding(.all, 16)
            .frame(width: 600)
        }
    }
  
    func SidebarButton(tab: Tab, title: String, icon: String, selectedTab: Binding<Tab>) -> some View {
        let isSelected = selectedTab.wrappedValue == tab
        return Button(action: {
            selectedTab.wrappedValue = tab
        }) {
            HStack(spacing: 10) { // Adjust spacing between icon and text
                Image(systemName: icon)
                    .frame(width: 20, height: 20) // Consistent icon size
                Text(title)
                    .font(.body) // Adjust font size for better readability
            }
            .frame(maxWidth: .infinity, alignment: .leading) // Align content to the left
            .padding(.vertical, 8) // Adjusted vertical padding for comfortable clicking
            .padding(.horizontal, 10) // Horizontal padding for balance
            .background(isSelected ? Color.blue.opacity(0.2) : Color.clear) // Blue background when selected
            .cornerRadius(6) // Rounded corners for a smoother look
            .contentShape(Rectangle()) // Ensures full area is tappable
            .scaleEffect(isSelected ? 1.05 : 1.0) // Slight scaling effect on selection
            .animation(.easeInOut(duration: 0.2), value: isSelected) // Smooth animation on tap
        }
        .buttonStyle(.plain) // Remove default button styling
    }
}


#Preview {
    ContentView()
}
