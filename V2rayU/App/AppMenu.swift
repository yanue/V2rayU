//
//  AppMenu.swift
//  V2rayU
//
//  Created by yanue on 2025/8/5.
//

import AppKit
import SwiftUI
import Combine
import KeyboardShortcuts

final class PingMenuItemView: NSView {
    private let titleField = NSTextField(labelWithString: "")
    private let clickHandler: () -> Void
    private var trackingAreaRef: NSTrackingArea?

    init(title: String, clickHandler: @escaping () -> Void) {
        self.clickHandler = clickHandler
        super.init(frame: NSRect(x: 0, y: 0, width: 240, height: 22))

        wantsLayer = true
        layer?.cornerRadius = 4

        titleField.stringValue = title
        titleField.font = .menuFont(ofSize: 0)
        titleField.textColor = .labelColor
        titleField.backgroundColor = .clear
        titleField.isBordered = false
        titleField.isEditable = false
        titleField.lineBreakMode = .byTruncatingTail
        titleField.translatesAutoresizingMaskIntoConstraints = false

        addSubview(titleField)
        NSLayoutConstraint.activate([
            // 对齐系统菜单项文本起始位置，给左侧预留勾选/图标槽位
            titleField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            titleField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            titleField.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingAreaRef {
            removeTrackingArea(trackingAreaRef)
        }
        let options: NSTrackingArea.Options = [.activeAlways, .mouseEnteredAndExited, .inVisibleRect]
        let trackingArea = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(trackingArea)
        trackingAreaRef = trackingArea
    }

    override func mouseEntered(with event: NSEvent) {
        layer?.backgroundColor = NSColor.selectedContentBackgroundColor.withAlphaComponent(0.18).cgColor
    }

    override func mouseExited(with event: NSEvent) {
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    override func mouseDown(with event: NSEvent) {
        clickHandler()
    }

    func updateTitle(_ title: String) {
        titleField.stringValue = title
        needsDisplay = true
    }
}

@MainActor
final class AppMenuManager: NSObject, NSMenuDelegate {
    static let shared = AppMenuManager()
    
    let versionController = AppVersionController()
    
    private var inited = false
    private var statusItem: NSStatusItem!
    private var hostingView: NSHostingView<StatusItemView>!
    // menu items
    private var coreStatusItem: NSMenuItem!
    private var toggleCoreItem: NSMenuItem!
    private var viewConfigItem: NSMenuItem!
    private var viewPacItem: NSMenuItem!
    private var viewLogItem: NSMenuItem!
    private var viewErrorLogItem: NSMenuItem!
    private var viewLogFilesItem: NSMenuItem!
    private var clearLogsItem: NSMenuItem!
    private var logsItem: NSMenuItem!
    private var logsSubMenu: NSMenu!
    private var pacModeItem: NSMenuItem!
    private var tunnelModeItem: NSMenuItem!
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
    private var pingTip: String = ""
    private var pingItemView: PingMenuItemView!
    private let pingTipSubject = PassthroughSubject<String, Never>()
    private var cancellables = Set<AnyCancellable>()
    private weak var statusMenu: NSMenu?

    override private init() {
        super.init()
        pingTipSubject // 500毫秒刷新一下,避免很多时一直刷新UI
            .throttle(for: .milliseconds(500), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] tip in
                self?.setPingMenuTitle(tip: tip)
            }
            .store(in: &cancellables)

        // 监听键盘快捷键变化
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardShortcutsDidChange),
            name: UserDefaults.didChangeNotification,
            object: nil
        )
    }

    @objc private nonisolated func keyboardShortcutsDidChange() {
        Task { @MainActor in
            AppMenuManager.shared.updateMenuKeyEquivalents()
        }
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
    
    func refreshPingTip(pingTip: String) {
        pingTipSubject.send(pingTip)
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
        // 刷新模式状态
        toggleCoreItem?.title = AppState.shared.v2rayTurnOn ? String(localized: .TurnCoreOff) : String(localized: .TurnCoreOn)
        pacModeItem.state = (.pac == AppState.shared.runMode) ? .on : .off
        tunnelModeItem.state = (.tun == AppState.shared.runMode) ? .on : .off
        globalModeItem.state = (.global == AppState.shared.runMode) ? .on : .off
        manualModeItem.state = (.manual == AppState.shared.runMode) ? .on : .off

        // 刷新快捷键显示
        updateMenuKeyEquivalents()
    }

    private func updateMenuKeyEquivalents() {
        // toggleCoreItem
        setKeyEquivalent(for: .toggleV2rayOnOff, menuItem: toggleCoreItem)
        // Tunnel Mode
        setKeyEquivalent(for: .switchToTunnelMode, menuItem: tunnelModeItem)
        // Global Mode
        setKeyEquivalent(for: .switchToGlobalMode, menuItem: globalModeItem)
        // Manual Mode
        setKeyEquivalent(for: .switchToManualMode, menuItem: manualModeItem)
        // PAC Mode
        setKeyEquivalent(for: .switchToPacMode, menuItem: pacModeItem)
        // View shortcuts
        setKeyEquivalent(for: .viewConfigJson, menuItem: viewConfigItem)
        setKeyEquivalent(for: .viewPacFile, menuItem: viewPacItem)
        setKeyEquivalent(for: .viewLog, menuItem: viewLogItem)
        // Tools shortcuts
        setKeyEquivalent(for: .pingSpeed, menuItem: pingItem)
        setKeyEquivalent(for: .importServers, menuItem: importServersItem)
        setKeyEquivalent(for: .scanQRCode, menuItem: scanQRCodeItem)
        setKeyEquivalent(for: .shareQRCode, menuItem: shareQRCodeItem)
        setKeyEquivalent(for: .copyHttpProxy, menuItem: copyHttpProxyItem)
    }

    private func setKeyEquivalent(for name: KeyboardShortcuts.Name, menuItem: NSMenuItem?) {
        guard let menuItem = menuItem else { return }

        if let shortcut = KeyboardShortcuts.getShortcut(for: name), let key = shortcut.key {
            menuItem.keyEquivalent = keyToString(key)
            menuItem.keyEquivalentModifierMask = shortcut.modifiers
        } else {
            menuItem.keyEquivalent = ""
            menuItem.keyEquivalentModifierMask = []
        }
    }

    private func keyToString(_ key: KeyboardShortcuts.Key) -> String {
        let keyCode = key.rawValue

        // Map common keys to their string representations
        let keyMap: [Int: String] = [
            0x00: "A", 0x01: "S", 0x02: "D", 0x03: "F", 0x04: "H",
            0x05: "G", 0x06: "Z", 0x07: "X", 0x08: "C", 0x09: "V",
            0x0B: "B", 0x0C: "Q", 0x0D: "W", 0x0E: "E", 0x0F: "R",
            0x10: "Y", 0x11: "T", 0x12: "1", 0x13: "2", 0x14: "3",
            0x15: "4", 0x16: "6", 0x17: "5", 0x18: "=", 0x19: "9",
            0x1A: "7", 0x1B: "-", 0x1C: "8", 0x1D: "0", 0x1E: "]",
            0x1F: "O", 0x20: "U", 0x21: "[", 0x22: "I", 0x23: "P",
            0x25: "L", 0x26: "J", 0x27: "'", 0x28: "K", 0x29: ";",
            0x2A: "\\", 0x2B: ",", 0x2C: "/", 0x2D: "N", 0x2E: "M",
            0x2F: ".", 0x32: "`", 0x24: "\r", 0x30: "\t", 0x31: " ",
            0x33: "\u{8}", 0x35: "\u{1B}",  // Delete and Escape
            0x7A: "F1", 0x78: "F2", 0x63: "F3", 0x76: "F4",
            0x60: "F5", 0x61: "F6", 0x62: "F7", 0x64: "F8",
            0x65: "F9", 0x6D: "F10", 0x67: "F11", 0x6F: "F12",
        ]

        return keyMap[keyCode] ?? String(format: "0x%02X", keyCode)
    }
    
    func updateMenuTitles() {
        if !inited {
            return
        }
        // coreStatusItem 使用 SwiftUI CoreStatusItemView 自动观察 AppState，无需手动更新 title
        setPingMenuTitle(tip: self.pingTip)
        diagnosticsItem?.title = String(localized: .Diagnostics)
        toggleCoreItem?.title = AppState.shared.v2rayTurnOn ? String(localized: .TurnCoreOff) : String(localized: .TurnCoreOn)
        viewConfigItem?.title = String(localized: .ViewConfigJson)
        viewPacItem?.title = String(localized: .ViewPacFile)
        viewLogItem?.title = String(localized: .ViewLog)
        viewErrorLogItem?.title = String(localized: .ViewErrorLog)
        viewLogFilesItem?.title = String(localized: .ViewLogFiles)
        clearLogsItem?.title = String(localized: .ClearAllLogs)
        logsItem?.title = String(localized: .Logs)
        pacModeItem?.title = String(localized: .PacMode)
        globalModeItem?.title = String(localized: .GlobalMode)
        manualModeItem?.title = String(localized: .ManualMode)
        tunnelModeItem?.title = String(localized: .TunnelMode)
        goSubscriptionsItem?.title = String(localized: .GoSubscriptionSettings)
        goRoutingSettingItem?.title = String(localized: .GoRoutingSettings)
        goServerSettingItem?.title = String(localized: .GoServerSettings)
        goPreferencesItem?.title = String(localized: .GoPreferences)
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

        toggleCoreItem = NSMenuItem(title: AppState.shared.v2rayTurnOn ? String(localized: .TurnCoreOff) : String(localized: .TurnCoreOn), action: #selector(toggleRunning), keyEquivalent: "t")
        viewConfigItem = NSMenuItem(title: String(localized: .ViewConfigJson), action: #selector(viewConfig), keyEquivalent: "")
        viewPacItem = NSMenuItem(title: String(localized: .ViewPacFile), action: #selector(viewPacFile), keyEquivalent: "")
        viewLogItem = NSMenuItem(title: String(localized: .ViewLog), action: #selector(openLogs), keyEquivalent: "")
        viewErrorLogItem = NSMenuItem(title: String(localized: .ViewErrorLog), action: #selector(openErrorLogs), keyEquivalent: "")
        viewLogFilesItem = NSMenuItem(title: String(localized: .ViewLogFiles), action: #selector(openLogFiles), keyEquivalent: "")
        clearLogsItem = NSMenuItem(title: String(localized: .ClearAllLogs), action: #selector(clearLogs), keyEquivalent: "")
        logsItem = getLogsItem()
        // 配置查看
        menu.addItem(toggleCoreItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(viewConfigItem)
        menu.addItem(viewPacItem)
        menu.addItem(NSMenuItem.separator())
        // 模式切换
        pacModeItem = getRunModeItem(mode: .pac, title: String(localized: .PacMode), keyEquivalent: "")
        globalModeItem = getRunModeItem(mode: .global, title: String(localized: .GlobalMode), keyEquivalent: "")
        manualModeItem = getRunModeItem(mode: .manual, title: String(localized: .ManualMode), keyEquivalent: "")
        tunnelModeItem = getRunModeItem(mode: .tun, title: String(localized: .TunnelMode), keyEquivalent: "")
        menu.addItem(pacModeItem)
        menu.addItem(tunnelModeItem)
        menu.addItem(globalModeItem)
        menu.addItem(manualModeItem)
        menu.addItem(NSMenuItem.separator())
        // 路由与服务器
        routingItem = getRoutingItem()
        serverItem = getServerItem()
        // 预先初始化一次
        pingItem = NSMenuItem()
        pingItemView = PingMenuItemView(title: String(localized: .LatencyTest)) { [weak self] in
            self?.showPingTestingState()
            self?.pingSpeedTest()
        }
        pingItem.view = pingItemView
        diagnosticsItem = NSMenuItem(title: String(localized: .Diagnostics), action: #selector(openDiagnostics), keyEquivalent: "")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(routingItem)
        menu.addItem(serverItem)
        menu.addItem(pingItem)
        menu.addItem(diagnosticsItem)
        // 预先初始化一次
        goRoutingSettingItem = NSMenuItem(title: String(localized: .GoRoutingSettings), action: #selector(openRoutingTab), keyEquivalent: "")
        goSubscriptionsItem = NSMenuItem(title: String(localized: .GoSubscriptionSettings), action: #selector(openPreferenceSubscribe), keyEquivalent: "")
        goServerSettingItem = NSMenuItem(title: String(localized: .GoServerSettings), action: #selector(openServerTab), keyEquivalent: "")
        goPreferencesItem = NSMenuItem(title: String(localized: .GoPreferences), action: #selector(openPreferenceGeneral), keyEquivalent: ",")
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
        helpItem = NSMenuItem(title: String(localized: .Help)+" (Xray-core \(getCoreShortVersion()))", action: #selector(goHelp), keyEquivalent: "")
        menu.addItem(logsItem)
        menu.addItem(checkForUpdatesItem)
        menu.addItem(helpItem)
        menu.addItem(NSMenuItem.separator())
        
        quitItem = NSMenuItem(title: String(localized: .Quit), action: #selector(terminateApp), keyEquivalent: "q")
        menu.addItem(quitItem)

        // 为所有菜单项设置 target
        for item in menu.items {
            item.target = self
        }

        menu.delegate = self
        statusItem.menu = menu
        statusMenu = menu
        self.inited = true
    }

    private func setPingMenuTitle(tip: String) {
        pingTip = tip
        guard let pingItem else { return }
        let suffix = tip.isEmpty ? "" : " \(tip)"
        let title = String(localized: .LatencyTest) + suffix
        pingItem.title = title
        pingItemView?.updateTitle(title)
        statusMenu?.itemChanged(pingItem)
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

    func getLogsItem() -> NSMenuItem {
        viewLogItem.target = self
        viewErrorLogItem.target = self
        viewLogFilesItem.target = self
        clearLogsItem.target = self

        logsSubMenu = NSMenu()
        logsSubMenu.addItem(viewLogItem)
        logsSubMenu.addItem(viewErrorLogItem)
        logsSubMenu.addItem(viewLogFilesItem)
        logsSubMenu.addItem(NSMenuItem.separator())
        logsSubMenu.addItem(clearLogsItem)

        let item = NSMenuItem(title: String(localized: .Logs), action: nil, keyEquivalent: "")
        item.submenu = logsSubMenu
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
        menu.state = (AppState.shared.v2rayTurnOn && mode == AppState.shared.runMode) ? .on : .off
        menu.toolTip = String(localized: mode.tip)
        return menu
    }

    func getRoutingSubMenus() -> NSMenu {
        
        let menu = NSMenu()

        let routings = RoutingStore.shared.fetchAll()
        for routing in routings {
            let item = createRoutingMenuItem(routing: routing)
            menu.addItem(item)
        }
        return menu
    }
    
    private func createRoutingMenuItem(routing: RoutingEntity) -> NSMenuItem {
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
        let groupedServers = ProfileStore.shared.getGroupedProfiles()
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
    private func createServerMenuItem(profile: ProfileEntity) -> NSMenuItem {
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

    func openConfigFile() {
        let confUrl = getConfigUrl()
        guard let url = URL(string: confUrl) else { return }
        NSWorkspace.shared.open(url)
    }

    func openPacFile() {
        let pacUrl = getPacUrl()
        guard let url = URL(string: pacUrl) else { return }
        NSWorkspace.shared.open(url)
    }

    func openLogsFile() {
        OpenLogs(logFilePath: coreLogFilePath)
    }

    func pingSpeedTest() {
        Task {
            await PingAll.shared.run()
        }
    }

    func showPingTestingState() {
        setPingMenuTitle(tip: " - " + String(localized: .Testing) + "...")
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        if menu === statusMenu {
            setPingMenuTitle(tip: pingTip)
        }
    }

    func importFromPasteboard() {
        if let uri = NSPasteboard.general.string(forType: .string), uri.count > 0 {
            importUri(url: uri)
        } else {
            noticeTip(title: "import server fail", informativeText: "no found vmess:// or vless:// or trojan:// or ss:// from Pasteboard")
        }
    }

    func scanQRCode() {
        let uri: String = Scanner.scanQRCodeFromScreen()
        if uri.count > 0 {
            importUri(url: uri)
        } else {
            noticeTip(title: "import server fail", informativeText: "no found qrcode")
        }
    }

    func shareQRCode() {
        guard let v2ray = AppState.shared.runningServer else {
            logger.info("v2ray config not found")
            noticeTip(title: "generate Qrcode fail", informativeText: "no available servers")
            return
        }
        ShareWindowManager.shared.openShareWindow(item: ProfileModel(from: v2ray))
    }

    func copyProxyExportCommand() {
        let httpPort = AppSettings.shared.httpPort
        let socksPort = AppSettings.shared.socksPort
        let command = "export http_proxy=http://127.0.0.1:\(httpPort);export https_proxy=http://127.0.0.1:\(httpPort);export ALL_PROXY=socks5://127.0.0.1:\(socksPort)"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(command, forType: NSPasteboard.PasteboardType.string)
        noticeTip(title: "Copied", informativeText: "Proxy export command copied to clipboard")
    }

    @objc private func openLogs(_ sender: NSMenuItem) {
        OpenLogs(logFilePath: coreLogFilePath)
    }

    @objc private func openErrorLogs(_ sender: NSMenuItem) {
        LogRotation.extractErrors()
        OpenLogs(logFilePath: LogRotation.recentErrorLogFilePath)
    }

    @objc private func openLogFiles(_ sender: NSMenuItem) {
        LogWindowManager.shared.openLogWindow()
    }

    @objc private func clearLogs(_ sender: NSMenuItem) {
        let alert = NSAlert()
        alert.messageText = String(localized: .ClearAllLogs)
        alert.informativeText = "确定要清除所有日志文件吗？此操作不可撤销。"
        alert.alertStyle = .warning
        alert.addButton(withTitle: String(localized: .Confirm))
        alert.addButton(withTitle: String(localized: .Cancel))
        
        if alert.runModal() == .alertFirstButtonReturn {
            LogRotation.clearAllLogs()
            noticeTip(title: String(localized: .ClearAllLogs), informativeText: "日志已清除")
        }
    }

    @objc private func toggleRunning(_ sender: NSMenuItem) {
        Task {
            await AppState.shared.toggleCore()
        }
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
        AppState.shared.mainTab = .diagnostic
        AppState.shared.helpTab = .qa
        MainWindowManager.shared.openMainWindow()
    }

    @objc private func switchServer(_ sender: NSMenuItem) {
        guard let uuid = sender.representedObject as? String else {
            logger.info("switchServer err")
            return
        }
        logger.info("switchServer: \(uuid)")
        Task {
            await AppState.shared.switchServer(uuid: uuid)
        }
    }

    @objc private func switchRouting(_ sender: NSMenuItem) {
        guard let uuid = sender.representedObject as? String else {
            logger.info("switchRouting err")
            return
        }
        logger.info("switchRouting: \(uuid)")
        Task {
            await AppState.shared.switchRouting(uuid: uuid)
        }
    }

    @objc private func goHelp(_ sender: NSMenuItem) {
        AppState.shared.mainTab = .diagnostic
        MainWindowManager.shared.openMainWindow()
    }

    @objc private func switchRunMode(_ sender: NSMenuItem) {
        guard let modeRaw = sender.representedObject as? String, let mode = RunMode(rawValue: modeRaw) else {
            logger.info("switchRunMode err")
            return
        }
        logger.info("switchRunMode: \(mode.rawValue)")
        Task {
            await AppState.shared.switchRunMode(mode: mode)
        }
    }

    @objc private func checkForUpdate(_ sender: NSMenuItem) {
        versionController.checkForUpdates(showWindow: true)
    }

    @objc private func generateQrcode(_ sender: NSMenuItem) {
        shareQRCode()
    }

    @objc private func copyExportCommand(_ sender: NSMenuItem) {
        copyProxyExportCommand()
    }

    @objc private func scanQrcode(_ sender: NSMenuItem) {
        scanQRCode()
    }

    @objc private func ImportFromPasteboard(_ sender: NSMenuItem) {
        importFromPasteboard()
    }
    @objc private func viewConfig(_ sender: Any) {
        openConfigFile()
    }

    @objc private func viewPacFile(_ sender: Any) {
        openPacFile()
    }


    @objc private func terminateApp() {
        NSApp.terminate(self)
    }
}
