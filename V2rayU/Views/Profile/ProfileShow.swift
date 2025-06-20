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
                HStack {
                    Image(systemName: "waveform.path")
                    Text("Outbound Preview")
                    Spacer()
                }
                .foregroundColor(.primary)
                .padding(.horizontal, 10)
                
                JSONTextView(jsonString: V2rayOutboundHandler(from: item).toJSON())
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
}


#Preview {
    ConfigShowView(item: ProfileModel(remark: "test01", protocol: .trojan, address: "dss", port: 443, password: "aaa", encryption: "auto"))
}
