import SwiftData
import SwiftUI

@main
struct V2rayUApp: App {
    @State  var windowController: NSWindowController?
    @State  var aboutWindowController: NSWindowController?
    @StateObject var languageManager = LanguageManager()
    @StateObject var themeManager = ThemeManager()
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState.shared
    @Environment(\.colorScheme) var colorScheme // 获取当前系统主题模式

    init() {
        // 初始化
        let fileManager = FileManager.default
        if fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first != nil {
//            print("Application Support Directory: \(appSupportURL)")
        }
        print("NSHomeDirectory()",NSHomeDirectory())
        print("userHomeDirectory",userHomeDirectory)
//        AppDelegate.redirectStdoutToFile()
        // 加载
//        appState.viewModel.getList()
//        V2rayLaunch.runTun2Socks()
    }


    var body: some Scene {
        // 留空
    }
    
}

// 实现 NSWindowDelegate 来监听窗口关闭事件,所有窗口关闭时,隐藏 dock 图标
class WindowDelegate: NSObject, NSWindowDelegate {
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        // 允许窗口关闭
        return true
    }
    
    // 监听窗口关闭事件
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
