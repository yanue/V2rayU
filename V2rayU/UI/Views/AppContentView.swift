//
//  Config.swift
//  V2rayU
//
//  Created by yanue on 2024/11/23.
//
import SwiftUI
struct ContentView: View {
    @StateObject private var navigationState = NavigationState.shared
    @State private var version = getAppVersion() // 控制设置页面的显示

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
                    Text("v"+version).font(.footnote).foregroundColor(.secondary)
                }
                .padding(.vertical, 20)

                SidebarButton(tab: .subscription, title: .Subscriptions, icon: "link.circle")
                SidebarButton(tab: .server, title: .Servers, icon: "globe")
                SidebarButton(tab: .routing, title: .Routings, icon: "arrow.triangle.branch")
                SidebarButton(tab: .setting, title: .Settings, icon: "gear")
                SidebarButton(tab: .diagnostic, title: .Diagnostics, icon: "antenna.radiowaves.left.and.right")
                SidebarButton(tab: .about, title: .About, icon: "info.circle")
                Spacer()
            }
            .frame(width: 136)
            .padding(.leading, 24)
            

            // 右侧内容区，根据选中状态切换
            VStack {
                switch navigationState.mainTab {
                case .server:
                    ProfileListView()
                case .subscription:
                    SubscriptionListView()
                case .routing:
                    RoutingListView()
                case .setting:
                    SettingView()
                case .diagnostic:
                    DiagnosticsView()
                case .about:
                    AboutView()
                }
                Spacer()
            }
            .padding() // 1. 内边距
            .background() // 2. 然后背景
            .clipShape(RoundedRectangle(cornerRadius: 10)) // 3. 内圆角
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                    .shadow(color: Color.primary.opacity(0.1), radius: 1, x: 0, y: 1)
            ) // 4. 添加边框和阴影
            .padding(.all, 16) // 5. 外边距
            .frame(minWidth: 640) // 设置右侧内容区的宽度
        }
        .frame(minWidth: 760, minHeight: 600, maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
  
    func SidebarButton(tab: MainTab, title: LanguageLabel, icon: String) -> some View {
        let isSelected = navigationState.mainTab == tab
        return Button(action: {
            navigationState.mainTab = tab
        }) {
            HStack(spacing: 10) { // Adjust spacing between icon and text
                Image(systemName: icon)
                    .frame(width: 20, height: 20) // Consistent icon size
                LocalizedTextLabelView(label:title)
                    .font(.callout) // Adjust font size for better readability
            }
            .frame(maxWidth: .infinity, alignment: .leading) // Align content to the left
            .padding(.vertical, 8) // Adjusted vertical padding for comfortable clicking
            .padding(.horizontal, 10) // Horizontal padding for balance
            .background(isSelected ? Color.accentColor.opacity(0.4) : Color.clear)
            .cornerRadius(6) // Rounded corners for a smoother look
            .contentShape(Rectangle()) // Ensures full area is tappable
        }
        .buttonStyle(.plain) // Remove default button styling
        .focusable(false)
    }
}
