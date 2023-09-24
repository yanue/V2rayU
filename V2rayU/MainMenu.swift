//
//  Menu.swift
//  V2rayU
//
//  Created by yanue on 2018/10/16.
//  Copyright © 2018 yanue. All rights reserved.
//

import Cocoa
import ServiceManagement
import Preferences
import Sparkle
import Alamofire

let menuController = (NSApplication.shared.delegate as? AppDelegate)?.statusMenu.delegate as! MenuController
let V2rayUpdater = SUUpdater()

extension PreferencePane.Identifier {
    static let generalTab = Identifier("generalTab")
    static let advanceTab = Identifier("advanceTab")
    static let subscribeTab = Identifier("subscribeTab")
    static let pacTab = Identifier("pacTab")
    static let routingTab = Identifier("routingTab")
    static let dnsTab = Identifier("dnsTab")
    static let aboutTab = Identifier("aboutTab")
}

let preferencesWindowController = PreferencesWindowController(
        preferencePanes: [
            PreferenceGeneralViewController(),
            PreferenceAdvanceViewController(),
            PreferenceSubscribeViewController(),
            PreferencePacViewController(),
            PreferenceRoutingViewController(),
            PreferenceDnsViewController(),
            PreferenceAboutViewController(),
        ]
)
var qrcodeWindow = QrcodeWindowController()

var toastWindowCtrl: ToastWindowController!

func makeToast(message: String, displayDuration: Double? = 2) {
    return
    if toastWindowCtrl != nil {
        toastWindowCtrl.close()
    }
    toastWindowCtrl = ToastWindowController()
    toastWindowCtrl.message = message
    toastWindowCtrl.showWindow(Any.self)
    toastWindowCtrl.fadeInHud(displayDuration)
}

func ToggleRunning(_ toast: Bool = true) {
    // turn off
    if UserDefaults.getBool(forKey: .v2rayTurnOn) {
        menuController.stopV2rayCore()
        if toast {
            makeToast(message: "v2ray-core: Off")
        }
        return
    }

    // start
    menuController.startV2rayCore()
    if toast {
        makeToast(message: "v2ray-core: On")
    }
}

func SwitchProxyMode() {
    let runMode = RunMode(rawValue: UserDefaults.get(forKey: .runMode) ?? "manual") ?? .manual

    switch runMode {
    case .pac:
        menuController.switchRunMode(runMode: .global)
        makeToast(message: "V2rayU: global Mode")
        break
    case .global:
        menuController.switchRunMode(runMode: .manual)
        makeToast(message: "V2rayU: manual Mode")
        break
    case .manual:
        menuController.switchRunMode(runMode: .pac)
        makeToast(message: "V2rayU: pac Mode")
        break

    default: break
    }
}

// regenerate All Config when base setting changed
func regenerateAllConfig() {
    NSLog("regenerateAllConfig.")

    for (idx, item) in V2rayServer.list().enumerated() {
        if !item.isValid {
            continue
        }

        // parse old
        let vCfg = V2rayConfig()
        vCfg.parseJson(jsonText: item.json)

        // combine
        let text = vCfg.combineManual()
        _ = V2rayServer.save(idx: idx, isValid: vCfg.isValid, jsonData: text)

        print("regenerate config", item.remark)
    }

    // restart service
    let item = V2rayServer.loadSelectedItem()
    if item != nil {
        menuController.startV2rayCore()
    }

    // reload config window
    if menuController.configWindow != nil {
        // fix: must be used from main thread only
        DispatchQueue.main.async {
            menuController.configWindow.serversTableView.reloadData()
        }
    }
}

// menu controller
class MenuController: NSObject, NSMenuDelegate {
    var closedByConfigWindow: Bool = false
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    var statusItemClicked: (() -> Void)?
    var configWindow: ConfigWindowController!
    var lastRunMode: String = ""; // for backup system proxy
    let lock = NSLock()

    @IBOutlet weak var pacMode: NSMenuItem!
    @IBOutlet weak var manualMode: NSMenuItem!
    @IBOutlet weak var globalMode: NSMenuItem!
    @IBOutlet weak var statusMenu: NSMenu!
    @IBOutlet weak var toggleV2rayItem: NSMenuItem!
    @IBOutlet weak var v2rayStatusItem: NSMenuItem!
    @IBOutlet weak var serverItems: NSMenuItem!
    @IBOutlet weak var newVersionItem: NSMenuItem!

    // when menu.xib loaded
    override func awakeFromNib() {
        newVersionItem.isHidden = true
        
        // kill v2ray
        let pskillCmd = "ps aux | grep v2ray | grep '.V2rayU/config.json' | awk '{print $2}' | xargs kill"
        _ = shell(launchPath: "/bin/bash", arguments: ["-c", pskillCmd])
        
        // install before launch
        V2rayLaunch.install()

        // windowWillClose Notification
        NotificationCenter.default.addObserver(self, selector: #selector(configWindowWillClose(notification:)), name: NSWindow.willCloseNotification, object: nil)

        // Do any additional setup after loading the view.
        // initial auth ref
        let runMode = UserDefaults.get(forKey: .runMode) ?? "pac"
        switch runMode {
        case "pac":
            self.pacMode.state = .on
            self.globalMode.state = .off
            self.manualMode.state = .off
            break

        case "global":
            self.pacMode.state = .off
            self.globalMode.state = .on
            self.manualMode.state = .off
            break

        default: //manual
            self.pacMode.state = .off
            self.globalMode.state = .off
            self.manualMode.state = .on

            break
        }

        statusMenu.delegate = self
        NSLog("start menu")
        // load server list
        V2rayServer.loadConfig()
        // show server list
        self.showServers()

        statusItem.menu = statusMenu

        // version before 1.5.2: res.rawValue is 0 or -1
        let isOldConfigVersion = appVersion.compare("1.5.2", options: .numeric).rawValue > 0
        print("isOldConfigVersion", isOldConfigVersion)
        if !isOldConfigVersion {
            regenerateAllConfig()
        }

        if UserDefaults.getBool(forKey: .v2rayTurnOn) {
            // start
            // on status
            self.startV2rayCore()
        } else {
            // show off status
            self.setStatusOff()
        }

        // auto update subscribe servers
        if UserDefaults.getBool(forKey: .autoUpdateServers) {
            V2raySubSync().sync()
        }
    }

    @IBAction func openLogs(_ sender: NSMenuItem) {
        V2rayLaunch.OpenLogs()
    }

    func setStatusOff() {
        v2rayStatusItem.title = "v2ray-core: Off" + ("  (v" + appVersion + ")")
        toggleV2rayItem.title = "Turn v2ray-core On"

        if let button = statusItem.button {
            button.image = NSImage(named: NSImage.Name("IconOff"))
        }

        // set off
        UserDefaults.setBool(forKey: .v2rayTurnOn, value: false)
    }

    func setStatusOn(runMode: RunMode) {
        v2rayStatusItem.title = "v2ray-core: On" + ("  (v" + appVersion + ")")
        toggleV2rayItem.title = "Turn v2ray-core Off"

        var iconName = "IconOn"

        switch runMode {
        case .global:
            iconName = "IconOnG"
        case .manual:
            iconName = "IconOnM"
        case .pac:
            iconName = "IconOnP"
        default:
            break
        }

        if let button = statusItem.button {
            DispatchQueue.main.async {
                button.image = NSImage(named: NSImage.Name(iconName))
            }
        }

        // set on
        UserDefaults.setBool(forKey: .v2rayTurnOn, value: true)
    }

    func stopV2rayCore() {
        // set status
        self.setStatusOff()
        // stop launch
        V2rayLaunch.Stop()
        // off system proxy
        V2rayLaunch.setSystemProxy(mode: .off)
    }

    // start v2ray core
    func startV2rayCore() {
        NSLog("start v2ray-core begin")
        if !V2rayLaunch.checkPorts() {
            setStatusOff()
            return
        }

        guard let v2ray = V2rayServer.loadSelectedItem() else {
            noticeTip(title: "start v2ray fail", subtitle: "", informativeText: "v2ray config not found")
            setStatusOff()
            return
        }

        if !v2ray.isValid {
            noticeTip(title: "start v2ray fail", subtitle: "", informativeText: "invalid v2ray config")
            setStatusOff()
            return
        }

        let runMode = RunMode(rawValue: UserDefaults.get(forKey: .runMode) ?? "manual") ?? .manual

        // create json file
        V2rayLaunch.createJsonFile(item: v2ray)

        // set status
        setStatusOn(runMode: runMode)

        // launch
        V2rayLaunch.Start()
        NSLog("start v2ray-core done.")

        // switch run mode
        self.switchRunMode(runMode: runMode)
        
        // ping and refresh
        PingCurrent(item: v2ray).doPing()
    }
    
    @IBAction func start(_ sender: NSMenuItem) {
        ToggleRunning(false)
    }

    @IBAction func quitClicked(_ sender: NSMenuItem) {
        NSApplication.shared.terminate(self)
    }

    @IBAction func openPreferenceGeneral(_ sender: NSMenuItem) {
        preferencesWindowController.show(preferencePane: .generalTab)
    }

    @IBAction func openPreferenceSubscribe(_ sender: NSMenuItem) {
        preferencesWindowController.show(preferencePane: .subscribeTab)
    }

    @IBAction func openPreferencePac(_ sender: NSMenuItem) {
        preferencesWindowController.show(preferencePane: .pacTab)
    }

    // switch server
    @IBAction func switchServer(_ sender: NSMenuItem) {
        guard let obj = sender.representedObject as? V2rayItem else {
            NSLog("switchServer err")
            return
        }

        if !obj.isValid {
            NSLog("current server is invalid", obj.remark)
            return
        }
        // set current
        UserDefaults.set(forKey: .v2rayCurrentServerName, value: obj.name)
        // stop first
        V2rayLaunch.Stop()
        // start
        startV2rayCore()
        // reload menu
        self.showServers()
    }

    // open config window
    @IBAction func openConfig(_ sender: NSMenuItem) {
        if configWindow != nil {
            // close before
            if closedByConfigWindow {
                configWindow.close()
                // renew
                configWindow = ConfigWindowController()
            }
        } else {
            // renew
            configWindow = ConfigWindowController()
        }

        _ = self.showDock(state: true)
//        // show window
        configWindow.showWindow(nil)
        configWindow.window?.makeKeyAndOrderFront(self)
//        // bring to front
        NSApp.activate(ignoringOtherApps: true)
    }

    /// When a window was closed this methods takes care of releasing its controller.
    ///
    /// - parameter notification: The notification.
    @objc private func configWindowWillClose(notification: Notification) {
        guard let object = notification.object as? NSWindow else {
            return
        }

        // config window title is "V2rayU"
        if object.title == "V2rayU" {
            _ = self.showDock(state: false)
        }
    }

    func showDock(state: Bool) -> Bool {
        // Get transform state.
        var transformState: ProcessApplicationTransformState
        if state {
            transformState = ProcessApplicationTransformState(kProcessTransformToForegroundApplication)
        } else {
            transformState = ProcessApplicationTransformState(kProcessTransformToUIElementApplication)
        }

        // Show / hide dock icon.
        var psn = ProcessSerialNumber(highLongOfPSN: 0, lowLongOfPSN: UInt32(kCurrentProcess))
        let transformStatus: OSStatus = TransformProcessType(&psn, transformState)

        return transformStatus == 0
    }

    @IBAction func goHelp(_ sender: NSMenuItem) {
        guard let url = URL(string: "https://github.com/yanue/v2rayu/issues") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    func setStatusMenuTip(pingTip: String) {
        lock.lock()
        defer {
            lock.unlock()
        }
        do {
            if self.statusMenu.item(withTag: 1) != nil {
                self.statusMenu.item(withTag: 1)?.title = pingTip
            }
        }
    }
    
    func showServers() {
        print("showServers")
        lock.lock()
        defer {
            lock.unlock()
        }
        let curSer = UserDefaults.get(forKey: .v2rayCurrentServerName)
        // reload servers
        V2rayServer.loadConfig()
        let _subMenus: NSMenu = NSMenu()
        // add new
        var validCount = 0
        var groupMenus: Dictionary = [String: NSMenu]()
        var chooseGroup = ""
        for item in V2rayServer.list() {
            if !item.isValid {
                continue
            }
            validCount+=1
            let menuItem: NSMenuItem = buildServerItem(item: item, curSer: curSer)
            var groupTag: String = item.subscribe
            if (groupTag.isEmpty) {
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
        for (itemKey,menu) in groupMenus {
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
        serverItems.submenu = _subMenus
        
        if menuController.configWindow != nil {
            DispatchQueue.main.async {
                // fix: must be used from main thread only
                menuController.configWindow.serversTableView.reloadData()
            }
        }
    }
    
    // build menu item by V2rayItem
    func buildServerItem(item: V2rayItem, curSer: String?) -> NSMenuItem {
        let menuItem: NSMenuItem = NSMenuItem()
        let speed = item.speed.count > 0 ? item.speed : "-1ms"
        let totalSpaceCnt = 10
        var spaceCnt = totalSpaceCnt - speed.count
        // littleSpace: 1,.
        if speed.contains(".") || speed.contains("1") {
            let littleSpaceCount = speed.filter({ $0 == "." }).count + speed.filter({ $0 == "1" }).count
            spaceCnt = totalSpaceCnt - ((speed.count - littleSpaceCount) + Int((speed.count - littleSpaceCount)/2))
        }
        if speed.contains("-1ms") {
            spaceCnt = 9
        }
        let space = String(repeating: " ", count: spaceCnt < 0 ? 0 : spaceCnt) + "　"

        menuItem.title = speed + space + item.remark
        menuItem.action = #selector(self.switchServer(_:))
        menuItem.representedObject = item
        menuItem.target = self
        menuItem.isEnabled = true

        if curSer == item.name || V2rayServer.count() == 1 {
            menuItem.state = NSControl.StateValue.on
        }
        return menuItem
    }

    @IBAction func switchManualMode(_ sender: NSMenuItem) {
        // disable
        switchRunMode(runMode: .manual)
        lastRunMode = RunMode.manual.rawValue
    }

    @IBAction func switchPacMode(_ sender: NSMenuItem) {
        // switch mode
        switchRunMode(runMode: .pac)
        lastRunMode = RunMode.pac.rawValue
    }

    // MARK: - actions
    @IBAction func switchGlobalMode(_ sender: NSMenuItem) {
        // switch mode
        switchRunMode(runMode: .global)
        lastRunMode = RunMode.global.rawValue
    }

    func switchRunMode(runMode: RunMode) {
        // save
        UserDefaults.set(forKey: .runMode, value: runMode.rawValue)
        // state
        self.globalMode.state = runMode == .global ? .on : .off
        self.pacMode.state = runMode == .pac ? .on : .off
        self.manualMode.state = runMode == .manual ? .on : .off
       
        // set icon
        setStatusOn(runMode: runMode)
        // launch
        V2rayLaunch.Start()
        // manual mode
        if lastRunMode == RunMode.manual.rawValue {
            // backup first
            V2rayLaunch.setSystemProxy(mode: .off)
        }

        // global
        if runMode == .global {
            V2rayLaunch.setSystemProxy(mode: .global)
            return
        }

        V2rayLaunch.setSystemProxy(mode: runMode)
    }

    @IBAction func checkForUpdate(_ sender: NSMenuItem) {
        menuController.checkV2rayUVersion()
        // need set SUFeedURL into plist
        V2rayUpdater.checkForUpdates(sender)
    }

    @IBAction func generateQrcode(_ sender: NSMenuItem) {
        guard let v2ray = V2rayServer.loadSelectedItem() else {
            NSLog("v2ray config not found")
            noticeTip(title: "generate Qrcode fail", subtitle: "", informativeText: "no available servers")
            return
        }

        let share = ShareUri()
        share.qrcode(item: v2ray)
        if share.error.count > 0 {
            noticeTip(title: "generate Qrcode fail", subtitle: "", informativeText: share.error)
            return
        }

        // close before
        qrcodeWindow.close()
        // renew
        qrcodeWindow = QrcodeWindowController()
        // show window
        qrcodeWindow.showWindow(nil)
        // center
        qrcodeWindow.window?.center()
        // set uri
        qrcodeWindow.setShareUri(uri: share.uri)
        // bring to front
        NSApp.activate(ignoringOtherApps: true)
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
        noticeTip(title: "Export Command Copied.", subtitle: "", informativeText: command)
    }

    @IBAction func scanQrcode(_ sender: NSMenuItem) {
        let uri: String = Scanner.scanQRCodeFromScreen()
        if uri.count > 0 {
            self.importUri(url: uri)
        } else {
            noticeTip(title: "import server fail", subtitle: "", informativeText: "no found qrcode")
        }
    }

    @IBAction func ImportFromPasteboard(_ sender: NSMenuItem) {
        if let uri = NSPasteboard.general.string(forType: .string), uri.count > 0 {
            self.importUri(url: uri)
        } else {
            noticeTip(title: "import server fail", subtitle: "", informativeText: "no found vmess:// or vless:// or trojan:// or ss:// from Pasteboard")
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

    func importUri(url: String) {
        let urls = url.split(separator: "\n")

        for url in urls {
            let uri = url.trimmingCharacters(in: .whitespaces)

            if uri.count == 0 {
                noticeTip(title: "import server fail", subtitle: "", informativeText: "import error: uri not found")
                continue
            }

            // ss://YWVzLTI1Ni1jZmI6ZUlXMERuazY5NDU0ZTZuU3d1c3B2OURtUzIwMXRRMERAMTcyLjEwNS43MS44Mjo4MDk5#翻墙党325.06美国 类型这种含中文的格式不是标准的URL格式
            if !ImportUri.supportProtocol(uri: uri) {
                noticeTip(title: "import server fail", subtitle: "", informativeText: "no found vmess:// or vless:// or trojan:// or ss:// ")
                continue
            }

            if let importUri = ImportUri.importUri(uri: uri) {
                self.saveServer(importUri: importUri)
                continue
            }

            noticeTip(title: "import server fail", subtitle: "", informativeText: "no found vmess:// or vless:// or trojan:// or ss:// ")
        }
    }

    func saveServer(importUri: ImportUri) {
        if importUri.isValid {
            // add server
            V2rayServer.add(remark: importUri.remark, json: importUri.json, isValid: true, url: importUri.uri)
            // refresh server
            self.showServers()

            noticeTip(title: "import server success", subtitle: "", informativeText: importUri.remark)
        } else {
            noticeTip(title: "import server fail", subtitle: "", informativeText: importUri.error)
        }
    }

    func noticeTip(title: String = "", subtitle: String = "", informativeText: String = "") {
        makeToast(message: title + (subtitle.count > 0 ? " - " + subtitle : "") + " : " + informativeText)
    }

    @IBAction func goRelease(_ sender: Any) {
        guard let url = URL(string: "https://github.com/yanue/v2rayu/releases") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    func checkV2rayUVersion() {
        // 当前版本检测
        Alamofire.request("https://api.github.com/repos/yanue/V2rayU/releases/latest").responseJSON { [self] response in
            //to get status code
            if let status = response.response?.statusCode {
                if status != 200 {
                    NSLog("error with response status: ", status)
                    return
                }
            }

            //to get JSON return value
            if let result = response.result.value {
                let JSON = result as! NSDictionary

                // get tag_name (verion)
                guard let tag_name = JSON["tag_name"] else {
                    NSLog("error: no tag_name")
                    return
                }

                // get prerelease and draft
                guard let prerelease = JSON["prerelease"], let draft = JSON["draft"] else {
                    // get
                    NSLog("error: get prerelease or draft")
                    return
                }

                // not pre release or draft
                if prerelease as! Bool == true || draft as! Bool == true {
                    NSLog("this release is a prerelease or draft")
                    return
                }

                let newVer = (tag_name as! String)
                // get old versiion
                let oldVer = appVersion.replacingOccurrences(of: "v", with: "").versionToInt()
                let curVer = newVer.replacingOccurrences(of: "v", with: "").versionToInt()

                // compare with [Int]
                if oldVer.lexicographicallyPrecedes(curVer) {
                    newVersionItem.isHidden = false
                    newVersionItem.title = "has new version " + newVer
                } else {
                    newVersionItem.isHidden = true
                }
            }
        }
    }
}
