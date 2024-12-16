//
//  Config.swift
//  V2rayU
//
//  Created by yanue on 2024/11/23.
//
import SwiftUI
struct ContentView: View {
    @State private var selectedTab: Tab = .screenshot // 当前选中的按钮

    // 定义 Tab 枚举
    enum Tab: String {
        case screenshot
        case annotate
        case pin
        case pickColor
        case recordScreen
        case recordAudio
        case ocr
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

                SidebarButton(tab: .screenshot, title: "Screenshot", icon: "camera.fill", selectedTab: $selectedTab)
                SidebarButton(tab: .annotate, title: "Annotate", icon: "pencil.tip", selectedTab: $selectedTab)
                SidebarButton(tab: .pin, title: "Pin", icon: "pin.fill", selectedTab: $selectedTab)
                SidebarButton(tab: .pickColor, title: "Pick Color", icon: "eyedropper", selectedTab: $selectedTab)
                SidebarButton(tab: .recordScreen, title: "Record Screen", icon: "record.circle", selectedTab: $selectedTab)
                SidebarButton(tab: .recordAudio, title: "Record Audio", icon: "mic.fill", selectedTab: $selectedTab)
                SidebarButton(tab: .ocr, title: "OCR", icon: "text.viewfinder", selectedTab: $selectedTab)

                Spacer()
            }
            .frame(width: 160)
            .padding(.leading, 16)

            // 右侧内容区，根据选中状态切换
            VStack {
                switch selectedTab {
                case .screenshot:
                    ConfigListView()
                case .annotate:
                    SubListView()
                case .pin:
                    RoutingListView()
                case .pickColor:
                    RoutingListView()
                case .recordScreen:
                    RoutingListView()
                case .recordAudio:
                    RoutingListView()
                case .ocr:
                    RoutingListView()
                }
            }
            .padding(16)
            .background()
            .padding(.all, 16)
        }
    }

    func SidebarButton(tab: Tab, title: String, icon: String, selectedTab: Binding<Tab>) -> some View {
        let isSelected = selectedTab.wrappedValue == tab
        return Button(action: {
            selectedTab.wrappedValue = tab
        }) {
            HStack(spacing: 10) { // Adjust spacing between icon and text
                Image(systemName: icon)
                    .frame(width: 16, height: 16) // Consistent icon size
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
