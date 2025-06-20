//
//  ServerView.swift
//  V2rayU
//
//  Created by yanue on 2024/11/24.
//

import SwiftUI

struct ConfigServerView: View {
    @ObservedObject var item: ProfileModel

    var body: some View {
        VStack {
            HStack {
                Image(systemName: "server.rack")
                Text("Server Settings")
                Spacer()
            }
            .foregroundColor(.primary)
            .padding(.horizontal, 10)

            VStack {
                getTextFieldWithLabel(label: "Remark", text: $item.remark)
                
                // 需要禁用显示: socks, dns, http, blackhole, freedom
                getPickerWithLabel(label: "Protocol", selection: $item.protocol,ignore: [.socks, .dns, .http, .blackhole, .freedom])

                if item.protocol == .trojan {
                    getTextFieldWithLabel(label: "Address", text: $item.address)
                    getNumFieldWithLabel(label: "Port", num: $item.port)
                    getTextFieldWithLabel(label: "Password", text: $item.password)
                }

                if item.protocol == .vmess {
                    getTextFieldWithLabel(label: "Address", text: $item.address)
                    getNumFieldWithLabel(label: "Port", num: $item.port)
                    getTextFieldWithLabel(label: "ID", text: $item.password)
                    getNumFieldWithLabel(label: "Alter ID", num: $item.alterId)
                    getTextFieldWithLabel(label: "Encryption", text: $item.encryption)
                }

                if item.protocol == .vless {
                    getTextFieldWithLabel(label: "Address", text: $item.address)
                    getNumFieldWithLabel(label: "Port", num: $item.port)
                    getTextFieldWithLabel(label: "ID", text: $item.password)
                    getTextFieldWithLabel(label: "Flow", text: $item.flow)
                    getTextFieldWithLabel(label: "Encryption", text: $item.encryption)
                }

                if item.protocol == .shadowsocks {
                    getTextFieldWithLabel(label: "Address", text: $item.address)
                    getNumFieldWithLabel(label: "Port", num: $item.port)
                    getTextFieldWithLabel(label: "Password", text: $item.password)
                    HStack {
                        getTextLabel(label: "Method")
                        Picker("", selection: $item.encryption) {
                            ForEach(V2rayOutboundShadowsockMethod, id: \.self) { pick in
                                Text(pick)
                            }
                        }
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(NSColor.alternateSelectedControlTextColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.black.opacity(0.2), lineWidth: 1)
                            .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    )
            )
        }
    }
}

#Preview {
    ConfigServerView(item: ProfileModel(remark: "test01", protocol: .trojan, address: "dss", port: 443, password: "aaa", encryption: "auto"))
}
