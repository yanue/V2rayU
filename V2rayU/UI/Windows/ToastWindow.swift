//
//  ToastWindowController.swift
//  V2rayU
//
//  Toast 通知窗口管理
//  用于在屏幕顶部显示临时消息提示（如"复制成功"等）
//

import Cocoa
import SwiftUI

// MARK: - Alert 对话框

/// 显示一个模态警告对话框
/// - Parameters:
///   - title: 对话框标题
///   - message: 对话框内容
func alertDialog(title: String, message: String) {
    DispatchQueue.main.async {
        // 优先使用主窗口显示对话框
        if (NSApp.mainWindow ?? NSApp.windows.first) != nil {
            let alert = NSAlert()
            alert.messageText = title
            alert.informativeText = message
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
        } else {
            // 如果没有可用窗口，回退到 Toast 显示
            Task {
                await MainActor.run {
                    makeToast(message: title + "\n" + message, displayDuration: 5)
                }
            }
        }
    }
}

// MARK: - Alert 同步对话框

/// 显示一个同步警告对话框（阻塞调用）
@MainActor
func showAlertSync(title: String, message: String, confirmTitle: String = String(localized: .OK)) {
    let alert = NSAlert()
    if let icon = NSImage(named: "V2rayU") {
        alert.icon = icon
    }
    alert.messageText = title
    alert.informativeText = message
    alert.alertStyle = .warning
    alert.addButton(withTitle: confirmTitle)
}

/// 显示一个带确认/取消按钮的同步对话框
/// - Returns: 用户点击确认返回 true，取消返回 false
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

// MARK: - Toast 通知

/// 全局 Toast 显示函数（主入口）
/// 在屏幕顶部居中显示一个临时消息，自动消失
/// - Parameters:
///   - message: 要显示的消息内容
///   - displayDuration: 显示持续时间（秒），默认 3 秒
func makeToast(message: String, displayDuration: Double? = 3) {
    logger.info("makeToast: message=\(message),displayDuration=\(String(describing: displayDuration))")
    // 确保在主线程执行，因为 NSWindow 操作必须在主线程
    DispatchQueue.main.async {
        ToastManager.shared.makeToast(message: message, displayDuration: displayDuration ?? 3)
    }
}

// MARK: - ToastManager

/// Toast 窗口管理器（单例）
/// 负责创建和管理浮层通知窗口
///
/// 设计说明：
/// 1. 使用 borderless 窗口实现透明背景的提示效果
/// 2. 使用 orderFrontRegardless 而非 makeKeyAndOrderFront
///    - borderless 窗口不能成为 key window
///    - makeKeyAndOrderFront 会尝试成为 key window 导致崩溃
///    - orderFrontRegardless 只显示窗口，不尝试成为 key window
/// 3. 窗口懒加载：首次调用 makeToast 时才创建窗口
/// 4. SwiftUI 视图通过 @ObservedObject 观察 message 变化自动更新
@MainActor
class ToastManager: ObservableObject {
    static let shared = ToastManager()
    
    /// 当前显示的消息内容（@Published 属性，变化时通知 SwiftUI 视图更新）
    @Published private(set) var message: String = ""
    
    /// Toast 窗口引用（懒加载，首次使用时创建）
    private var toastWindow: NSWindow?
    
    /// 定时隐藏任务（用于取消上一次未完成的隐藏任务）
    private var hideTask: Task<Void, Never>?
    
    /// 窗口是否正在显示中
    private var isDisplaying = false
    
    /// 私有初始化，确保单例模式
    private init() {}
    
    /// 显示 Toast 消息
    /// - Parameters:
    ///   - message: 消息内容
    ///   - displayDuration: 显示时长（秒）
    func makeToast(message: String, displayDuration: Double = 3) {
        // 首次调用时创建窗口（懒加载）
        if toastWindow == nil {
            setupWindow()
        }
        
        // 更新消息内容，SwiftUI 视图会自动刷新
        self.message = message
        
        // 如果窗口未显示，则显示它
        if !isDisplaying {
            // 使用 orderFrontRegardless 而非 makeKeyAndOrderFront
            // 原因：borderless 窗口不能成为 key window
            toastWindow?.orderFrontRegardless()
            isDisplaying = true
        }
        
        // 取消上一次的隐藏任务（防止多次调用时定时器混乱）
        hideTask?.cancel()
        
        // 启动新的定时隐藏任务
        hideTask = Task {
            do {
                // 等待指定时间
                try await Task.sleep(nanoseconds: UInt64(displayDuration * 1_000_000_000))
                if !Task.isCancelled {
                    // 时间到了，隐藏窗口
                    toastWindow?.orderOut(nil)
                    isDisplaying = false
                }
            } catch {
                // 任务被取消，不做任何处理
                logger.info("Hide task cancelled")
            }
        }
    }
    
    /// 创建 Toast 窗口
    /// 仅在首次调用 makeToast 时执行一次
    private func setupWindow() {
        guard toastWindow == nil, let screen = NSScreen.main else { return }
        
        // 初始窗口大小（会被 SwiftUI 视图内容撑开）
        let initialFrame = CGRect(
            x: (screen.frame.width - 300) / 2,  // 水平居中
            y: screen.frame.height - 50,         // 屏幕顶部下方 50pt
            width: 300,
            height: 50
        )
        
        // 创建 SwiftUI 视图，传入 self 以便观察 message 变化
        let toastView = ToastView(manager: self)
        let hosting = NSHostingView(rootView: toastView)
        
        // 创建 borderless 窗口（无标题栏、无边框）
        let window = NSWindow(
            contentRect: initialFrame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        // 窗口样式配置
        window.isOpaque = false           // 窗口不透明 = false，支持透明背景
        window.backgroundColor = .clear  // 背景透明
        window.level = .floating          // 浮动窗口，置于普通窗口之上
        
        // collectionBehavior 配置说明：
        // - .canJoinAllSpaces: 窗口出现在所有 Spaces 中
        // - .fullScreenAuxiliary: 全屏时不消失
        // - .stationary: 窗口位置相对屏幕固定，不参与窗口排列
        // - .ignoresCycle: 忽略窗口循环切换
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        
        // 添加阴影效果，提升视觉层次
        window.hasShadow = true
        
        // 设置内容视图
        window.contentView = hosting
        
        // 关闭窗口时不释放内存，下次复用
        window.isReleasedWhenClosed = false
        
        toastWindow = window
    }
}

// MARK: - ToastView

/// Toast 通知的 SwiftUI 视图
/// 显示一个圆角黑色半透明背景的文字标签
struct ToastView: View {
    /// 观察 ToastManager 的 message 属性
    @ObservedObject var manager: ToastManager
    
    var body: some View {
        Text(manager.message)
            .font(.system(size: 13))           // 13pt 字体
            .padding(.horizontal, 16)          // 左右各 16pt 内边距
            .padding(.vertical, 10)            // 上下各 10pt 内边距
            .background(Color.black.opacity(0.85))  // 85% 不透明度的黑色背景
            .foregroundColor(.white)           // 白色文字
            .cornerRadius(8)                   // 8pt 圆角
            .fixedSize()                      // 固定尺寸，不随父视图拉伸
    }
}
