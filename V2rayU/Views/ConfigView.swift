//
//  Config.swift
//  V2rayU
//
//  Created by yanue on 2024/11/23.
//
import SwiftUI

struct ConfigView: View {
    @ObservedObject var item: ProxyModel

    var body: some View {
        HStack {
            ConfigFormView(item: item).frame(width: 400) // 左

            Divider().frame(width: 0) // 分隔线，适当调整宽度

            ConfigShowView(item: item) // 右

        }.padding()
            .frame(width: 660)
            .onAppear {
                print("ConfigView appeared with item: \(item.id)")
            }
    }
}

#Preview {
    ConfigView(item: ProxyModel(protocol: .trojan, address: "dss", port: 443, id: "aaa", security: "auto", remark: "test01"))
}
