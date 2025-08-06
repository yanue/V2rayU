//
//  AppMenu.swift
//  V2rayU
//
//  Created by yanue on 2025/8/5.
//

import AppKit
import SwiftUI

@MainActor
final class StatusItemManager: NSObject {
    static let shared = StatusItemManager()
    var windowController: NSWindowController?
    var aboutWindowController: NSWindowController?
    private var statusItem: NSStatusItem!
    private var hostingView: NSHostingView<StatusItemView>!

    override private init() {
        super.init()
    }

    func setupStatusItem() {
        setStatusItem()
        setupMenu()
    }

    private func setupMenu() {
        let menu = NSMenu()

        // 基本菜单项
        menu.addItem(NSMenuItem(title: "打开主窗口", action: #selector(openMainWindow), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "退出", action: #selector(terminateApp), keyEquivalent: "q"))

        // 为所有菜单项设置 target
        for item in menu.items {
            item.target = self
        }

        statusItem.menu = menu
    }
    
    func setStatusItem() {
        // StatusBar自适应关键点: 需要 StatusItemView 设置 fixedSize 配合 statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            // 创建 SwiftUI 视图的 HostingView
            let statusItemView = StatusItemView()
            hostingView = NSHostingView(rootView: statusItemView)
            button.addSubview(hostingView)
            // 只给垂直方向撑满，水平方向让尺寸自行决定
            hostingView.translatesAutoresizingMaskIntoConstraints = false
            // 设置约束
            NSLayoutConstraint.activate([
                hostingView.leadingAnchor.constraint(equalTo: button.leadingAnchor),
                hostingView.trailingAnchor.constraint(equalTo: button.trailingAnchor),
                hostingView.topAnchor.constraint(equalTo: button.topAnchor),
                hostingView.bottomAnchor.constraint(equalTo: button.bottomAnchor),
            ])
        }
    }
    
    @objc private func openMainWindow() {
        // 1. 切回常规模式（显示 Dock 图标、主菜单）
        NSApp.setActivationPolicy(.regular)
        // 2. 激活应用，确保接收键盘事件
        NSApp.activate(ignoringOtherApps: true)

        // 3. 如果还没创建 windowController，就初始化
        if windowController == nil {
            // 3.1 构建 SwiftUI 内容视图
            let contentView = ContentView()
                .environment(\.locale, LanguageManager.shared.currentLocale)
                .environmentObject(AppState.shared)
            let hostingVC = NSHostingController(rootView: contentView)

            // 3.2 初始化自定义窗口
            let window = HotKeyWindow(
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

    @objc private func terminateApp() {
        NSApp.terminate(self)
    }
}
