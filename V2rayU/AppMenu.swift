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
    private var toggleCoreItem: NSMenuItem!

    override private init() {
        super.init()
    }

    func setupStatusItem() {
        setStatusItem()
        setupMenu()
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

    private func setupMenu() {
        let menu = NSMenu()

        // 基本菜单项
        // 状态显示
        let coreStatusItem = NSMenuItem(title: "v2ray-core: On (v4.2.6)", action: nil, keyEquivalent: "")
        coreStatusItem.isEnabled = false
        menu.addItem(coreStatusItem)

        toggleCoreItem = NSMenuItem(title: AppState.shared.v2rayTurnOn ? "Turn Core Off" : "Turn Core On", action: #selector(toggleRunning), keyEquivalent: "t")
        menu.addItem(toggleCoreItem)
        // 配置查看
        menu.addItem(NSMenuItem(title: "View config.json", action: #selector(viewConfig), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "View pac file", action: #selector(viewPacFile), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "View v2ray log", action: #selector(openLogs), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        // 模式切换
        menu.addItem(NSMenuItem(title: "Pac Mode", action: #selector(switchPacMode), keyEquivalent: ""))
        let globalModeItem = NSMenuItem(title: "Global Mode", action: #selector(switchGlobalMode), keyEquivalent: "")
        globalModeItem.state = .on // 当前选中模式
        menu.addItem(globalModeItem)
        menu.addItem(NSMenuItem(title: "Manual Mode", action: #selector(switchManualMode), keyEquivalent: ""))

        menu.addItem(NSMenuItem.separator())

        // 路由与服务器
        let routingItem = NSMenuItem(title: "Routing", action: #selector(goRouting), keyEquivalent: "")
        menu.addItem(routingItem)
        menu.addItem(NSMenuItem(title: "Servers", action: #selector(switchServer), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "打开主窗口", action: #selector(openMainWindow), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Subscription...", action: #selector(openPreferenceSubscribe), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Pac...", action: #selector(openPreferencePac), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Ping", action: #selector(pingSpeed), keyEquivalent: ""))

        menu.addItem(NSMenuItem.separator())

        // 导入与分享
        menu.addItem(NSMenuItem(title: "Import Server From Pasteboard", action: #selector(ImportFromPasteboard), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Scan QR Code From Screen", action: #selector(scanQrcode), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Share QR Code", action: #selector(generateQrcode), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Copy HTTP Proxy Shell Export Line", action: #selector(copyExportCommand), keyEquivalent: ""))

        menu.addItem(NSMenuItem.separator())

        // 设置与帮助
        menu.addItem(NSMenuItem(title: "Preferences...", action: #selector(openPreferenceGeneral), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "Check for Updates...", action: #selector(checkForUpdate), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Help", action: #selector(goHelp), keyEquivalent: ""))

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "退出", action: #selector(terminateApp), keyEquivalent: "q"))

        // 为所有菜单项设置 target
        for item in menu.items {
            item.target = self
        }

        statusItem.menu = menu
    }

    @objc private func openLogs(_ sender: NSMenuItem) {
//        OpenLogs()
    }

    @objc private func toggleRunning(_ sender: NSMenuItem) {
        let isRunning = AppState.shared.v2rayTurnOn
        V2rayLaunch.ToggleRunning()
        toggleCoreItem.title = AppState.shared.v2rayTurnOn ? "Turn xray-core On" : "Turn xray-core Off"
        print("toggleRunning", isRunning, toggleCoreItem.title)
    }

    @objc private func quitClicked(_ sender: NSMenuItem) {
        NSApplication.shared.terminate(self)
    }

    @objc private func openPreferenceGeneral(_ sender: NSMenuItem) {
        AppState.shared.mainTab = .setting
        AppState.shared.settingTab = .general
        openMainWindow()
    }

    @objc private func openPreferenceSubscribe(_ sender: NSMenuItem) {
        AppState.shared.mainTab = .subscription
        openMainWindow()
    }

    @objc private func openPreferencePac(_ sender: NSMenuItem) {
        AppState.shared.mainTab = .setting
        AppState.shared.settingTab = .pac
        openMainWindow()
    }

    @objc private func switchServer(_ sender: NSMenuItem) {
//        guard let obj = sender.representedObject as? V2rayItem else {
//            NSLog("switchServer err")
//            return
//        }
//        UserDefaults.set(forKey: .v2rayCurrentServerName, value: obj.name)
        V2rayLaunch.restartV2ray()
    }

    @objc private func switchRouting(_ sender: NSMenuItem) {
//        guard let obj = sender.representedObject as? RoutingItem else {
//            NSLog("switchRouting err")
//            return
//        }
//        UserDefaults.set(forKey: .routingSelectedRule, value: obj.name)
//        showRouting()
        V2rayLaunch.restartV2ray()
    }

    @objc private func openConfig(_ sender: NSMenuItem) {
//        OpenConfigWindow()
    }

    @objc private func goHelp(_ sender: NSMenuItem) {
        guard let url = URL(string: "https://github.com/yanue/v2rayu/issues") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    @objc private func switchManualMode(_ sender: NSMenuItem) {
        V2rayLaunch.restartV2ray()
    }

    @objc private func switchPacMode(_ sender: NSMenuItem) {
        V2rayLaunch.restartV2ray()
    }

    @objc private func goRouting(_ sender: NSMenuItem) {
        DispatchQueue.main.async {
//            showDock(state: true)
        }
    }

    @objc private func switchGlobalMode(_ sender: NSMenuItem) {
        UserDefaults.set(forKey: .runMode, value: RunMode.global.rawValue)
        V2rayLaunch.restartV2ray()
    }

    @objc private func checkForUpdate(_ sender: NSMenuItem) {
        V2rayUpdater.checkForUpdates(showWindow: true)
    }

    @objc private func generateQrcode(_ sender: NSMenuItem) {
//        guard let v2ray = V2rayServer.loadSelectedItem() else {
//            NSLog("v2ray config not found")
//            noticeTip(title: "generate Qrcode fail", informativeText: "no available servers")
//            return
//        }
//
//        let share = ShareUri()
//        share.qrcode(item: v2ray)
//        if share.error.count > 0 {
//            noticeTip(title: "generate Qrcode fail", informativeText: share.error)
//            return
//        }
//
//        showQRCode(uri: share.uri)
    }

    @objc private func copyExportCommand(_ sender: NSMenuItem) {
        // Get the Http proxy config.
        let httpPort = AppSettings.shared.httpPort
        let socksPort = AppSettings.shared.socksPort

        // Format an export string.
        let command = "export http_proxy=http://127.0.0.1:\(httpPort);export https_proxy=http://127.0.0.1:\(httpPort);export ALL_PROXY=socks5://127.0.0.1:\(socksPort)"

        // Copy to paste board.
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(command, forType: NSPasteboard.PasteboardType.string)

        // Show a toast notification.
        noticeTip(title: "Export Command Copied.", informativeText: "")
    }

    @objc private func scanQrcode(_ sender: NSMenuItem) {
        let uri: String = Scanner.scanQRCodeFromScreen()
        if uri.count > 0 {
            importUri(url: uri)
        } else {
            noticeTip(title: "import server fail", informativeText: "no found qrcode")
        }
    }

    @objc private func ImportFromPasteboard(_ sender: NSMenuItem) {
        if let uri = NSPasteboard.general.string(forType: .string), uri.count > 0 {
            importUri(url: uri)
        } else {
            noticeTip(title: "import server fail", informativeText: "no found vmess:// or vless:// or trojan:// or ss:// from Pasteboard")
        }
    }

    @objc private func pingSpeed(_ sender: NSMenuItem) {
        Task {
            await PingAll.shared.run()
        }
    }

    @objc private func viewConfig(_ sender: Any) {
        let confUrl = getConfigUrl()
        guard let url = URL(string: confUrl) else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    @objc private func viewPacFile(_ sender: Any) {
        let pacUrl = getPacUrl()
        guard let url = URL(string: pacUrl) else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    @objc private func goRelease(_ sender: Any) {
        guard let url = URL(string: "https://github.com/yanue/v2rayu/releases") else {
            return
        }
        NSWorkspace.shared.open(url)
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
