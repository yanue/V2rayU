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
    private var diagnosticsItem: NSMenuItem!
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
        // coreStatusItem 使用 SwiftUI CoreStatusItemView 自动观察 AppState，无需手动更新 title
        toggleCoreItem?.title = AppState.shared.v2rayTurnOn ? String(localized: .TurnCoreOff) : String(localized: .TurnCoreOn)
        pacModeItem.state = (.pac == AppState.shared.runMode) ? .on : .off
        globalModeItem.state = (.global == AppState.shared.runMode) ? .on : .off
        manualModeItem.state = (.manual == AppState.shared.runMode) ? .on : .off
    }
    
    func updateMenuTitles() {
        if !inited {
            return
        }
        // coreStatusItem 使用 SwiftUI CoreStatusItemView 自动观察 AppState，无需手动更新 title
        pingItem?.title = String(localized: .Ping)
        diagnosticsItem?.title = String(localized: .Diagnostics)
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
        coreStatusItem = getCoreStatusItem()
        menu.addItem(coreStatusItem)
        menu.addItem(NSMenuItem.separator())

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
        // 预先初始化一次
        pingItem = NSMenuItem(title: String(localized: .Ping), action: #selector(pingSpeed), keyEquivalent: "")
        diagnosticsItem = NSMenuItem(title: String(localized: .Diagnostics), action: #selector(openDiagnostics), keyEquivalent: "")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(routingItem)
        menu.addItem(serverItem)
        menu.addItem(pingItem)
        menu.addItem(diagnosticsItem)
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
        checkForUpdatesItem = NSMenuItem(title: String(localized: .CheckForUpdates)+" (V2rayU v\(appVersion))", action: #selector(checkForUpdate), keyEquivalent: "")
        helpItem = NSMenuItem(title: String(localized: .Help)+" (Xray-core \(getCoreShortVersion()))", action: #selector(checkForUpdate), keyEquivalent: "")
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
    
    func getCoreStatusItem() -> NSMenuItem {
        // 使用 SwiftUI 视图替换原始的 title-only 菜单项，CoreStatusItemView 会观察 AppState 自动刷新
        let item = NSMenuItem()
        // 创建一个 HostingView 并赋给 menu item 的 view
        let coreHosting = NSHostingView(rootView: CoreStatusItemView())
        // 给 hosting view 一个合理的固有大小（根据视图内容微调）
        coreHosting.translatesAutoresizingMaskIntoConstraints = false
        coreHosting.frame = NSRect(x: 0, y: 0, width: 220, height: 40)
        item.view = coreHosting
        item.isEnabled = false
        return item
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

        let menu = NSMenu()
        
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
        let speedText: String = "[\(profile.speed)ms]"
        let speedColor: NSColor = getSpeedColor(latency: Double(profile.speed))
        
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
        MainWindowManager.shared.openMainWindow()
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
        MainWindowManager.shared.openMainWindow()
    }

    @objc private func openPreferenceSubscribe(_ sender: NSMenuItem) {
        AppState.shared.mainTab = .subscription
        MainWindowManager.shared.openMainWindow()
    }

    @objc private func openPreferencePac(_ sender: NSMenuItem) {
        AppState.shared.mainTab = .setting
        AppState.shared.settingTab = .pac
        MainWindowManager.shared.openMainWindow()
    }
    
    @objc private func openRoutingTab(_ sender: NSMenuItem) {
        AppState.shared.mainTab = .routing
        MainWindowManager.shared.openMainWindow()
    }
    
    @objc private func openServerTab(_ sender: NSMenuItem) {
        AppState.shared.mainTab = .server
        MainWindowManager.shared.openMainWindow()
    }
    
    @objc private func openDiagnostics(_ sender: NSMenuItem) {
        AppState.shared.mainTab = .help
        AppState.shared.helpTab = .diagnostic
        MainWindowManager.shared.openMainWindow()
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
        MainWindowManager.shared.openMainWindow()
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
        guard let v2ray = AppState.shared.runningServer else {
            logger.info("v2ray config not found")
            noticeTip(title: "generate Qrcode fail", informativeText: "no available servers")
            return
        }
        ShareWindowManager.shared.openShareWindow(item: v2ray)
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
                    .foregroundColor(Color(getSpeedColor(latency: appState.latency))) // 绿色
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

struct CoreStatusItemView: View {
    @ObservedObject var appState = AppState.shared

    var body: some View {
        HStack() {
            HStack(spacing: 0) {
                Image(systemName: appState.v2rayTurnOn ? "wifi" : "wifi.slash")
                // 延迟信息
                Text(" \(String(format: "%.0f", appState.latency)) ms")
                    .font(.system(size: 11))
            }
            .foregroundColor(Color(appState.v2rayTurnOn ? getSpeedColor(latency: appState.latency) : .systemGray))

            
            Spacer()
            
            HStack{
                Text("↑ \(String(format: "%.0f", appState.proxyUpSpeed)) KB/s")
                    .font(.system(size: 11))
                    .foregroundColor(Color(appState.v2rayTurnOn ? .systemBlue : .systemGray))

                Text("↓ \(String(format: "%.0f", appState.proxyDownSpeed)) KB/s")
                    .font(.system(size: 11))
                    .foregroundColor(Color(appState.v2rayTurnOn ? .systemRed : .systemGray))
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 22)
    }
}
