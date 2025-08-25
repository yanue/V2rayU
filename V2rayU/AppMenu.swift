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

    func refreshMenuItems() {
        setupMenu()
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
        menu.addItem(getRunModeItem(mode: .pac,title: "Pac Mode", keyEquivalent: ""))
        menu.addItem(getRunModeItem(mode: .global,title: "Global Mode", keyEquivalent: ""))
        menu.addItem(getRunModeItem(mode: .manual,title: "Manual Mode", keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        // 路由与服务器
        let routingItem = getRoutingSubMenus()
        menu.addItem(routingItem)
        let serverItem = getServerSubMenus()
        menu.addItem(serverItem)
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
    
    func getRunModeItem(mode: RunMode,title: String, keyEquivalent: String = "") -> NSMenuItem {
        let menu = NSMenuItem()
        menu.title = title
        menu.action = #selector(switchRunMode)
        menu.representedObject = mode.rawValue  // 可选：存储模式名称
        menu.isEnabled =  true
        menu.target = self
        menu.keyEquivalent = keyEquivalent // todo 快捷键设置
        menu.state = (mode == AppState.shared.runMode) ? .on : .off
        return menu
    }

    func getRoutingSubMenus() -> NSMenuItem {
        let menu = NSMenuItem()
        menu.title = "Routing"
        menu.submenu = NSMenu()
        
        let routings = RoutingViewModel.all()
        let currentRouting = AppState.shared.runningRouting
        let item = NSMenuItem(title: "Routing Settings ...", action: #selector(openRoutingTab), keyEquivalent: "")
        item.representedObject = ""  // 可选：存储路由名称
        item.isEnabled =  true
        item.target = self
        menu.submenu?.addItem(item)
        menu.submenu?.addItem(NSMenuItem.separator())

        NSLog("currentRouting: \(currentRouting)")
        for routing in routings {
            NSLog("routing item: \(routing.name) \(currentRouting) \(item.state.rawValue) ")
            let item = createRoutingMenuItem(routing: routing, current: currentRouting)
            menu.submenu?.addItem(item)
        }
        return menu
    }
    
    private func createRoutingMenuItem(routing: RoutingModel, current: String) -> NSMenuItem {
        let item = NSMenuItem(title: routing.remark, action: #selector(switchRouting), keyEquivalent: "")
        item.representedObject = routing  // 可选：存储路由名称
        item.isEnabled =  true
        item.target = self
        item.state = (routing.uuid == current) ? .on : .off
        return item
    }
    
    func getServerSubMenus() -> NSMenuItem {
        let menu = NSMenuItem()
        menu.title = "Servers"
        menu.submenu = NSMenu()
        
        let currentProfile = AppState.shared.runningProfile
        
        // 添加服务器设置项
        let settingsItem = NSMenuItem(title: "Servers Settings ...", action: #selector(openServerTab), keyEquivalent: "")
        settingsItem.isEnabled = true
        settingsItem.target = self
        menu.submenu?.addItem(settingsItem)
        menu.submenu?.addItem(NSMenuItem.separator())
        
        // 按订阅ID分组
        let groupedServers = ProfileViewModel.getGroupedProfiles()
        
        // 决定是否使用分组显示
        let useGrouping = groupedServers.count >= 2
        
        if useGrouping {
            // 分组显示
            for (name, profiles) in groupedServers {
                let groupName = name.isEmpty ? "Default" : name
                let subMenu = NSMenu()
                let groupItem = NSMenuItem()
                groupItem.title = groupName
                groupItem.submenu = subMenu
                groupItem.image = NSImage(systemSymbolName: "folder", accessibilityDescription: nil)
                groupItem.toolTip = "\(profiles.count) servers"
                // todo 优化
                groupItem.state = profiles.contains { $0.uuid == currentProfile } ? .on : .off
                for profile in profiles {
                    let item = createServerMenuItem(profile: profile, current: currentProfile)
                    subMenu.addItem(item)
                }
                menu.submenu?.addItem(groupItem)
            }
        } else {
            // 直接显示所有服务器
            for (_, profiles) in groupedServers {
                for profile in profiles {
                    let item = createServerMenuItem(profile: profile, current: currentProfile)
                    menu.submenu?.addItem(item)
                }
            }
        }
        
        return menu
    }

    // 辅助方法：创建对齐的服务器菜单项
    private func createServerMenuItem(profile: ProfileModel, current: String) -> NSMenuItem {
        let speedText: String
        let speedColor: NSColor
        
        if profile.speed < 0 {
            speedText = "[\(profile.speed)ms]"
            speedColor = NSColor.systemGray
        } else if profile.speed < 100 {
            speedText = "[\(profile.speed)ms]"
            speedColor = NSColor.systemGreen
        } else if profile.speed < 300 {
            speedText = "[\(profile.speed)ms]"
            speedColor = NSColor.systemOrange
        } else {
            speedText = "[\(profile.speed)ms]"
            speedColor = NSColor.systemRed
        }
        
        // Ping值放前面
        let title = "\(speedText) \(profile.remark)"
        
        let item = NSMenuItem()
        item.attributedTitle = createColoredAttributedTitle(
            title: title,
            speedRange: NSRange(location: 0, length: speedText.count),
            speedColor: speedColor
        )
        item.action = #selector(switchServer)
        item.keyEquivalent = ""
        item.representedObject = profile
        item.isEnabled = true
        item.target = self
        item.state = profile.uuid == current ? .on : .off
        item.toolTip = "\(profile.address):\(profile.port)"
        
        return item
    }

    private func createColoredAttributedTitle(title: String, speedRange: NSRange, speedColor: NSColor) -> NSAttributedString {
        let attributedString = NSMutableAttributedString(string: title)
        
        // 设置整体字体
        attributedString.addAttributes([
            .font: NSFont.menuFont(ofSize: 0),
            .foregroundColor: NSColor.labelColor
        ], range: NSRange(location: 0, length: title.count))
        
        // 为速度文本设置颜色
        attributedString.addAttributes([
            .foregroundColor: speedColor,
            .font: NSFont.boldSystemFont(ofSize: NSFont.labelFontSize)
        ], range: speedRange)
        
        return attributedString
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
    
    @objc private func openRoutingTab(_ sender: NSMenuItem) {
        AppState.shared.mainTab = .routing
        openMainWindow()
    }
    
    @objc private func openServerTab(_ sender: NSMenuItem) {
        AppState.shared.mainTab = .server
        openMainWindow()
    }
    
    @objc private func switchServer(_ sender: NSMenuItem) {
        guard let uuid = sender.representedObject as? String else {
            NSLog("switchServer err")
            return
        }
        AppState.shared.runProfile(uuid: uuid)
    }

    @objc private func switchRouting(_ sender: NSMenuItem) {
        guard let uuid = sender.representedObject as? String else {
            NSLog("switchRouting err")
            return
        }
        AppState.shared.runRouting(uuid: uuid)
    }

    @objc private func goHelp(_ sender: NSMenuItem) {
        guard let url = URL(string: "https://github.com/yanue/v2rayu/issues") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    @objc private func switchRunMode(_ sender: NSMenuItem) {
        guard let modeRaw = sender.representedObject as? String, let mode = RunMode(rawValue: modeRaw) else {
            NSLog("switchRunMode err")
            return
        }
        NSLog("switchRunMode: \(mode.rawValue)")
        AppState.shared.runMode(mode: mode)
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
