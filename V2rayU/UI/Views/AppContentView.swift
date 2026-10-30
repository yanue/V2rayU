//
//  AppContentView.swift
//  V2rayU
//
//  Created by yanue on 2024/11/23.
//
import SwiftUI
struct ContentView: View {
    @ObservedObject private var navigationState = NavigationState.shared
    @State private var version = getAppVersion()
    @State private var alertMessage: String = ""
    @State private var showAlert = false

    var body: some View {
        HStack(spacing: 0) {
            // 左侧 Sidebar
            VStack {
                HStack(spacing: 8) {
                    Image("V2rayU")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 36, height: 36)
                    VStack(alignment: .leading, spacing: 0) {
                        Text("V2rayU").font(.headline)
                        Text("v"+version).font(.caption2).foregroundColor(.secondary)
                    }
                    Spacer()
                }
                // 顶部让出红绿灯的位置; 左边和下面菜单的图标对齐
                .padding(.top, 60)
                .padding(.bottom, 4)
                .padding(.leading, 10)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 2) {
                        SidebarSection(.SidebarGroupActivity)
                        SidebarButton(tab: .status, title: .Overview, icon: "gauge.with.dots.needle.33percent")
                            .accessibilityIdentifier(ViewAccessibilityIdentifier.sidebarStatus.rawValue)
                        SidebarButton(tab: .connections, title: .Connections, icon: "point.3.connected.trianglepath.dotted")
                            .accessibilityIdentifier(ViewAccessibilityIdentifier.sidebarConnections.rawValue)
                        SidebarButton(tab: .logs, title: .Logs, icon: "doc.text.magnifyingglass")
                            .accessibilityIdentifier(ViewAccessibilityIdentifier.sidebarLogs.rawValue)
                        SidebarButton(tab: .diagnostic, title: .Diagnostics, icon: "stethoscope")
                            .accessibilityIdentifier(ViewAccessibilityIdentifier.sidebarDiagnostic.rawValue)

                        SidebarSection(.SidebarGroupProxy)
                        SidebarButton(tab: .server, title: .Servers, icon: "globe")
                            .accessibilityIdentifier(ViewAccessibilityIdentifier.sidebarServer.rawValue)
                        SidebarButton(tab: .subscription, title: .Subscriptions, icon: "link.circle")
                            .accessibilityIdentifier(ViewAccessibilityIdentifier.sidebarSubscription.rawValue)
                        SidebarButton(tab: .combination, title: .Combinations, icon: "rectangle.stack.badge.person.crop")
                            .accessibilityIdentifier(ViewAccessibilityIdentifier.sidebarCombination.rawValue)
                        SidebarButton(tab: .routing, title: .Routings, icon: "arrow.triangle.branch")
                            .accessibilityIdentifier(ViewAccessibilityIdentifier.sidebarRouting.rawValue)

                        SidebarSection(.SidebarGroupSystem)
                        SidebarButton(tab: .core, title: .Core, icon: "cpu")
                            .accessibilityIdentifier(ViewAccessibilityIdentifier.sidebarCore.rawValue)
                        SidebarButton(tab: .setting, title: .Settings, icon: "gear")
                            .accessibilityIdentifier(ViewAccessibilityIdentifier.sidebarSetting.rawValue)
                        SidebarButton(tab: .about, title: .About, icon: "info.circle")
                            .accessibilityIdentifier(ViewAccessibilityIdentifier.sidebarAbout.rawValue)
                    }
                }
                Spacer()
            }
            .frame(width: 160)
            .padding(.leading, 24)
            .padding(.trailing, 12)

            // 侧边栏和内容区之间一条浅色竖线; 系统 Divider 在深色模式下太显眼
            Rectangle()
                .fill(Color.secondary.opacity(0.12))
                .frame(width: 1)

            // 右侧内容区，根据选中状态切换
            VStack {
                switch navigationState.mainTab {
                case .status:
                    StatusView()
                case .server:
                    ProfileListView()
                case .combination:
                    CombinedConfigListView()
                case .subscription:
                    SubscriptionListView()
                case .routing:
                    RoutingListView()
                case .core:
                    CoreView()
                case .connections:
                    ConnectionsView()
                case .logs:
                    LogView()
                case .diagnostic:
                    DiagnosticsView()
                case .setting:
                    SettingView()
                case .about:
                    AboutView()
                }
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 20)
            .padding(.bottom)
            // 内容区铺满右侧, 不加圆角卡片; 也别裁剪, 外层有裁剪时(clipShape/cornerRadius)列表的拖动排序放不下去
            .background(.background)
            .frame(minWidth: 640)
        }
        // 窗口用了 fullSizeContentView, 不让出标题栏的高度
        .ignoresSafeArea()
        .alert(String(localized: .DownloadHint), isPresented: $showAlert) {
            Button(String(localized: .Confirm)) { }
        } message: {
            Text(alertMessage)
        }
        .onReceive(CoreViewModel.shared.$showAlert) { shouldShow in
            if shouldShow {
                alertMessage = CoreViewModel.shared.errorMsg
                showAlert = true
                CoreViewModel.shared.showAlert = false
            }
        }
    }
  
    /// 侧边栏分组小标题
    func SidebarSection(_ title: LanguageLabel) -> some View {
        Text(String(localized: title))
            .font(.caption2.weight(.semibold))
            .foregroundColor(.secondary)
            .padding(.top, 12)
            .padding(.bottom, 2)
            .padding(.leading, 10)
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
                    .font(.body)
            }
            .frame(maxWidth: .infinity, alignment: .leading) // Align content to the left
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(isSelected ? Color.accentColor.opacity(0.3) : Color.clear)
            .cornerRadius(6)
            .contentShape(Rectangle()) // Ensures full area is tappable
            .animation(.easeInOut(duration: 0.15), value: isSelected)
        }
        .buttonStyle(.plain) // Remove default button styling
        .focusable(false)
    }
}
