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
            
            getTextFieldWithLabel(label: "Remark", text: $item.remark)
        }
        VStack {
            VStack {

                Section(header: Text("Server Settings")) {
                    getPickerWithLabel(label: "Protocol", selection: $item.protocol)
                    if item.protocol == .trojan {
                        getTextFieldWithLabel(label: "address", text: $item.address)
                        getNumFieldWithLabel(label: "port", num: $item.port)
                        getTextFieldWithLabel(label: "password", text: $item.password)
                    }
                    if item.protocol == .vmess {
                        getTextFieldWithLabel(label: "address", text: $item.address)
                        getNumFieldWithLabel(label: "port", num: $item.port)
                        getTextFieldWithLabel(label: "id", text: $item.password)
                        getNumFieldWithLabel(label: "alterId", num: $item.alterId)

                        HStack {
                            getTextLabel(label: "encryption")
                            Spacer()
                            Picker("", selection: $item.encryption) {
                                ForEach(V2rayProtocolOutbound.allCases) { pick in
                                    Text(pick.rawValue)
                                }
                            }
                        }
                    }
                    if item.protocol == .vless {
                        getTextFieldWithLabel(label: "address", text: $item.address)
                        getNumFieldWithLabel(label: "port", num: $item.port)
                        getTextFieldWithLabel(label: "id", text: $item.password)
                        getTextFieldWithLabel(label: "flow", text: $item.flow)
                        HStack {
                            getTextLabel(label: "encryption")
                            Spacer()
                            Picker("", selection: $item.encryption) {
                                ForEach(V2rayProtocolOutbound.allCases) { pick in
                                    Text(pick.rawValue)
                                }
                            }
                        }
                    }
                }
                if item.protocol == .shadowsocks {
                    getTextFieldWithLabel(label: "address", text: $item.address)
                    getNumFieldWithLabel(label: "port", num: $item.port)
                    getTextFieldWithLabel(label: "password", text: $item.password)
                    HStack {
                        getTextLabel(label: "method")
                        Picker("", selection: $item.encryption) {
                            ForEach(V2rayProtocolOutbound.allCases) { pick in
                                Text(pick.rawValue)
                            }
                        }
                    }
                }
            }
        }
        .padding(20)
        .border(Color.white, width: 1) // 黑色边框，宽度为 2

        Spacer()
    }
}

#Preview {
    ConfigServerView(item: ProfileModel(remark: "test01", protocol: .trojan, address: "dss", port: 443, password: "aaa", encryption: "auto"))
}
