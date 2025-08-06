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
        // 设置右键菜单
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
        print("打开主窗口")
        if windowController == nil {
            let contentView = ContentView()
                .environment(\.locale, LanguageManager.shared.currentLocale) // 设置 Environment 的 locale
                .environmentObject(AppState.shared)
            let hostingController = NSHostingController(rootView: contentView)

            let window = NSWindow(contentViewController: hostingController)
            window.setContentSize(NSSize(width: 760, height: 600))
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            window.isReleasedWhenClosed = false
//            window.delegate = windowDelegate
            window.title = "V2rayU"
            
            windowController = NSWindowController(window: window)
        }

        windowController?.showWindow(nil)
        // 确保窗口在最前面
        windowController?.window?.makeKeyAndOrderFront(nil)
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        // 确保窗口始终在最前面
        DispatchQueue.main.async {
            self.windowController?.window?.orderFrontRegardless()
        }
    }

    @objc private func terminateApp() {
        NSApp.terminate(self)
    }

}
