//
//  Config.swift
//  V2rayU
//
//  Created by yanue on 2024/11/23.
//
import SwiftUI

struct ConfigShowView: View {
    @ObservedObject var item: ProfileModel

    var body: some View {
        HStack {
            VStack {
                Section(header: Text("Outbound Preview")) {
                    JSONTextView(jsonString: ProfileHandler(from: item).toJSON())
                }
                Spacer()
            }
            Spacer()
        }
    }
}


#Preview {
    ConfigShowView(item: ProfileModel(protocol: .trojan, address: "dss", port: 443, password: "aaa", encryption: "auto", remark: "test01"))
}
