//
//  Advance.swift
//  V2rayU
//
//  Created by yanue on 2024/12/18.
//
import Foundation
import SwiftUI

struct AdvanceView: View {

    @State private var v2rayShortcut: String = ""
    @State private var proxyModeShortcut: String = ""

    @ObservedObject var appState = AppState.shared // 引用单例

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Form {
                getTextFieldWithLabel(label: "Local Http Listen Host", num: $appState.httpHost)
                getNumFieldWithLabel(label: "Local Http Listen Port", num: $appState.httpPort)
                getTextFieldWithLabel(label: "Local Socks Listen Host", num: $appState.socksHost)
                getNumFieldWithLabel(label: "Local Socks Listen Port", num: $appState.socksPort)
                getBoolFieldWithLabel(label: "Enable UDP", bool: $appState.enableUdp)
                HStack {
                    getBoolFieldWithLabel(label: "Enable Mux", bool: $appState.enableMux)
                    Spacer()
                    getNumFieldWithLabel(label: "mux", num: $appState.mux)
                }
                getBoolFieldWithLabel(label: "Enable Sniffing", bool: $appState.enableSniffing)
                Toggle("Enable Traffic Statistics", isOn: $appState.enableStat)
                getPathFieldWithLabel(label: "V2ray Core Log Level", path: $appState.logLevel)
            }
        }
        .frame(width: 500, height: 400)

    }
}
