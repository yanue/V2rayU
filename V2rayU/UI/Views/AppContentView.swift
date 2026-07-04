//
//  AppContentView.swift
//  V2rayU
//
//  Created by yanue on 2024/11/23.
//
import SwiftUI
struct ContentView: View {
    @StateObject private var navigationState = NavigationState.shared
    @State private var version = getAppVersion()
    @State private var alertMessage: String = ""
    @State private var showAlert = false

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
                    .accessibilityIdentifier(ViewAccessibilityIdentifier.sidebarSubscription.rawValue)
                SidebarButton(tab: .server, title: .Servers, icon: "globe")
                    .accessibilityIdentifier(ViewAccessibilityIdentifier.sidebarServer.rawValue)
                SidebarButton(tab: .combination, title: .Combinations, icon: "rectangle.stack.badge.person.crop")
                    .accessibilityIdentifier(ViewAccessibilityIdentifier.sidebarCombination.rawValue)
                SidebarButton(tab: .routing, title: .Routings, icon: "arrow.triangle.branch")
                    .accessibilityIdentifier(ViewAccessibilityIdentifier.sidebarRouting.rawValue)
                SidebarButton(tab: .core, title: .Core, icon: "cpu")
                    .accessibilityIdentifier(ViewAccessibilityIdentifier.sidebarCore.rawValue)
                SidebarButton(tab: .diagnostic, title: .Diagnostics, icon: "exclamationmark.triangle")
                    .accessibilityIdentifier(ViewAccessibilityIdentifier.sidebarDiagnostic.rawValue)
                SidebarButton(tab: .setting, title: .Settings, icon: "gear")
                    .accessibilityIdentifier(ViewAccessibilityIdentifier.sidebarSetting.rawValue)
                SidebarButton(tab: .about, title: .About, icon: "info.circle")
                    .accessibilityIdentifier(ViewAccessibilityIdentifier.sidebarAbout.rawValue)
                Spacer()
            }
            .frame(width: 136)
            .padding(.leading, 24)

            // 右侧内容区，根据选中状态切换
            VStack {
                switch navigationState.mainTab {
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
                case .setting:
                    SettingView()
                case .diagnostic:
                    DiagnosticsView()
                case .about:
                    AboutView()
                }
                Spacer()
            }
            .padding()
            .background()
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                    .shadow(color: Color.primary.opacity(0.1), radius: 1, x: 0, y: 1)
            )
            .padding(.all, 16)
            .frame(minWidth: 640)
        }
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
            .scaleEffect(isSelected ? 1.05 : 1.0) // Slight scaling effect on selection
            .animation(.easeInOut(duration: 0.2), value: isSelected) // Smooth animation on tap
        }
        .buttonStyle(.plain) // Remove default button styling
        .focusable(false)
    }
}
