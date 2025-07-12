//
//  Stream.swift
//  V2rayU
//
//  Created by yanue on 2024/11/24.
//

import SwiftUI

struct ConfigStreamView: View {
    @ObservedObject var item: ProfileModel

    var body: some View {
        VStack {
            HStack {
                Image(systemName: "waveform.path")
                Text("Stream Settings")
                Spacer()
            }
            .foregroundColor(.primary)
            .padding(.horizontal, 10)
            .font(.title3)
            
            VStack {
                getPickerWithLabel(label: "Network", selection: $item.network)
                if item.network == .tcp  {
                    if item.network == .tcp {
                        getPickerWithLabel(label: "Header Type", selection: $item.headerType)
                    }
                    if item.headerType == .http {
                        getTextFieldWithLabel(label: "Request Host", text: $item.host)
                        getTextFieldWithLabel(label: "Request Path", text: $item.path)
                    }
                }
                
                if item.network == .ws {
                    getTextFieldWithLabel(label: "Request Host", text: $item.host)
                    getTextFieldWithLabel(label: "Request Path", text: $item.path)
                }
                
                if item.network == .h2 {
                    getTextFieldWithLabel(label: "Request Host", text: $item.host)
                    getTextFieldWithLabel(label: "Request Path", text: $item.path)
                }
                
                if item.network == .grpc {
                    getTextFieldWithLabel(label: "Service Name", text: $item.path)
                }
                
                if item.network == .quic {
                    getTextFieldWithLabel(label: "Key", text: $item.path)
                    getPickerWithLabel(label: "Header Type", selection: $item.headerType)
                    getPickerWithLabel(label: "Security", selection: $item.headerType)
                }
                
                if item.network == .domainsocket {
                    getTextFieldWithLabel(label: "Path", text: $item.path)
                }
                
                if item.network == .kcp {
                    getTextFieldWithLabel(label: "Seed", text: $item.path)
                    getPickerWithLabel(label: "Header Type", selection: $item.headerType)
                    getBoolFieldWithLabel(label: "Congestion", isOn: $item.allowInsecure)
                    getNumFieldWithLabel(label: "MTU", num: $item.port)
                    getNumFieldWithLabel(label: "TTI", num: $item.port)
                    getNumFieldWithLabel(label: "Uplink Capacity", num: $item.port)
                    getNumFieldWithLabel(label: "Downlink Capacity", num: $item.port)
                }
                
                if item.network == .xhttp {
                    getTextFieldWithLabel(label: "Path", text: $item.path)
                    getTextFieldWithLabel(label: "Host", text: $item.host)
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

#Preview {
    ConfigStreamView(item: ProfileModel(remark: "test01", protocol: .trojan, address: "dss", port: 443, password: "aaa", encryption: "auto"))
}
