//
//  Overview.swift
//  V2rayU
//
//  Created by yanue on 2024/12/17.
//

import SwiftUI

struct ActivityView: View {
    @ObservedObject var appState = AppState.shared

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
                    Text("匹配优先级: 域名阻断 -> 域名代理 -> 域名直连 -> IP阻断 -> IP代理 -> IP直连")
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
                    Text("Speed: \(profile.speed >= 0 ? "\(profile.speed) ms" : "N/A")")
                        .font(.subheadline)
                        .foregroundColor(.orange)
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
                        .foregroundColor(.blue)
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
                        .foregroundColor(.blue)
                    Text(String(format: "%.2f KB/s", appState.proxyDownSpeed))
                        .font(.headline)
                }
                Spacer()
                VStack(alignment: .leading, spacing: 8) {
                    Text("LATENCY")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text(String(format: "%.2f ms", appState.latency))
                        .font(.headline)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)

            // Tabs
            HStack {
                TabItem(name: "Latency", selected: true)
                TabItem(name: "Traffic", selected: false)
                TabItem(name: "Interfaces", selected: false)
            }
            // Event Log
            LogView(logManager: .init(filePath: appLogFilePath, maxLines: 20, parse: { GenericLogLine(raw: $0) }), title: "App Log")
            LogView(logManager: .init(filePath: v2rayLogFilePath, maxLines: 20, parse: { GenericLogLine(raw: $0) }), title: "V2ray Log")
        }
        .padding(8)
    }
}

// Subviews

struct TabItem: View {
    var name: String
    var selected: Bool

    var body: some View {
        Text(name)
            .font(.subheadline)
            .foregroundColor(selected ? .black : .gray)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(selected ? Color.gray.opacity(0.2) : Color.clear)
            .cornerRadius(8)
    }
}

struct CardView: View {
    var title: String
    var value: String
    var unit: String
    var color: Color

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Spacer()

                Text(title)
                    .font(.caption)
                    .foregroundColor(color)

                Spacer()
            }
            HStack {
                Spacer()
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                Text(unit)
                    .font(.caption)
                Spacer()
            }
        }
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(10)
    }
}
