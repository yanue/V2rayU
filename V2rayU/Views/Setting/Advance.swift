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
    private var labelWidth: CGFloat = 240
    @ObservedObject var appState = AppState.shared // 引用单例

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            getTextFieldWithLabel(label: "Local Socks Listen Host", text: $appState.socksHost, labelWidth: labelWidth)
            HStack {
                getTextLabel(label: "Local Socks Listen Port", labelWidth: labelWidth)
                TextField("Local Socks Listen Port", value: $appState.socksPort, formatter: NumberFormatter())
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.leading, 7)
                Spacer()
                getTextLabel(label: "Enable UDP", labelWidth: 100)
                Toggle("", isOn: $appState.enableUdp).frame(alignment: .leading)
                    .toggleStyle(SwitchToggleStyle(tint: .blue))
                    .frame(alignment: .leading)
            }
            getTextFieldWithLabel(label: "Local Http Listen Host", text: $appState.httpHost, labelWidth: labelWidth)
            getNumFieldWithLabel(label: "Local Http Listen Port", num: $appState.httpPort, labelWidth: labelWidth)
            getBoolFieldWithLabel(label: "Enable Sniffing", isOn: $appState.enableSniffing, labelWidth: labelWidth)
            HStack {
                getBoolFieldWithLabel(label: "Enable Mux", isOn: $appState.enableMux, labelWidth: labelWidth)
                Spacer()
                getNumFieldWithLabel(label: "mux", num: $appState.mux)
            }
            getBoolFieldWithLabel(label: "Enable Traffic Statistics", isOn: $appState.enableStat, labelWidth: labelWidth)
            HStack {
                getTextLabel(label: "V2ray Core Log Level", labelWidth: labelWidth)
                Spacer()
                Picker("", selection: $appState.logLevel) {
                    ForEach(V2rayLogLevel.allCases, id: \.self) { pick in
                        Text(pick.rawValue)
                    }
                }
            }
        }
        .frame(width: 500, height: 400)
        Spacer()
    }
}
