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
                getTextLabel(label: .LocalSocksListenPort, labelWidth: labelWidth)
                TextField(String(localized: .LocalSocksListenPort), value: $settings.socksPort, formatter: NumberFormatter())
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.leading, 7)
                Spacer()
                getTextLabel(label: .EnableUDP, labelWidth: 100)
                Toggle("", isOn: $settings.enableUdp).frame(alignment: .leading)
                    .toggleStyle(SwitchToggleStyle(tint: .blue))
                    .frame(alignment: .leading)
            }
            getNumFieldWithLabel(label: .LocalHttpListenPort, num: $settings.httpPort, labelWidth: labelWidth)
            getNumFieldWithLabel(label: .LocalPacListenPort, num: $settings.pacPort, labelWidth: labelWidth)
            getBoolFieldWithLabel(label: .AllowLAN, isOn: $settings.allowLAN, labelWidth: labelWidth)
            getBoolFieldWithLabel(label: .EnableSniffing, isOn: $settings.enableSniffing, labelWidth: labelWidth)
            HStack {
                getBoolFieldWithLabel(label: .EnableMux, isOn: $settings.enableMux, labelWidth: labelWidth)
                Spacer()
                getNumFieldWithLabel(label: .Mux, num: $settings.mux)
            }
            getBoolFieldWithLabel(label: .EnableTrafficStatistics, isOn: $settings.enableStat, labelWidth: labelWidth)
            HStack {
                getTextLabel(label: .V2rayCoreLogLevel, labelWidth: labelWidth)
                Spacer()
                Picker("", selection: $settings.logLevel) {
                    ForEach(V2rayLogLevel.allCases, id: \ .self) { pick in
                        Text(pick.rawValue)
                    }
                }
            }
            HStack {
                Button(String(localized: .Save)) {
                    settings.saveSettings()
                }
                Spacer()
            }
        }
        .frame(width: 500, height: 400)
        Spacer()
    }
}
