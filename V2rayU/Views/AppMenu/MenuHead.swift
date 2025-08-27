//
//  MenuHead.swift
//  V2rayU
//
//  Created by yanue on 2025/1/8.
//

import SwiftUI

// 头部视图组件
struct HeaderView: View {
    @ObservedObject var appState = AppState.shared // 引用单例

    var body: some View {
        VStack {
            HStack {
                Text("v2ray-core ● \(String(format: "%.0f", appState.latency)) ms").foregroundColor(.green)
                Spacer()
                Toggle("", isOn: $appState.v2rayTurnOn)
                    .toggleStyle(SwitchToggleStyle())
                    .onChange(of: appState.v2rayTurnOn) { _, newValue in
                        if newValue {
                            AppState.shared.turnOnCore()
                        } else {
                            AppState.shared.turnOffCore()
                        }
                    }
            }
        }.id("header-view")
    }
}
