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
    // 直接在主线程执行，避免并发问题
    DispatchQueue.main.async {
        // 检查是否有可用窗口
        if (NSApp.mainWindow ?? NSApp.windows.first) != nil {
            let alert = NSAlert()
            alert.messageText = title
            alert.informativeText = message
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                logger.info("OK clicked")
            } else {
                logger.info("Cancel clicked")
            }
        } else {
            // 如果没有窗口，使用替代方案
            Task {
                await MainActor.run {
                    makeToast(message: title + "\n" + message, displayDuration: 5)
                }
            }
        }
    }
}

@MainActor
func showConfirmAlertSync(title: String, message: String, confirmTitle: String = String(localized: .OK), cancelTitle: String = String(localized: .Cancel)) -> Bool {
    let alert = NSAlert()
    if let icon = NSImage(named: "V2rayU") {
        alert.icon = icon
    }
    alert.messageText = title
    alert.informativeText = message
    alert.alertStyle = .warning
    alert.addButton(withTitle: confirmTitle)
    alert.addButton(withTitle: cancelTitle)
    return alert.runModal() == .alertFirstButtonReturn
}

func makeToast(message: String, displayDuration: Double? = 3) {
    logger.info("makeToast: message=\(message),displayDuration=\(String(describing: displayDuration))")
    // 确保调用 makeToast 时在主线程上
    DispatchQueue.main.async {
        ToastManager.shared.makeToast(message: message,displayDuration: displayDuration ?? 3)
    }
}

/// 全局管理 Toast 显示的单例类
/// 支持消息更新防抖和自动隐藏功能
@MainActor
class ToastManager: ObservableObject {
    static let shared = ToastManager()
    
    @Published private(set) var message: String = ""
    private var toastWindow: NSWindow?
    private var hideTask: Task<Void, Never>?
    private var isDisplaying = false
    private var lastUpdateTime: Date = .distantPast
    private let minimumUpdateInterval: TimeInterval = 0.5  // 最小更新间隔为0.5秒
    
    private init() {
        setupToastWindow()
    }
    
    /// 显示或更新 Toast 消息
    /// - Parameters:
    ///   - message: 要显示的消息内容
    ///   - displayDuration: 显示持续时间，默认3秒
    func makeToast(message: String, displayDuration: Double = 3) {
        let now = Date()
        guard now.timeIntervalSince(lastUpdateTime) >= minimumUpdateInterval else {
            return  // 防止频繁更新
        }
        
        self.message = message
        self.lastUpdateTime = now
        
        if !isDisplaying {
            toastWindow?.makeKeyAndOrderFront(nil)
            isDisplaying = true
        }
        
        adjustWindowSize(for: message)
        scheduleHideToast(after: displayDuration)
    }
    
    /// 初始化 Toast 窗口及其基本配置
    private func setupToastWindow() {
        let screen = NSScreen.main!
        let frame = CGRect(
            x: (screen.frame.width - 300) / 2,
            y: screen.frame.height - 50,
            width: 300,
            height: 50
        )
        
        let hostingView = NSHostingView(rootView: ToastView(manager: self))
        toastWindow = NSWindow(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        toastWindow?.isOpaque = false
        toastWindow?.backgroundColor = .clear
        toastWindow?.level = .floating
        toastWindow?.contentView = hostingView
        toastWindow?.isReleasedWhenClosed = false
    }
    
    /// 根据消息内容动态调整窗口大小
    private func adjustWindowSize(for message: String) {
        guard let toastWindow = self.toastWindow else { return }
        
        let tempView = NSHostingView(rootView: ToastView(manager: self))
        let fittingSize = tempView.fittingSize
        
        let screen = NSScreen.main!
        let newFrame = CGRect(
            x: (screen.frame.width - fittingSize.width) / 2,
            y: screen.frame.height - 50,
            width: fittingSize.width,
            height: fittingSize.height
        )
        toastWindow.setFrame(newFrame, display: true)
    }
    
    /// 调度 Toast 的自动隐藏任务
    /// - Parameter duration: 显示持续时间
    private func scheduleHideToast(after duration: Double) {
        hideTask?.cancel()  // 取消之前的隐藏任务
        
        hideTask = Task {
            do {
                try await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
                if !Task.isCancelled {
                    toastWindow?.orderOut(nil)
                    isDisplaying = false
                }
            } catch {
                logger.info("Hide task cancelled")
            }
        }
    }
}

/// Toast 视图组件
struct ToastView: View {
    @ObservedObject var manager: ToastManager
    
    var body: some View {
        Text(manager.message)
            .padding()
            .background(Color.black.opacity(0.8))
            .foregroundColor(.white)
            .cornerRadius(8)
    }
}
