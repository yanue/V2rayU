//
//  ShareWindow.swift
//  V2rayU
//
//  Created by yanue on 2025/9/19.
//


import SwiftUI

// MARK: - AppKit 窗口控制
@MainActor
class ShareWindowManager {
    static let shared = ShareWindowManager()
    private var windowController: NSWindowController?
    
    func openShareWindow(item: ProfileModel) {
        // 1. 切回常规模式（显示 Dock 图标、主菜单）
        NSApp.setActivationPolicy(.regular)
        // 2. 激活应用，确保接收键盘事件
        NSApp.activate(ignoringOtherApps: true)

        // 3.1 每次重新构建 SwiftUI 内容视图（确保 onAppear 触发 regenerate）
        let contentView = ShareQrCodeView(profile: item) {
            self.windowController?.close()
        }
            .environment(\.locale, LanguageManager.shared.currentLocale)

        let hostingVC = NSHostingController(rootView: contentView)
        if #available(macOS 13.0, *) {
            // Prevent SwiftUI from animating/resizing the NSWindow in
            // response to transient content-size changes during layout.
            hostingVC.sizingOptions = []
        }

        if let windowController = windowController {
            // 复用窗口：替换 contentViewController
            windowController.window?.contentViewController = hostingVC
        } else {
            // 第一次：初始化自定义窗口
            let window = BaseWindow(
                contentRect: .zero,
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )

            // 3.3 关键：设置代理，触发 windowWillClose 等
            window.delegate = window

            // 3.4 配置窗口内容和大小
            window.contentViewController = hostingVC
            window.setContentSize(NSSize(width: 760, height: 600))
            window.title = "V2rayU"
            window.center()
            window.isReleasedWhenClosed = false

            // 3.5 包装成 NSWindowController
            windowController = NSWindowController(window: window)
        }
        
        // 4. 显示并确保成为 key window
        windowController?.showWindow(nil)
        if let win = windowController?.window {
            win.makeKeyAndOrderFront(nil)
            DispatchQueue.main.async {
                win.orderFrontRegardless()
            }
        }
    }
}
