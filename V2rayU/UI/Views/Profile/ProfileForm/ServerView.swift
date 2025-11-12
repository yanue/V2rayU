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
                localized(.ServerSettings)
                Spacer()
            }
            .foregroundColor(.primary)
            .padding(.horizontal, 10)
            .font(.title3)

            VStack {
                getTextFieldWithLabel(label: .Remark, text: $item.remark)
                
                // 需要禁用显示: socks, dns, http, blackhole, freedom
                getPickerWithLabel(label: .`Protocol`, selection: $item.protocol,ignore: [.socks, .dns, .http, .blackhole, .freedom])

                if item.protocol == .trojan {
                    getTextFieldWithLabel(label: .Address, text: $item.address)
                    getNumFieldWithLabel(label: .Port, num: $item.port)
                    getTextFieldWithLabel(label: .Password, text: $item.password)
                }

                if item.protocol == .vmess {
                    getTextFieldWithLabel(label: .Address, text: $item.address)
                    getNumFieldWithLabel(label: .Port, num: $item.port)
                    getTextFieldWithLabel(label: .ID, text: $item.password)
                    getNumFieldWithLabel(label: .AlterID, num: $item.alterId)
                    getTextFieldWithLabel(label: .Encryption, text: $item.encryption)
                }

                if item.protocol == .vless {
                    getTextFieldWithLabel(label: .Address, text: $item.address)
                    getNumFieldWithLabel(label: .Port, num: $item.port)
                    getTextFieldWithLabel(label: .ID, text: $item.password)
                    getTextFieldWithLabel(label: .Flow, text: $item.flow)
                    getTextFieldWithLabel(label: .Encryption, text: $item.encryption)
                }

                if item.protocol == .shadowsocks {
                    getTextFieldWithLabel(label: .Address, text: $item.address)
                    getNumFieldWithLabel(label: .Port, num: $item.port)
                    getTextFieldWithLabel(label: .Password, text: $item.password)
                    HStack {
                        getTextLabel(label: .Method)
                        Picker("", selection: $item.encryption) {
                            ForEach(V2rayOutboundShadowsockMethod, id: \.self) { pick in
                                Text(pick)
                            }
                        }
                    }
                }
            }
            .padding() // 1. 内边距
            .background() // 2. 然后背景
            .clipShape(RoundedRectangle(cornerRadius: 8)) // 3. 内圆角
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                    .shadow(color: Color.primary.opacity(0.1), radius: 1, x: 0, y: 1)
            ) // 4. 添加边框和阴影
        }
    }
}

