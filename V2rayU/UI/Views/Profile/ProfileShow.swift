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
                    localized(.Preview)
                    Spacer()
                }
                .foregroundColor(.primary)
                .padding(.horizontal, 10)
                .font(.title3)
                
                JSONTextView(jsonString: V2rayOutboundHandler(from: item).toJSON())
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
}
