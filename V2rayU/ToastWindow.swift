//
//  ToastWindowController.swift
//  ShadowsocksX-NG
//
//  Created by 邱宇舟 on 2017/3/20.
//  Copyright © 2017年 qiuyuzhou. All rights reserved.
//

import Cocoa
import SwiftUI

func alertDialog(title: String, message: String) {
    DispatchQueue.main.async {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        let response = alert.runModal()
        
        if response == .alertFirstButtonReturn {
            print("OK clicked")
        } else {
            print("Cancel clicked")
        }
    }
}

func makeToast(message: String, displayDuration: Double? = 3) {
    // 确保调用 makeToast 时在主线程上
    DispatchQueue.main.async {
        // 错误处理
        ToastManager.shared.makeToast(message: message, displayDuration: displayDuration ?? 3)
    }
}

// 将 ToastManager 类标记为 @MainActor，确保线程安全
@MainActor
class ToastManager {
    static let shared = ToastManager()
    private init() {}

    private var popover: NSPopover?

    // 显示 Toast 的方法
    func makeToast(message: String, displayDuration: Double = 3) {
        self.showPopover(message: message, displayDuration: displayDuration)
    }

    // 显示 Popover
    private func showPopover(message: String, displayDuration: Double) {
        // 创建 Toast 的视图
        let toastView = ToastView(message: message)

        // 使用 NSHostingView 包装 SwiftUI 视图
        let hostingView = NSHostingView(rootView: toastView)

        // 创建 Popover 并设置其内容视图控制器
        let popover = NSPopover()
        popover.contentSize = NSSize(width: 200, height: 50)  // 定制大小
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = NSViewController()
        popover.contentViewController?.view = hostingView  // 设置为 NSHostingView

        // 设置 Popover 的透明效果
        popover.appearance = NSAppearance(named: .vibrantLight)

        // 获取菜单栏图标的位置，并在其下方显示 Popover
        if let button = NSApp.keyWindow?.contentView?.superview {
            print("button",button)
            _ = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength).length
            let menuBarFrame = button.frame
            let position = CGPoint(x: menuBarFrame.origin.x + (menuBarFrame.size.width / 2), y: menuBarFrame.origin.y)

            popover.show(relativeTo: NSRect(x: position.x, y: position.y, width: 0, height: 0), of: button, preferredEdge: .minY)
        }

        // 显示完毕后，自动隐藏
        DispatchQueue.main.asyncAfter(deadline: .now() + displayDuration) {
            popover.performClose(nil)
        }

        self.popover = popover
    }
}

// Toast 的视图内容
struct ToastView: View {
    var message: String

    var body: some View {
        Text(message)
            .padding()
            .background(Color.black.opacity(0.8))
            .cornerRadius(10)
            .foregroundColor(.white)
            .font(.body)
    }
}
