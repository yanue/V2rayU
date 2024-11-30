//
//  TransportView.swift
//  V2rayU
//
//  Created by yanue on 2024/11/24.
//
import SwiftUI


struct ConfigTransportView: View {
    @ObservedObject var item: ProxyModel
    var body: some View{
        HStack {
            VStack{
                Section(header: Text("Transport Settings")) {
                    getPickerWithLabel(label: "Security", selection: $item.streamSecurity)
                    getBoolWithLabel(label: "allowInsecure", isOn: $item.allowInsecure)
                    getTextFieldWithLabel(label: "serverName(SNI)", text: $item.sni)
                    getPickerWithLabel(label: "fingerprint", selection: $item.fingerprint)
                    if item.streamSecurity == .reality {
                        getTextFieldWithLabel(label: "PublicKey", text: $item.publicKey)
                        getTextFieldWithLabel(label: "ShortId", text: $item.shortId)
                        getTextFieldWithLabel(label: "spiderX", text: $item.spiderX)
                    } else {
                        getPickerWithLabel(label: "alpn", selection: $item.alpn)
                    }
                }
            }
        }
        .padding(20)
        .border(Color.secondary, width: 1) // 黑色边框，宽度为 2

        Spacer()
    }
}


#Preview {
    ConfigTransportView(item: ProxyModel(protocol: .trojan, address: "dss", port: 443, id: "aaa", security: "auto", remark: "test01"))
}
