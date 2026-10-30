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
        crashBreadcrumb("open main window")
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
                styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )

            // 2.3 关键：设置代理，触发 windowWillClose 等
            window.delegate = window

            // 2.4 配置窗口内容和大小
            window.contentViewController = hostingVC
            // 默认和最小尺寸都控制在笔记本屏幕的一半以内; 内容区放不下的页面自己滚动
            window.setContentSize(NSSize(width: 820, height: 620))
            window.minimumContentSize = NSSize(width: 800, height: 600)
            window.animationBehavior = .none
            window.title = "V2rayU" // 窗口菜单里用, 标题栏不显示
            // 标题栏透明, 内容铺到顶部; 红绿灯浮在侧边栏左上角
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.center()
            window.isReleasedWhenClosed = false

            // 2.5 包装成 NSWindowController
            windowController = NSWindowController(window: window)
        }

        // 2.6 已有窗口比最小尺寸还小(比如旧版本留下的), 打开时撑回最小尺寸
        if let win = windowController?.window as? BaseWindow {
            let cur = win.contentRect(forFrameRect: win.frame).size
            let min = win.minimumContentSize
            if cur.width < min.width || cur.height < min.height {
                win.setContentSize(NSSize(width: max(cur.width, min.width), height: max(cur.height, min.height)))
            }
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
