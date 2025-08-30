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
                    localized(.Activity)
                        .font(.title)
                        .fontWeight(.bold)
                    localized(.ActivitySubHead)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            HStack{
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
                Spacer()
                HeaderView()
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
            MenuRoutingPanel()
            MenuProfilePanel()
        }
        .padding(8)
    }
}
