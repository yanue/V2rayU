//
//  Stream.swift
//  V2rayU
//
//  Created by yanue on 2024/11/24.
//

import SwiftUI

struct ConfigStreamView: View {
    @ObservedObject var item: ProxyModel
    
    var body: some View {
        HStack {
            VStack {
                Section(header: Text("Stream Settings")) {
                    getPickerWithLabel(label: "Network", selection: $item.network)
                    if item.network == .tcp || item.network == .ws || item.network == .h2  || item.network == .http {
                        if item.network == .tcp || item.network == .http {
                            getPickerWithLabel(label: "header type", selection: $item.headerType)
                        }
                        getTextFieldWithLabel(label: "request host",text: $item.requestHost)
                        getTextFieldWithLabel(label: "request path",text: $item.path)
                    }
                    if item.network == .grpc {
                        getTextFieldWithLabel(label: "serviceName",text: $item.path)
                    }
                    if item.network == .quic {
                        getTextFieldWithLabel(label: "Key",text: $item.path)
                        getPickerWithLabel(label: "header type", selection: $item.headerType)
                        getPickerWithLabel(label: "security", selection: $item.headerType)
                    }
                    if item.network == .domainsocket {
                        getTextFieldWithLabel(label: "path",text: $item.path)
                    }
                    if item.network == .kcp {
                        getTextFieldWithLabel(label: "seed",text: $item.path)
                        getPickerWithLabel(label: "header-type", selection: $item.headerType)
                        getBoolWithLabel(label: "congestion", isOn: $item.allowInsecure)
                        getNumFieldWithLabel(label: "mtu", num: $item.port)
                        getNumFieldWithLabel(label: "tti", num: $item.port)
                        getNumFieldWithLabel(label: "uplinkCapacity", num: $item.port)
                        getNumFieldWithLabel(label: "downlinkCapacity", num: $item.port)
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
    ConfigStreamView(item: ProxyModel(protocol: .trojan, address: "dss", port: 443, id: "aaa", security: "auto", remark: "test01"))
}
