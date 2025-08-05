import SwiftData
import SwiftUI

@main
struct V2rayUApp: App {
    @State var windowController: NSWindowController?
    @State var aboutWindowController: NSWindowController?
    @StateObject var languageManager = LanguageManager()
    @StateObject var themeManager = ThemeManager()
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState.shared
    @Environment(\.colorScheme) var colorScheme

    // 新增：状态栏菜单项
    var statusItem: NSStatusItem?

    init() {
        // 初始化
        let fileManager = FileManager.default
        if fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first != nil {
//            print("Application Support Directory: \(appSupportURL)")
        }
        print("NSHomeDirectory()", NSHomeDirectory())
        print("userHomeDirectory", userHomeDirectory)
//        AppDelegate.redirectStdoutToFile()
        // 加载
//        appState.viewModel.getList()
//        V2rayLaunch.runTun2Socks()
        // 初始化状态栏菜单
        setupStatusItem()
    }

    var body: some Scene {
        // 移除 MenuBarExtra，保留空 WindowGroup 以兼容 SwiftUI 生命周期
        WindowGroup {
            EmptyView()
        }
        .environment(\.locale, languageManager.currentLocale)
    }

    // 新增：状态栏菜单初始化
    func setupStatusItem() {
        // 只初始化一次
        if statusItem != nil { return }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(named: appState.icon)
        item.button?.action = #selector(statusBarButtonClicked)
        item.button?.target = self
        item.menu = buildStatusMenu()
        statusItem = item
    }

    // 新增：构建菜单
    func buildStatusMenu() -> NSMenu {
        let menu = NSMenu()
        // 参考 MainMenu.xib 和 MenuController，添加主要菜单项
        menu.addItem(withTitle: "V2ray-Core: On", action: nil, keyEquivalent: "")
        menu.items.last?.isEnabled = false
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "打开主界面", action: #selector(openMainWindow), keyEquivalent: "o")
        menu.addItem(withTitle: "关于", action: #selector(openAbout), keyEquivalent: "")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "退出", action: #selector(quitApp), keyEquivalent: "q")
        return menu
    }

    // 新增：状态栏按钮点击事件（可选，弹出 SwiftUI 菜单/窗口）
    @objc func statusBarButtonClicked() {
        // 可选：弹出 SwiftUI 菜单窗口
        openContentViewWindow()
    }

    // 新增：菜单事件
    @objc func openMainWindow() {
        openContentViewWindow()
    }

    @objc func openAbout() {
        openAboutWindow()
    }

    @objc func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    func MenuBarIcon() -> some View {
        HStack(spacing: 8) {
            Image(appState.icon)
                .resizable()
                .frame(width: 18, height: 18)
            if AppSettings.shared.showSpeedOnTray {
                VStack(alignment: .trailing, spacing: 0) {
                    Text(String(format: "↑%.0fKB/s", AppState.shared.proxyUpSpeed))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(Color(red: 1, green: 0.2, blue: 0.2))
                    Text(String(format: "↓%.0fKB/s", AppState.shared.proxyDownSpeed))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(Color(red: 0.2, green: 0.7, blue: 0.2))
                }
                .frame(height: 18)
                .fixedSize()
            }
            Spacer()
        }
        .padding(.horizontal, 4)
        .frame(height: 32)
        .background(Color(NSColor.windowBackgroundColor).opacity(0.95))
      }

    func openContentViewWindow() {
        if windowController == nil {
//            let contentView = ContentView().modelContainer(sharedModelContainer)
//            let item = ProfileModel(protocol: .trojan,  address: "aaa", port: 443, id: "xxxx-bbb-ccccc", security: "none", remark: "test02")
//            let contentView = ConfigView(item: item)
            let contentView = ContentView()
                .environment(\.locale, languageManager.currentLocale) // 设置 Environment 的 locale
                .environmentObject(AppState.shared)
            let hostingController = NSHostingController(rootView: contentView)

            let window = NSWindow(contentViewController: hostingController)
            window.setContentSize(NSSize(width: 760, height: 600))
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            window.isReleasedWhenClosed = false
            window.delegate = windowDelegate

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

    func openAboutWindow() {
        if aboutWindowController == nil {
            // 创建自定义 About 窗口
            let aboutView = VStack {
                Text("V2rayU")
                    .font(.largeTitle)
                Text("版本 1.0.0")
                Text("版权所有 © 2024")
                    .padding()
            }.frame(width: 400, height: 200)
                .padding()
            let hostingController = NSHostingController(rootView: aboutView)
            let window = NSWindow(contentViewController: hostingController)
            window.title = "About V2rayU"
            window.styleMask = [.titled, .closable]
            window.setContentSize(NSSize(width: 600, height: 400))
            window.isReleasedWhenClosed = false
            window.delegate = windowDelegate

            aboutWindowController = NSWindowController(window: window)
        }
        // 确保窗口在最前面
        aboutWindowController?.window?.makeKeyAndOrderFront(nil)
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        // 确保窗口始终在最前面
        DispatchQueue.main.async {
            self.aboutWindowController?.window?.orderFrontRegardless()
        }
    }

    func showWindow() {
    }
}


// 实现 NSWindowDelegate 来监听窗口关闭事件,所有窗口关闭时,隐藏 dock 图标
class WindowDelegate: NSObject, NSWindowDelegate {
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
