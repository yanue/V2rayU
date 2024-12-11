//
//  Config.swift
//  V2rayU
//
//  Created by yanue on 2024/11/23.
//
import SwiftUI

struct ConfigShowView: View {
    @ObservedObject var item: ProxyModel

    var body: some View {
        HStack {
            VStack {
                Section(header: Text("Outbound Preview")) {
                    JSONTextView(jsonString: item.toJSON())
                }
                Spacer()
            }
            Spacer()
        }
    }
}


#Preview {
    ConfigShowView(item: ProxyModel(protocol: .trojan, address: "dss", port: 443, password: "aaa", security: "auto", remark: "test01"))
}
