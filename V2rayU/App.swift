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
        V2rayLaunch.checkInstall()
        V2rayLaunch.runAtStart()
        // 加载
        appState.viewModel.getList()
//        V2rayLaunch.runTun2Socks()
    }


    var body: some Scene {
        // 显示 MenuBar
        MenuBarExtra("V2rayU", image: appState.icon) {
            AppMenuView(openContentViewWindow: openContentViewWindow)
        }
        .menuBarExtraStyle(.window) // 重点,按窗口显示
        .environment(\.locale, languageManager.currentLocale) // 设置 Environment 的 locale
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

struct VisualEffectBackground: View {
    @Environment(\.colorScheme) var colorScheme // 获取当前系统的颜色模式
    
    var body: some View {
        VisualEffectView(effect: colorScheme == .dark ? .dark : .light)
            .edgesIgnoringSafeArea(.all)
    }
}

struct VisualEffectView: NSViewRepresentable {
    var effect: NSVisualEffectView.Material
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let visualEffectView = NSVisualEffectView()
        visualEffectView.blendingMode = .withinWindow
        visualEffectView.material = effect
        visualEffectView.state = .active
        return visualEffectView
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = effect
    }
}

struct CustomMenuItemView: View {
    var body: some View {
        Text("Hello world")
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
