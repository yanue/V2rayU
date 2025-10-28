//
//  Config.swift
//  V2rayU
//
//  Created by yanue on 2024/11/23.
//
import SwiftUI
struct ContentView: View {
    @ObservedObject var appState = AppState.shared // 引用单例
    @State private var version = getAppVersion() // 控制设置页面的显示

    // 定义 Tab 枚举
    enum Tab: String, CaseIterable {
        case server
        case subscription
        case routing
        case setting
        case help
        case about
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
                    Text("v"+version).font(.footnote).foregroundColor(.secondary)
                }
                .padding(.vertical,20)

                SidebarButton(tab: .subscription, title: .Subscriptions, icon: "personalhotspot")
                SidebarButton(tab: .server, title: .Servers, icon: "shield.lefthalf.filled")
                SidebarButton(tab: .routing, title: .Routings, icon: "bonjour")
                SidebarButton(tab: .setting, title: .Settings, icon: "gear")
                SidebarButton(tab: .help, title: .Help, icon: "questionmark.circle")
                SidebarButton(tab: .about, title: .About, icon: "info.circle")
                Spacer()
            }
            .frame(width: 160)
            .padding(.leading, 16)
            

            // 右侧内容区，根据选中状态切换
            VStack {
                switch appState.mainTab {
                case .server:
                    ProfileListView()
                case .subscription:
                    SubscriptionListView()
                case .routing:
                    RoutingListView()
                case .setting:
                    SettingView()
                case .help:
                    HelpPageView()
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
            .frame(width: 640) // 设置右侧内容区的宽度
        }
    }
  
    func SidebarButton(tab: Tab, title: LanguageLabel, icon: String) -> some View {
        let isSelected = appState.mainTab == tab
        return Button(action: {
            appState.mainTab = tab
        }) {
            HStack(spacing: 10) { // Adjust spacing between icon and text
                Image(systemName: icon)
                    .frame(width: 20, height: 20) // Consistent icon size
                LocalizedTextLabelView(label:title)
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
