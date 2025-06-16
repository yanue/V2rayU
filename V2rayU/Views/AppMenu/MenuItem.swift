//
//  MenuIten.swift
//  V2rayU
//
//  Created by yanue on 2025/1/8.
//

import SwiftUI

struct MenuItemsView: View {
    var openContentViewWindow: () -> Void
    var body: some View {
        GroupBox(""){
            VStack {
                MenuItemView(title: "打开设置", action: openContentViewWindow)
                Divider()
                MenuItemView(title: "Import Server From Pasteboard", action: {
                    Task{
                        if let uri = NSPasteboard.general.string(forType: .string), uri.count > 0 {
                            importUri(url: uri)
                        } else {
                            noticeTip(title: "import server fail", informativeText: "no found vmess:// or vless:// or trojan:// or ss:// from Pasteboard")
                        }
                    }
                })
                Divider()
                MenuItemView(title: "Scan QRCode From Screen", action: {
                    Task{
                        let uri: String = Scanner.scanQRCodeFromScreen()
                        if uri.count > 0 {
                            importUri(url: uri)
                        } else {
                            noticeTip(title: "import server fail", informativeText: "no found qrcode")
                        }
                    }
                })
                Divider()
                MenuItemView(title: "Quit", action: { NSApplication.shared.terminate(nil) })
            }
        }
    }
}

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
        }
        .buttonStyle(PlainButtonStyle()) // 去掉默认按钮样式
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
