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
    @ObservedObject var settings = AppSettings.shared // 引用单例

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                getTextLabel(label: "Local Socks Listen Port", labelWidth: labelWidth)
                TextField("Local Socks Listen Port", value: $settings.socksPort, formatter: NumberFormatter())
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.leading, 7)
                Spacer()
                getTextLabel(label: "Enable UDP", labelWidth: 100)
                Toggle("", isOn: $settings.enableUdp).frame(alignment: .leading)
                    .toggleStyle(SwitchToggleStyle(tint: .blue))
                    .frame(alignment: .leading)
            }
            getNumFieldWithLabel(label: "Local Http Listen Port", num: $settings.httpPort, labelWidth: labelWidth)
            getNumFieldWithLabel(label: "Local Pac Listen Port", num: $settings.pacPort, labelWidth: labelWidth)
            getBoolFieldWithLabel(label: "Allow LAN", isOn: $settings.allowLAN, labelWidth: labelWidth)
            getBoolFieldWithLabel(label: "Enable Sniffing", isOn: $settings.enableSniffing, labelWidth: labelWidth)
            HStack {
                getBoolFieldWithLabel(label: "Enable Mux", isOn: $settings.enableMux, labelWidth: labelWidth)
                Spacer()
                getNumFieldWithLabel(label: "mux", num: $settings.mux)
            }
            getBoolFieldWithLabel(label: "Enable Traffic Statistics", isOn: $settings.enableStat, labelWidth: labelWidth)
            HStack {
                getTextLabel(label: "V2ray Core Log Level", labelWidth: labelWidth)
                Spacer()
                Picker("", selection: $settings.logLevel) {
                    ForEach(V2rayLogLevel.allCases, id: \.self) { pick in
                        Text(pick.rawValue)
                    }
                }
            }
            HStack {
                Button("保存") {
                    settings.saveSettings()
                }
                Spacer()
            }
        }
        .frame(width: 500, height: 400)
        Spacer()
    }
}
