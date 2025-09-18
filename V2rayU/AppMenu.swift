//
//  AppMenu.swift
//  V2rayU
//
//  Created by yanue on 2025/8/5.
//

import AppKit
import SwiftUI

@MainActor
final class AppMenuManager: NSObject {
    static let shared = AppMenuManager()
    var windowController: NSWindowController?
    var aboutWindowController: NSWindowController?
    private var inited = false
    private var statusItem: NSStatusItem!
    private var hostingView: NSHostingView<StatusItemView>!
    // menu items
    private var coreStatusItem: NSMenuItem!
    private var toggleCoreItem: NSMenuItem!
    private var viewConfigItem: NSMenuItem!
    private var viewPacItem: NSMenuItem!
    private var viewLogItem: NSMenuItem!
    private var pacModeItem: NSMenuItem!
    private var globalModeItem: NSMenuItem!
    private var manualModeItem: NSMenuItem!
    private var routingItem: NSMenuItem!
    private var routingSubMenu: NSMenu!
    private var goRoutingSettingItem: NSMenuItem!
    private var serverItem: NSMenuItem!
    private var serverSubMenu: NSMenu!
    private var goServerSettingItem: NSMenuItem!
    private var goSubscriptionsItem: NSMenuItem!
    private var pacSettingsItem: NSMenuItem!
    private var pingItem: NSMenuItem!
    private var importServersItem: NSMenuItem!
    private var scanQRCodeItem: NSMenuItem!
    private var shareQRCodeItem: NSMenuItem!
    private var copyHttpProxyItem: NSMenuItem!
    private var goPreferencesItem: NSMenuItem!
    private var checkForUpdatesItem: NSMenuItem!
    private var helpItem: NSMenuItem!
    private var quitItem: NSMenuItem!

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

    func refreshServerItems() {
        serverSubMenu = getServerSubMenus()
        serverItem.submenu = serverSubMenu
    }
    
    func refreshRoutingItems() {
        routingSubMenu = getRoutingSubMenus()
        routingItem.submenu = routingSubMenu
    }
    
    func refreshBasicMenus() {
        coreStatusItem?.title = AppState.shared.v2rayTurnOn ? String(localized: .CoreOn) : String(localized: .CoreOff)
        toggleCoreItem?.title = AppState.shared.v2rayTurnOn ? String(localized: .TurnCoreOff) : String(localized: .TurnCoreOn)
        pacModeItem.state = (.pac == AppState.shared.runMode) ? .on : .off
        globalModeItem.state = (.global == AppState.shared.runMode) ? .on : .off
        manualModeItem.state = (.manual == AppState.shared.runMode) ? .on : .off
    }
    
    func updateMenuTitles() {
        if !inited {
            return
        }
        coreStatusItem?.title = AppState.shared.v2rayTurnOn ? String(localized: .CoreOn) : String(localized: .CoreOff)
        pingItem?.title = String(localized: .Ping)
        toggleCoreItem?.title = AppState.shared.v2rayTurnOn ? String(localized: .TurnCoreOff) : String(localized: .TurnCoreOn)
        viewConfigItem?.title = String(localized: .ViewConfigJson)
        viewPacItem?.title = String(localized: .ViewPacFile)
        viewLogItem?.title = String(localized: .ViewLog)
        pacModeItem?.title = String(localized: .PacMode)
        globalModeItem?.title = String(localized: .GlobalMode)
        manualModeItem?.title = String(localized: .ManualMode)
        goSubscriptionsItem?.title = String(localized: .goSubscriptionSettings)
        goRoutingSettingItem?.title = String(localized: .goRoutingSettings)
        goServerSettingItem?.title = String(localized: .goServerSettings)
        goPreferencesItem?.title = String(localized: .goPreferences)
        pacSettingsItem?.title = String(localized: .PAC)
        importServersItem?.title = String(localized: .ImportServersFromClipboard)
        scanQRCodeItem?.title = String(localized: .ScanQRCodeFromScreen)
        shareQRCodeItem?.title = String(localized: .ShareQrCode)
        copyHttpProxyItem?.title = String(localized: .CopyHttpProxyShellExportLine)
        checkForUpdatesItem?.title = String(localized: .CheckForUpdates)
        helpItem?.title = String(localized: .Help)
        quitItem?.title = String(localized: .Quit)
        routingItem?.title = String(localized: .RoutingList)
        serverItem?.title = String(localized: .ServerList)
    }


    private func setupMenu() {
        let menu = NSMenu()

        // 基本菜单项
        coreStatusItem = NSMenuItem(title: AppState.shared.v2rayTurnOn ? String(localized: .CoreOn) : String(localized: .CoreOff), action: nil, keyEquivalent: "")
        coreStatusItem.isEnabled = false
        menu.addItem(coreStatusItem)

        toggleCoreItem = NSMenuItem(title: AppState.shared.v2rayTurnOn ? String(localized: .TurnCoreOff) : String(localized: .TurnCoreOn), action: #selector(toggleRunning), keyEquivalent: "t")
        viewConfigItem = NSMenuItem(title: String(localized: .ViewConfigJson), action: #selector(viewConfig), keyEquivalent: "")
        viewPacItem = NSMenuItem(title: String(localized: .ViewPacFile), action: #selector(viewPacFile), keyEquivalent: "")
        viewLogItem = NSMenuItem(title: String(localized: .ViewLog), action: #selector(openLogs), keyEquivalent: "")
        // 配置查看
        menu.addItem(toggleCoreItem)
        menu.addItem(viewConfigItem)
        menu.addItem(viewPacItem)
        menu.addItem(viewLogItem)
        menu.addItem(NSMenuItem.separator())
        // 模式切换
        pacModeItem = getRunModeItem(mode: .pac, title: String(localized: .PacMode), keyEquivalent: "")
        globalModeItem = getRunModeItem(mode: .global, title: String(localized: .GlobalMode), keyEquivalent: "")
        manualModeItem = getRunModeItem(mode: .manual, title: String(localized: .ManualMode), keyEquivalent: "")
        menu.addItem(pacModeItem)
        menu.addItem(globalModeItem)
        menu.addItem(manualModeItem)
        menu.addItem(NSMenuItem.separator())
        // 路由与服务器
        routingItem = getRoutingItem()
        serverItem = getServerItem()
        menu.addItem(NSMenuItem.separator())
        menu.addItem(routingItem)
        menu.addItem(serverItem)
        // 预先初始化一次
        goRoutingSettingItem = NSMenuItem(title: String(localized: .goRoutingSettings), action: #selector(openRoutingTab), keyEquivalent: "")
        goSubscriptionsItem = NSMenuItem(title: String(localized: .goSubscriptionSettings), action: #selector(openPreferenceSubscribe), keyEquivalent: "")
        goServerSettingItem = NSMenuItem(title: String(localized: .goServerSettings), action: #selector(openServerTab), keyEquivalent: "")
        goPreferencesItem = NSMenuItem(title: String(localized: .goPreferences), action: #selector(openPreferenceGeneral), keyEquivalent: ",")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(goSubscriptionsItem)
        menu.addItem(goServerSettingItem)
        menu.addItem(goRoutingSettingItem)
        menu.addItem(goPreferencesItem)
        menu.addItem(NSMenuItem.separator())

        // 导入与分享
        importServersItem = NSMenuItem(title: String(localized: .ImportServersFromClipboard), action: #selector(ImportFromPasteboard), keyEquivalent: "")
        scanQRCodeItem = NSMenuItem(title: String(localized: .ScanQRCodeFromScreen), action: #selector(scanQrcode), keyEquivalent: "")
        shareQRCodeItem = NSMenuItem(title: String(localized: .ShareQrCode), action: #selector(generateQrcode), keyEquivalent: "")
        copyHttpProxyItem = NSMenuItem(title: String(localized: .CopyHttpProxyShellExportLine), action: #selector(copyExportCommand), keyEquivalent: "")
        menu.addItem(importServersItem)
        menu.addItem(scanQRCodeItem)
        menu.addItem(shareQRCodeItem)
        menu.addItem(copyHttpProxyItem)
        menu.addItem(NSMenuItem.separator())

        // 设置与帮助
        checkForUpdatesItem = NSMenuItem(title: String(localized: .CheckForUpdates), action: #selector(checkForUpdate), keyEquivalent: "")
        helpItem = NSMenuItem(title: String(localized: .Help), action: #selector(goHelp), keyEquivalent: "")
        menu.addItem(checkForUpdatesItem)
        menu.addItem(helpItem)
        menu.addItem(NSMenuItem.separator())
        
        quitItem = NSMenuItem(title: String(localized: .Quit), action: #selector(terminateApp), keyEquivalent: "q")
        menu.addItem(quitItem)

        // 为所有菜单项设置 target
        for item in menu.items {
            item.target = self
        }

        statusItem.menu = menu
        self.inited = true
    }
    
    func getRoutingItem() -> NSMenuItem {
        // 获取子菜单
        routingSubMenu = getRoutingSubMenus()
        // 返回菜单项
        let item = NSMenuItem(title: String(localized: .RoutingList), action: nil, keyEquivalent: "")
        item.submenu = routingSubMenu
        return item
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
        menu.toolTip = String(localized: mode.tip)
        return menu
    }

    func getRoutingSubMenus() -> NSMenu {
        
        let menu = NSMenu()

        let routings = RoutingViewModel.all()
        for routing in routings {
            let item = createRoutingMenuItem(routing: routing)
            menu.addItem(item)
        }
        return menu
    }
    
    private func createRoutingMenuItem(routing: RoutingModel) -> NSMenuItem {
        let item = NSMenuItem(title: routing.remark, action: #selector(switchRouting), keyEquivalent: "")
        item.representedObject = routing.uuid  // 可选：存储路由名称
        item.isEnabled =  true
        item.target = self
        item.state = (routing.uuid == AppState.shared.runningRouting) ? .on : .off
        logger.info("currentRouting: \(AppState.shared.runningRouting)")
        return item
    }
    
    func getServerItem() -> NSMenuItem {
        // 获取子菜单
        serverSubMenu = getServerSubMenus()
        // 返回菜单项
        let item = NSMenuItem(title: String(localized: .ServerList), action: nil, keyEquivalent: "")
        item.submenu = serverSubMenu
        return item
    }
    
    func getServerSubMenus() -> NSMenu {
        // 预先初始化一次
        pingItem = NSMenuItem(title: String(localized: .Ping), action: #selector(pingSpeed), keyEquivalent: "")
        pingItem.isEnabled = true
        pingItem.target = self

        let menu = NSMenu()
        menu.addItem(pingItem)
        menu.addItem(NSMenuItem.separator())
        
        // 直接拿有序数组
        let groupedServers = ProfileViewModel.getGroupedProfiles()
        let useGrouping = groupedServers.count >= 2
        
        if useGrouping {
            for (name, profiles) in groupedServers {
                let groupName = name.isEmpty ? "Default" : name
                let subMenu = NSMenu()
                let groupItem = NSMenuItem()
                groupItem.title = groupName
                groupItem.submenu = subMenu
                groupItem.image = NSImage(systemSymbolName: "folder", accessibilityDescription: nil)
                groupItem.state = profiles.contains { $0.uuid == AppState.shared.runningProfile } ? .on : .off
                
                for profile in profiles {
                    let item = createServerMenuItem(profile: profile)
                    subMenu.addItem(item)
                }
                menu.addItem(groupItem)
            }
        } else {
            for (_, profiles) in groupedServers {
                for profile in profiles {
                    let item = createServerMenuItem(profile: profile)
                    menu.addItem(item)
                }
            }
        }
        return menu
    }

    // 辅助方法：创建对齐的服务器菜单项
    private func createServerMenuItem(profile: ProfileModel) -> NSMenuItem {
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
        item.representedObject = profile.uuid
        item.isEnabled = true
        item.target = self
        item.state = profile.uuid == AppState.shared.runningProfile ? .on : .off
        item.toolTip = "\(profile.`protocol`)-\(profile.address):\(profile.port)-\(profile.uuid)"
        
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

    func openAdvanceSetting() {
        AppState.shared.mainTab = .setting
        AppState.shared.settingTab = .general
        self.openMainWindow()
    }

    @objc private func openLogs(_ sender: NSMenuItem) {
        OpenLogs(logFilePath: v2rayLogFilePath)
    }

    @objc private func toggleRunning(_ sender: NSMenuItem) {
        AppState.shared.toggleCore()
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
            logger.info("switchServer err")
            return
        }
        logger.info("switchServer: \(uuid)")
        AppState.shared.switchServer(uuid: uuid)
    }

    @objc private func switchRouting(_ sender: NSMenuItem) {
        guard let uuid = sender.representedObject as? String else {
            logger.info("switchRouting err")
            return
        }
        logger.info("switchRouting: \(uuid)")
        AppState.shared.switchRouting(uuid: uuid)
    }

    @objc private func goHelp(_ sender: NSMenuItem) {
        AppState.shared.mainTab = .help
        openMainWindow()
    }

    @objc private func switchRunMode(_ sender: NSMenuItem) {
        guard let modeRaw = sender.representedObject as? String, let mode = RunMode(rawValue: modeRaw) else {
            logger.info("switchRunMode err")
            return
        }
        logger.info("switchRunMode: \(mode.rawValue)")
        AppState.shared.switchRunMode(mode: mode)
    }

    @objc private func checkForUpdate(_ sender: NSMenuItem) {
        V2rayUpdater.checkForUpdates(showWindow: true)
    }

    @objc private func generateQrcode(_ sender: NSMenuItem) {
//        guard let v2ray = ProfileViewModel.getRunning() else {
//            logger.info("v2ray config not found")
//            noticeTip(title: "generate Qrcode fail", informativeText: "no available servers")
//            return
//        }
//
//        let share = ShareUri()
//        let uri = ShareUri.generateShareUri(item: v2ray)
//        if share.error.count > 0 {
//            noticeTip(title: "generate Qrcode fail", informativeText: share.error)
//            return
//        }
//
//        showQRCode(uri: uri)
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

// MARK: - 状态栏视图

struct StatusItemView: View {
    @ObservedObject var appState = AppState.shared // 显式使用 ObservedObject
    @ObservedObject var settings = AppSettings.shared // 显式使用 ObservedObject

    var body: some View {
        HStack() {
            // 应用图标
            Image(appState.icon)
                .resizable()
                .scaledToFit()
                .frame(width: 20, height: 20)
            if settings.showLatencyOnTray {
                // 延迟信息
                Text("● \(String(format: "%.0f", appState.latency)) ms")
                    .font(.system(size: 10))
                    .foregroundColor(.green) // 绿色
            }
            if settings.showSpeedOnTray {
                // 速度信息（两行显示）
                VStack(alignment: .leading) {
                    Text("↓ \(String(format: "%.0f", appState.proxyDownSpeed)) KB/s")
                    Text("↑ \(String(format: "%.0f", appState.proxyUpSpeed)) KB/s")
                }
                .font(.system(size: 9))
                .foregroundColor(.primary)
            }
            Spacer()
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .fixedSize()   // StatusBar自适应关键点: 需要 StatusItemView 设置 fixedSize 配合 statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    }
}

