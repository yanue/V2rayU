//
//  HotKeyWindow.swift
//  V2rayU
//
//  Created by yanue on 2025/8/6.
//

import SwiftUI
import Foundation

// 自定义窗口: 监听快捷键及窗口关闭事件
class BaseWindow: NSWindow, NSWindowDelegate {
    // 因使用 NSStatusItem 自定义显示tray, 导致打开窗口无法自动监听相关快捷键, 这种手动监听对应的快捷键
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard event.type == .keyDown,
              event.modifierFlags.contains(.command),
              let chars = event.charactersIgnoringModifiers?.lowercased()
        else {
            return super.performKeyEquivalent(with: event)
        }

        switch chars {
        case "w":
            self.performClose(nil)
            return true

        case "q":
            NSApp.terminate(nil)
            return true

        default:
            return super.performKeyEquivalent(with: event)
        }
    }
    
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        // 允许窗口关闭
        return true
    }
    
    // 监听窗口关闭事件, 所有窗口关闭时,隐藏 dock 图标
    func windowWillClose(_ notification: Notification) {
        // 延迟检查剩余的窗口
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // 当前已打开的窗口
            let windows = NSApplication.shared.windows
            // 过滤出用户可见的普通窗口
            let visibleMainWindows = windows.filter { window in
                window.isVisible && window.isKeyWindow && window.level == .normal
            }
            // 如果没有可见的主窗口
            if visibleMainWindows.isEmpty {
                // 隐藏 Dock 图标
                NSApp.setActivationPolicy(.accessory)
            }
        }
    }
}
