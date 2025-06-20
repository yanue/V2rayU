//
//  TransportView.swift
//  V2rayU
//
//  Created by yanue on 2024/11/24.
//
import SwiftUI

struct ConfigTransportView: View {
    @ObservedObject var item: ProfileModel

    var body: some View {
        VStack {
            HStack {
                Image(systemName: "lock.shield")
                Text("Transport Settings")
                Spacer()
            }
            .foregroundColor(.primary)
            .padding(.horizontal, 10)
            
            VStack {
                getPickerWithLabel(label: "Security", selection: $item.security)
                getBoolFieldWithLabel(label: "Allow Insecure", isOn: $item.allowInsecure)
                getTextFieldWithLabel(label: "serverName(SNI)", text: $item.sni)
                getPickerWithLabel(label: "Fingerprint", selection: $item.fingerprint)
                if item.security == .reality {
                    getTextFieldWithLabel(label: "Public Key", text: $item.publicKey)
                    getTextFieldWithLabel(label: "Short ID", text: $item.shortId)
                    getTextFieldWithLabel(label: "SpiderX", text: $item.spiderX)
                } else {
                    getPickerWithLabel(label: "ALPN", selection: $item.alpn)
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
    ConfigTransportView(item: ProfileModel(remark: "test01", protocol: .trojan, address: "dss", port: 443, password: "aaa", encryption: "auto"))
}
