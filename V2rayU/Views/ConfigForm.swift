//
//  Config.swift
//  V2rayU
//
//  Created by yanue on 2024/11/23.
//
import SwiftUI

struct ConfigFormView: View {
    @ObservedObject var item: ProxyModel

    var body: some View {
        VStack{
            ConfigServerView(item: item)
            ConfigStreamView(item: item)
            ConfigTransportView(item: item)
        }
    }
}


#Preview {
    ConfigFormView(item: ProxyModel(protocol: .trojan, address: "dss", port: 443, id: "aaa", security: "auto", remark: "test01"))
}
