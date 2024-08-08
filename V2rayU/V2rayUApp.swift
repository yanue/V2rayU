import SwiftUI
import SwiftData

@main
struct V2rayUApp: App {
    @State private var windowController: NSWindowController?
    private var windowDelegate = WindowDelegate()
    @State private var aboutWindowController: NSWindowController?

    init() {
        // 已设置 Application is agent (UIElement) 为 YES
        // 初始化
    }

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        // 显示 MenuBar
        MenuBarExtra("V2rayU", image: "IconOn") {
            AppMenu(openContentViewWindow: openContentViewWindow,openAboutWindow: openAboutWindow)
        }
        // 不需要 contentView 了
    }
    
    func openContentViewWindow() {
        if windowController == nil {
            let contentView = ContentView().modelContainer(sharedModelContainer)
            let hostingController = NSHostingController(rootView: contentView)

            let window = NSWindow(contentViewController: hostingController)
            window.setContentSize(NSSize(width: 800, height: 600))
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
           }.frame(width: 400,height: 200)
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
    
    func showWindow(){
        
    }
}

struct AppMenu: View {
    var openContentViewWindow: () -> Void
    var openAboutWindow: () -> Void

    func action1() {
        openContentViewWindow()
    }
    func action2() {
        openAboutWindow()
    }
    func action3() {
        
    }

    var body: some View {
        CustomMenuItemView()
        Button(action: action1, label: { Text("Setting") })
        Button(action: action2, label: { Text("About") })
        
        Divider()

        Button(action: action3, label: { Text("Quit") })
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
