//
//  Overview.swift
//  V2rayU
//
//  Created by yanue on 2024/12/17.
//

import SwiftUI

struct ActivityView: View {
    @ObservedObject var appState = AppState.shared
    @State private var selectedLogTab: String = "App Log" // 新增状态

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "camera.filters")
                    .resizable()
                    .frame(width: 28, height: 28)
                    .foregroundColor(.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Activity")
                        .font(.title)
                        .fontWeight(.bold)
                    Text("Activity and Logs")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            // Profile Info Section
            if let profile = appState.runningServer {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current Proxy: \(profile.remark)")
                        .font(.headline)
                    Text("Protocol: \(profile.protocol.rawValue)  |  \(profile.address):\(profile.port)")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .padding(8)
                .background(Color.gray.opacity(0.08))
                .cornerRadius(8)
            } else {
                Text("No active profile.")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }

            // Network Info
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("LATENCY")
                        .font(.caption)
                        .foregroundColor(.green)
                    Text(String(format: "%.0f ms", appState.latency))
                        .font(.headline)
                }
                Spacer()
                VStack(alignment: .leading, spacing: 8) {
                    Text("Proxy UPLOAD")
                        .font(.caption)
                        .foregroundColor(.red)
                    Text(String(format: "%.2f KB/s", appState.proxyUpSpeed))
                        .font(.headline)
                }
                Spacer()
                VStack(alignment: .leading, spacing: 8) {
                    Text("Proxy DOWNLOAD")
                        .font(.caption)
                        .foregroundColor(.brown)
                    Text(String(format: "%.2f KB/s", appState.proxyDownSpeed))
                        .font(.headline)
                }
                Spacer()
                VStack(alignment: .leading, spacing: 8) {
                    Text("Proxy UPLOAD")
                        .font(.caption)
                        .foregroundColor(.pink)
                    Text(String(format: "%.2f KB/s", appState.proxyUpSpeed))
                        .font(.headline)
                }
                Spacer()
                VStack(alignment: .leading, spacing: 8) {
                    Text("Proxy DOWNLOAD")
                        .font(.caption)
                        .foregroundColor(.cyan)
                    Text(String(format: "%.2f KB/s", appState.proxyDownSpeed))
                        .font(.headline)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)

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
            .background(Color.gray.opacity(0.08))
            .cornerRadius(4)
            // LogView 切换
            if selectedLogTab == "App Log" {
                LogView(logManager: AppLogStream, title: "App Log")
            } else {
                LogView(logManager: V2rayLogStream, title: "V2ray Log")
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
                .foregroundColor(selected ? .accentColor : .gray)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(selected ? Color.accentColor.opacity(0.15) : Color.clear)
                .cornerRadius(4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
