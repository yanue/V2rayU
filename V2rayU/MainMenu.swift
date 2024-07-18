//
//  Menu.swift
//  V2rayU
//
//  Created by yanue on 2018/10/16.
//  Copyright © 2018 yanue. All rights reserved.
//

import Cocoa
import ServiceManagement

let menuController = (NSApplication.shared.delegate as? AppDelegate)?.statusMenu.delegate as! MenuController

// menu controller
class MenuController: NSObject, NSMenuDelegate {
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    var statusItemClicked: (() -> Void)?
    let lock = NSLock()

    @IBOutlet var pacMode: NSMenuItem!
    @IBOutlet var manualMode: NSMenuItem!
    @IBOutlet var globalMode: NSMenuItem!
    @IBOutlet var statusMenu: NSMenu!
    @IBOutlet var toggleV2rayItem: NSMenuItem!
    @IBOutlet var v2rayStatusItem: NSMenuItem!
    @IBOutlet var serverItems: NSMenuItem!
    @IBOutlet var newVersionItem: NSMenuItem!
    @IBOutlet var routingMenu: NSMenuItem!

    // when menu.xib loaded
    override func awakeFromNib() {
        print("awakeFromNib")
        super.awakeFromNib()
        statusMenu.delegate = self
        statusItem.menu = statusMenu

        // hide new version
        newVersionItem.isHidden = true
        
        showRouting()

        // windowWillClose Notification
        NotificationCenter.default.addObserver(self, selector: #selector(configWindowWillClose(notification:)), name: NSWindow.willCloseNotification, object: nil)
    }

    func setStatusOff() {
        DispatchQueue.main.async {
            if isMainland {
                self.v2rayStatusItem.title = "v2ray-core: 已关闭" + ("  (v" + appVersion + ")")
                self.toggleV2rayItem.title = "开启 v2ray-core"
            } else {
                self.v2rayStatusItem.title = "v2ray-core: Off" + ("  (v" + appVersion + ")")
                self.toggleV2rayItem.title = "Turn v2ray-core On"
            }

            if let button = self.statusItem.button {
                button.image = NSImage(named: NSImage.Name("IconOff"))
            }

            self.pacMode.state = .off
            self.globalMode.state = .off
            self.manualMode.state = .off

            // set off
            UserDefaults.setBool(forKey: .v2rayTurnOn, value: false)
        }
    }

    func setModeIcon(mode: RunMode) {
        DispatchQueue.main.async {
            var iconName = "IconOn"

            switch mode {
            case .global:
                iconName = "IconOnG"
                self.pacMode.state = .off
                self.globalMode.state = .on
                self.manualMode.state = .off
            case .manual:
                iconName = "IconOnM"
                self.pacMode.state = .off
                self.globalMode.state = .off
                self.manualMode.state = .on
            case .pac:
                iconName = "IconOnP"
                self.pacMode.state = .on
                self.globalMode.state = .off
                self.manualMode.state = .off
            default:
                break
            }

            if let button = self.statusItem.button {
                button.image = NSImage(named: NSImage.Name(iconName))
            }
        }
    }

    func setStatusOn(mode: RunMode) {
        DispatchQueue.main.async {
            if isMainland {
                self.v2rayStatusItem.title = "v2ray-core: 已启动" + ("  (v" + appVersion + ")")
                self.toggleV2rayItem.title = "关闭 v2ray-core"
            } else {
                self.v2rayStatusItem.title = "v2ray-core: On" + ("  (v" + appVersion + ")")
                self.toggleV2rayItem.title = "Turn v2ray-core Off"
            }
            self.setModeIcon(mode: mode)
            UserDefaults.setBool(forKey: .v2rayTurnOn, value: true)
        }
    }

    func setStatusMenuTip(pingTip: String) {
        DispatchQueue.main.async {
            if let item = self.statusMenu.item(withTag: 1) {
                item.title = pingTip
            }
        }
    }

    func showServers() {
        DispatchQueue.global().async {
            self.lock.lock()
            defer { self.lock.unlock() }

            print("showServers")
            let _subMenus = self.getServerMenus()

            DispatchQueue.main.async {
                self.serverItems.submenu = _subMenus
                // fix: must be used from main thread only
                configWindow.reloadData()
            }
        }
    }

    func showRouting() {
        DispatchQueue.global().async {
            let rules = V2rayRoutings.all()
//            print("showRouting", rules)
            let sumMenus = NSMenu()
            // add Routing... menu and click event is goRouting
            let routingMenuItem = NSMenuItem()
            if isMainland {
                routingMenuItem.title = "路由..."
            } else {
                routingMenuItem.title = "Routing..."
            }
            routingMenuItem.target = self
            routingMenuItem.action = #selector(self.goRouting(_:))
            sumMenus.addItem(routingMenuItem)
            // add separator menu item
            let separator = NSMenuItem.separator()
            sumMenus.addItem(separator)
            // now add all rules
            let routingRule = UserDefaults.get(forKey: .routingSelectedRule)
            for rule in rules {
                let menuItem = NSMenuItem()
                menuItem.title = rule.remark
                menuItem.target = self
                menuItem.action = #selector(self.switchRouting(_:))
                menuItem.representedObject = rule
                menuItem.isEnabled = true
                if rule.name == routingRule {
                    menuItem.state = NSControl.StateValue.on
                }
                sumMenus.addItem(menuItem)
            }
//            print("showRouting", sumMenus)
            // 假设 routingMenu 已经连接并且有一个子菜单
            DispatchQueue.main.async {
                self.routingMenu.submenu = sumMenus
            }
        }
    }

    func getServerMenus() -> NSMenu {
        // default
        let curSer = UserDefaults.get(forKey: .v2rayCurrentServerName)
        let _subMenus: NSMenu = NSMenu()
        // add new
        var validCount = 0
        var groupMenus: Dictionary = [String: NSMenu]()
        var chooseGroup = ""
        // for each
        for item in V2rayServer.all() {
            validCount += 1
            let menuItem: NSMenuItem = buildServerItem(item: item, curSer: curSer)
            var groupTag: String = item.subscribe
            if groupTag.isEmpty {
                groupTag = "default"
                _subMenus.addItem(menuItem)
                continue
            }
            if item.name == curSer {
                chooseGroup = groupTag
            }

            if let menu = groupMenus[groupTag] {
                menu.addItem(menuItem)
            } else {
                let newGroupMenu: NSMenu = NSMenu()
                groupMenus[groupTag] = newGroupMenu
                newGroupMenu.addItem(menuItem)
            }
        }

        // subscribe items
        for (itemKey, menu) in groupMenus {
            if itemKey == "default" {
                continue
            }
            let newGroup: NSMenuItem = NSMenuItem()
            var groupTagName = "🌏 订阅"
            if let sub = V2raySubItem.load(name: itemKey) {
                groupTagName = "🌏 " + sub.remark + " (\(menu.items.count))"
            }
            newGroup.submenu = menu
            newGroup.title = groupTagName
            newGroup.target = self
            newGroup.isEnabled = true
            if chooseGroup == itemKey {
                newGroup.state = NSControl.StateValue.on
            }
            _subMenus.addItem(newGroup)
        }

        if validCount == 0 {
            let menuItem: NSMenuItem = NSMenuItem()
            menuItem.title = "no available servers."
            menuItem.isEnabled = false
            _subMenus.addItem(menuItem)
        }

        return _subMenus
    }

    // build menu item by V2rayItem
    func buildServerItem(item: V2rayItem, curSer: String?) -> NSMenuItem {
        let menuItem: NSMenuItem = NSMenuItem()
        menuItem.title = getMenuServerTitle(item: item)
        menuItem.action = #selector(switchServer(_:))
        menuItem.representedObject = item
        menuItem.target = self
        menuItem.isEnabled = true
        if curSer == item.name {
            menuItem.state = NSControl.StateValue.on
        }
        return menuItem
    }

    @IBAction func openLogs(_ sender: NSMenuItem) {
        OpenLogs()
    }

    @IBAction func start(_ sender: NSMenuItem) {
        V2rayLaunch.ToggleRunning()
    }

    @IBAction func quitClicked(_ sender: NSMenuItem) {
        NSApplication.shared.terminate(self)
    }

    @IBAction func openPreferenceGeneral(_ sender: NSMenuItem) {
        DispatchQueue.main.async {
            preferencesWindowController.show(preferencePane: .generalTab)
            showDock(state: true)
        }
    }

    @IBAction func openPreferenceSubscribe(_ sender: NSMenuItem) {
        DispatchQueue.main.async {
            preferencesWindowController.show(preferencePane: .subscribeTab)
            showDock(state: true)
        }
    }

    @IBAction func openPreferencePac(_ sender: NSMenuItem) {
        DispatchQueue.main.async {
            preferencesWindowController.show(preferencePane: .pacTab)
            showDock(state: true)
        }
    }

    @IBAction func switchServer(_ sender: NSMenuItem) {
        guard let obj = sender.representedObject as? V2rayItem else {
            NSLog("switchServer err")
            return
        }
        UserDefaults.set(forKey: .v2rayCurrentServerName, value: obj.name)
        V2rayLaunch.restartV2ray()
    }

    @IBAction func switchRouting(_ sender: NSMenuItem) {
        guard let obj = sender.representedObject as? RoutingItem else {
            NSLog("switchRouting err")
            return
        }
        UserDefaults.set(forKey: .routingSelectedRule, value: obj.name)
        showRouting()
        V2rayLaunch.restartV2ray()
    }

    @IBAction func openConfig(_ sender: NSMenuItem) {
        OpenConfigWindow()
    }

    @objc private func configWindowWillClose(notification: Notification) {
        guard let object = notification.object as? NSWindow else {
            return
        }
        let allow_titles = ["V2rayU", "About", "Pac", "Subscription", "General", "Advance", "Dns", "Routing"]
        if allow_titles.contains(object.title) {
            showDock(state: false)
        }
    }

    @IBAction func goHelp(_ sender: NSMenuItem) {
        guard let url = URL(string: "https://github.com/yanue/v2rayu/issues") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    @IBAction func switchManualMode(_ sender: NSMenuItem) {
        UserDefaults.set(forKey: .runMode, value: RunMode.manual.rawValue)
        V2rayLaunch.restartV2ray()
    }

    @IBAction func switchPacMode(_ sender: NSMenuItem) {
        UserDefaults.set(forKey: .runMode, value: RunMode.pac.rawValue)
        V2rayLaunch.restartV2ray()
    }

    @IBAction func goRouting(_ sender: NSMenuItem) {
        DispatchQueue.main.async {
            preferencesWindowController.show(preferencePane: .routingTab)
            showDock(state: true)
        }
    }

    @IBAction func switchGlobalMode(_ sender: NSMenuItem) {
        UserDefaults.set(forKey: .runMode, value: RunMode.global.rawValue)
        V2rayLaunch.restartV2ray()
    }

    @IBAction func checkForUpdate(_ sender: NSMenuItem) {
        V2rayUpdater.checkForUpdates(showWindow: true)
    }

    @IBAction func generateQrcode(_ sender: NSMenuItem) {
        guard let v2ray = V2rayServer.loadSelectedItem() else {
            NSLog("v2ray config not found")
            noticeTip(title: "generate Qrcode fail", informativeText: "no available servers")
            return
        }

        let share = ShareUri()
        share.qrcode(item: v2ray)
        if share.error.count > 0 {
            noticeTip(title: "generate Qrcode fail", informativeText: share.error)
            return
        }

        showQRCode(uri: share.uri)
    }

    @IBAction func copyExportCommand(_ sender: NSMenuItem) {
        // Get the Http proxy config.
        let httpPort = UserDefaults.get(forKey: .localHttpPort) ?? "1087"
        let sockPort = UserDefaults.get(forKey: .localSockPort) ?? "1080"

        // Format an export string.
        let command = "export http_proxy=http://127.0.0.1:\(httpPort);export https_proxy=http://127.0.0.1:\(httpPort);export ALL_PROXY=socks5://127.0.0.1:\(sockPort)"

        // Copy to paste board.
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(command, forType: NSPasteboard.PasteboardType.string)

        // Show a toast notification.
        noticeTip(title: "Export Command Copied.", informativeText: "")
    }

    @IBAction func scanQrcode(_ sender: NSMenuItem) {
        let uri: String = Scanner.scanQRCodeFromScreen()
        if uri.count > 0 {
            importUri(url: uri)
        } else {
            noticeTip(title: "import server fail", informativeText: "no found qrcode")
        }
    }

    @IBAction func ImportFromPasteboard(_ sender: NSMenuItem) {
        if let uri = NSPasteboard.general.string(forType: .string), uri.count > 0 {
            importUri(url: uri)
        } else {
            noticeTip(title: "import server fail", informativeText: "no found vmess:// or vless:// or trojan:// or ss:// from Pasteboard")
        }
    }

    @IBAction func pingSpeed(_ sender: NSMenuItem) {
        ping.pingAll()
    }

    @IBAction func viewConfig(_ sender: Any) {
        let confUrl = getConfigUrl()
        guard let url = URL(string: confUrl) else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    @IBAction func viewPacFile(_ sender: Any) {
        let pacUrl = getPacUrl()
        guard let url = URL(string: pacUrl) else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    @IBAction func goRelease(_ sender: Any) {
        guard let url = URL(string: "https://github.com/yanue/v2rayu/releases") else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}

func getMenuServerTitle(item: V2rayItem) -> String {
    let speed = item.speed.count > 0 ? item.speed : "-1ms"
    let totalSpaceCnt = 10
    var spaceCnt = totalSpaceCnt - speed.count
    // littleSpace: 1,.
    if speed.contains(".") || speed.contains("1") {
        let littleSpaceCount = speed.filter({ $0 == "." }).count + speed.filter({ $0 == "1" }).count
        spaceCnt = totalSpaceCnt - ((speed.count - littleSpaceCount) + Int((speed.count - littleSpaceCount) / 2))
    }
    if speed.contains("-1ms") {
        spaceCnt = 9
    }
    let space = String(repeating: " ", count: spaceCnt < 0 ? 0 : spaceCnt) + "　"
    return speed + space + item.remark
}
