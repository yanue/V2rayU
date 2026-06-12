//
//  MainWindow.swift
//  V2rayU
//
//  Created by yanue on 2025/9/19.
//

import SwiftUI

// MARK: - AppKit 窗口控制
@MainActor

class MainWindowManager {
    static let shared = MainWindowManager()
    private var windowController: NSWindowController?

    var mainWindow: NSWindow? { windowController?.window }
    
    public func openMainWindow() {
        // 1. 切回常规模式（显示 Dock 图标、主菜单）
        NSApp.setActivationPolicy(.regular)

        // 2. 如果还没创建 windowController，就初始化
        if windowController == nil {
            // 2.1 构建 SwiftUI 内容视图
            let contentView = ContentView()
                .environment(\.locale, LanguageManager.shared.currentLocale)
            let hostingVC = NSHostingController(rootView: contentView)
            if #available(macOS 13.0, *) {
                // Prevent SwiftUI from animating/resizing the NSWindow in
                // response to transient content-size changes during layout.
                hostingVC.sizingOptions = []
            }

            // 2.2 初始化自定义窗口
            let window = BaseWindow(
                contentRect: .zero,
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )

            // 2.3 关键：设置代理，触发 windowWillClose 等
            window.delegate = window

            // 2.4 配置窗口内容和大小
            window.contentViewController = hostingVC
            window.setContentSize(NSSize(width: 760, height: 600))
            window.contentMinSize = NSSize(width: 760, height: 600)
            window.animationBehavior = .none
            window.title = "V2rayU"
            window.center()
            window.isReleasedWhenClosed = false

            // 2.5 包装成 NSWindowController
            windowController = NSWindowController(window: window)
        }

        // 3. 先激活应用（必须同步，确保窗口能正确接收焦点）
        NSApp.activate(ignoringOtherApps: true)
        // 4. 显示窗口
        windowController?.showWindow(nil)
        // 5. 延迟置前，确保菜单 tracking 结束后窗口能正确弹出
        DispatchQueue.main.async { [weak self] in
            guard let win = self?.windowController?.window else { return }
            win.makeKeyAndOrderFront(nil)
            win.orderFrontRegardless()
        }
    }
}
