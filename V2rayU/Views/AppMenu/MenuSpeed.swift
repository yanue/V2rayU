//
//  MenuSpeed.swift
//  V2rayU
//
//  Created by yanue on 2025/1/8.
//

import SwiftUI

// 头部视图组件
struct MenuSpeedView: View {
    @ObservedObject var appState = AppState.shared // 引用单例

    var body: some View {
        HStack (spacing: 8) {
            MenuSpeedItemView(name: "direct", icon: "swift", upSpeed: $appState.directUpSpeed, downSpeed: $appState.directDownSpeed)
                .frame(maxWidth: .infinity)  // 使其占用 50% 宽度

            MenuSpeedItemView(name: "proxy", icon: "swiftdata", upSpeed: $appState.proxyUpSpeed, downSpeed: $appState.proxyDownSpeed)
                .frame(maxWidth: .infinity)  // 使其占用 50% 宽度

        }
        .padding(.horizontal,16)
    }
}

struct MenuSpeedItemView: View {
    var name: String
    var icon: String
    @Binding var upSpeed: Double
    @Binding var downSpeed: Double

    var body: some View {
        GroupBox(name) {
            HStack{
                Text("\(String(format: "%.2f", upSpeed)) KB/s ↑").foregroundStyle(.blue)
                Text("\(String(format: "%.2f", downSpeed)) KB/s ↓").foregroundStyle(.red)
            }
            .font(.system(size: 11))
            .frame(maxWidth: .infinity)  // 确保在其父视图中占据 50% 宽度
        }
    }
}
