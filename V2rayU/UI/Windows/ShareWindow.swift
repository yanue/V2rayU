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
    private var profile: ProfileModel?
    
    func openShareWindow(item: ProfileModel) {
        // 1. 切回常规模式（显示 Dock 图标、主菜单）
        NSApp.setActivationPolicy(.regular)
        // 2. 激活应用，确保接收键盘事件
        NSApp.activate(ignoringOtherApps: true)

        if let existingProfile = profile {
            // 更新数据
            existingProfile.remark = item.remark
            existingProfile.protocol = item.protocol
            existingProfile.address = item.address
            existingProfile.port = item.port
        } else {
            // 第一次创建
            profile = item
        
            // 3.1 构建 SwiftUI 内容视图
            let contentView = ShareQrCodeView(profile: item) {
                self.windowController?.close()
            }
                .environment(\.locale, LanguageManager.shared.currentLocale)
                .environmentObject(AppState.shared)
            
            let hostingVC = NSHostingController(rootView: contentView)

            // 3.2 初始化自定义窗口
            let window = BaseWindow(
                contentRect: .zero,
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )

            // 3.3 关键：设置代理，触发 windowWillClose 等
            window.delegate = window

            // 3.4 配置窗口内容和大小
            window.contentView = hostingVC.view
            window.setContentSize(NSSize(width: 760, height: 600))
            window.title = "V2rayU"
            window.center()
            window.isReleasedWhenClosed = false

            // 3.5 关键：把焦点给 SwiftUI 视图，让 performKeyEquivalent 生效
            window.makeFirstResponder(hostingVC.view)

            // 3.6 包装成 NSWindowController
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
