//
//  StatusItemView.swift
//  V2rayU
//
//  Created by yanue on 2025/11/8.
//

import SwiftUI

// MARK: - 状态栏视图

struct StatusItemView: View {
    @ObservedObject var appState = AppState.shared // 显式使用 ObservedObject
    @ObservedObject var settings = AppSettings.shared // 显式使用 ObservedObject

    var body: some View {
        HStack(alignment: .center, spacing: 4) {
            // 应用图标
            Image(appState.icon)
                .resizable()
                .scaledToFit()
                .frame(width: 18, height: 18)
                .frame(height: 22, alignment: .center) // 确保图标垂直居中
            if settings.showLatencyOnTray {
                HStack(spacing: 4) {
                    Text("●")
                        .font(.system(size: 10))
                        .foregroundColor(Color(appState.v2rayTurnOn ? NSColor.systemGreen : NSColor.systemGray))
                    // 延迟信息
                    Text("\(String(format: "%.0f", appState.latency)) ms")
                        .font(.system(size: 10))
                        .foregroundColor(Color(getSpeedColor(latency: appState.latency))) // 绿色
                }
            }
            if settings.showSpeedOnTray {
                // 速度信息（两行显示）
                VStack(alignment: .leading, spacing: 1) {
                    Text("↓ \(String(format: "%.0f", appState.proxyDownSpeed)) KB/s")
                    Text("↑ \(String(format: "%.0f", appState.proxyUpSpeed)) KB/s")
                }
                .font(.system(size: 9))
                .foregroundColor(.primary)
            }
        }
        .frame(height: 22, alignment: .center) // 固定高度确保居中
        .padding(.horizontal, 4)
        .fixedSize()   // StatusBar自适应关键点: 需要 StatusItemView 设置 fixedSize 配合 statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    }
}

struct CoreStatusItemView: View {
    @ObservedObject var appState = AppState.shared

    var body: some View {
        HStack() {
            HStack(spacing: 0) {
                Image(systemName: appState.v2rayTurnOn ? "wifi" : "wifi.slash")
                    .foregroundColor(Color(appState.v2rayTurnOn ? NSColor.systemGreen : NSColor.systemGray))
                // 延迟信息
                Text(" \(String(format: "%.0f", appState.latency)) ms")
                    .font(.system(size: 11))
                    .foregroundColor(Color(appState.v2rayTurnOn ? getSpeedColor(latency: appState.latency) : .systemGray))
            }
            
            Spacer()
            
            HStack{
                Text("↑ \(String(format: "%.0f", appState.proxyUpSpeed)) KB/s")
                    .font(.system(size: 11))
                    .foregroundColor(Color(appState.v2rayTurnOn ? .systemBlue : .systemGray))

                Text("↓ \(String(format: "%.0f", appState.proxyDownSpeed)) KB/s")
                    .font(.system(size: 11))
                    .foregroundColor(Color(appState.v2rayTurnOn ? .systemRed : .systemGray))
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 22)
    }
}
