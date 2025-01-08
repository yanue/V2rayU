//
//  MenuIten.swift
//  V2rayU
//
//  Created by yanue on 2025/1/8.
//

import SwiftUI

struct MenuItemView: View {
    var title: String
    var action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .foregroundColor(isHovered ? .white : .primary)
                Spacer()
            }
            .padding(.horizontal)
            .frame(maxWidth: .infinity, minHeight: 22, alignment: .leading)
            .background(isHovered ? Color.accentColor.opacity(0.8) : Color.clear) // 鼠标悬停高亮
            .cornerRadius(4) // 可选的圆角
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle()) // 去掉默认按钮样式
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
