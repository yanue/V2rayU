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
                SidebarButton(tab: .server, title: "Proxies", icon: "shield.lefthalf.filled", selectedTab: $selectedTab)
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
                    ProfileListView()
                case .subscription:
                    SubscriptionListView()
                case .routing:
                    RoutingListView()
                case .setting:
                    SettingView()
                }
                Spacer()
            }
            .background() // 先添加背景
            .padding(.all, 16) // 添加内边距
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(NSColor.alternateSelectedControlTextColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.black.opacity(0.2), lineWidth: 1)
                            .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    )
            )
            .padding(.all, 16) // 外边距
            .frame(width: 800) // 设置右侧内容区的宽度
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
