//
//  LogsPage.swift
//  V2rayU
//
//  Created by yanue on 2025/7/15.
//

import SwiftUI

struct LogPageView: View {
    @ObservedObject var appState = AppState.shared // 引用单例
    @State private var selectedLogTab: String = "App Log" // 新增状态

    var body: some View {
        VStack{
            HStack{
                HStack {
                    Image(systemName: "camera.filters")
                        .resizable()
                        .frame(width: 28, height: 28)
                        .foregroundColor(.accentColor)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Log Viewer")
                            .font(.title)
                            .fontWeight(.bold)
                        Text("App Logs and V2ray Logs")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                // Tabs
                HStack(spacing: 0) {
                    LogTabItem(name: "App Log", selected: selectedLogTab == "App Log") {
                        selectedLogTab = "App Log"
                    }
                    LogTabItem(name: "V2ray Log", selected: selectedLogTab == "V2ray Log") {
                        selectedLogTab = "V2ray Log"
                    }
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 4)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(4)
            }
            .padding()
            Spacer()
            // LogView 切换
            if selectedLogTab == "App Log" {
                LogStreamView(logManager: AppLogStream, title: "App Log")
            } else {
                LogStreamView(logManager: V2rayLogStream, title: "V2ray Log")
            }
        }
        .padding(8)
    }
}


// 新增美观的 TabItem
struct LogTabItem: View {
    var name: String
    var selected: Bool
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(name)
                .font(.subheadline)
                .foregroundColor(selected ? .primary : .gray)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(selected ? Color.gray.opacity(0.15) : Color.clear)
                .cornerRadius(4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
