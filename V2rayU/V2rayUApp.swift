import SwiftData
import SwiftUI

let LAUNCH_AGENT_NAME = "yanue.v2rayu.v2ray-core"
let AppResourcesPath = Bundle.main.bundlePath + "/Contents/Resources"
let AppHomePath = NSHomeDirectory() + "/.V2rayU"
let databasePath = NSHomeDirectory() + "/.V2rayU/.V2rayU.db"
let v2rayUTool = AppHomePath + "/V2rayUTool"
let v2rayCorePath = AppHomePath + "/v2ray-core"
let v2rayCoreFile = v2rayCorePath + "/v2ray"
let logFilePath = AppHomePath + "/v2ray-core.log"
let JsonConfigFilePath = AppHomePath + "/config.json"
@MainActor let windowDelegate = WindowDelegate()
let userHomeDirectory = FileManager.default.homeDirectoryForCurrentUser.path

@main
struct V2rayUApp: App {
    @State private var windowController: NSWindowController?
    @State private var aboutWindowController: NSWindowController?
    

    init() {
        // 已设置 Application is agent (UIElement) 为 YES
        // 初始化
        let fileManager = FileManager.default
        if let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
//            print("Application Support Directory: \(appSupportURL)")
        }
        print("NSHomeDirectory()",NSHomeDirectory())
        print("userHomeDirectory",userHomeDirectory)
    }

   
    var body: some Scene {
        // 显示 MenuBar
        MenuBarExtra("V2rayU", image: "IconOn") {
            AppMenuView(openContentViewWindow: openContentViewWindow)
        }.menuBarExtraStyle(.window) // 重点,按窗口显示
    }

    func openContentViewWindow() {
        if windowController == nil {
//            let contentView = ContentView().modelContainer(sharedModelContainer)
//            let item = ProxyModel(protocol: .trojan,  address: "aaa", port: 443, id: "xxxx-bbb-ccccc", security: "none", remark: "test02")
//            let contentView = ConfigView(item: item)
            let contentView = ContentView()
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
