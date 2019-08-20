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

let menuController = (NSApplication.shared.delegate as? AppDelegate)?.statusMenu.delegate as! MenuController
let V2rayUpdater = SUUpdater()

extension PreferencePane.Identifier {
    static let generalTab = Identifier("generalTab")
    static let advanceTab = Identifier("advanceTab")
    static let subscribeTab = Identifier("subscribeTab")
    static let pacTab = Identifier("pacTab")
    static let aboutTab = Identifier("aboutTab")
}

let preferencesWindowController = PreferencesWindowController(
        preferencePanes: [
            PreferenceGeneralViewController(),
            PreferenceAdvanceViewController(),
            PreferenceSubscribeViewController(),
            PreferencePacViewController(),
            PreferenceAboutViewController(),
        ]
)
var qrcodeWindow = QrcodeWindowController()

// menu controller
class MenuController: NSObject, NSMenuDelegate {
    var closedByConfigWindow: Bool = false
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    var statusItemClicked: (() -> Void)?
    var configWindow: ConfigWindowController!
    var lastRunMode: String = ""; // for backup system proxy

    @IBOutlet weak var pacMode: NSMenuItem!
    @IBOutlet weak var manualMode: NSMenuItem!
    @IBOutlet weak var globalMode: NSMenuItem!
    @IBOutlet weak var statusMenu: NSMenu!
    @IBOutlet weak var toggleV2rayItem: NSMenuItem!
    @IBOutlet weak var v2rayStatusItem: NSMenuItem!
    @IBOutlet weak var serverItems: NSMenuItem!

    // when menu.xib loaded
    override func awakeFromNib() {
        V2rayLaunch.chmodCmdPermission()

        // backup system proxy when init
        V2rayLaunch.setSystemProxy(mode: .backup)

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

//        self.configWindow = ConfigWindowController()

        if UserDefaults.getBool(forKey: .v2rayTurnOn) {
            // start
            // on status
            self.startV2rayCore()
        } else {
            // show off status
            self.setStatusOff()
        }

        // windowWillClose Notification
        NotificationCenter.default.addObserver(self, selector: #selector(configWindowWillClose(notification:)), name: NSWindow.willCloseNotification, object: nil)
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

    func setStatusOn() {
        v2rayStatusItem.title = "v2ray-core: On" + ("  (v" + appVersion + ")")
        toggleV2rayItem.title = "Turn v2ray-core Off"

        if let button = statusItem.button {
            button.image = NSImage(named: NSImage.Name("IconOn"))
        }

        // set on
        UserDefaults.setBool(forKey: .v2rayTurnOn, value: true)
    }

    func stopV2rayCore() {
        // set status
        self.setStatusOff()
        // stop launch
        V2rayLaunch.Stop()
        // restore system proxy
        V2rayLaunch.setSystemProxy(mode: .restore)
    }

    // start v2ray core
    func startV2rayCore() {
        NSLog("start v2ray-core begin")

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

        // create json file
        V2rayConfig.createJsonFile(item: v2ray)

        // set status
        setStatusOn()

        // launch
        V2rayLaunch.Start()
        NSLog("start v2ray-core done.")

        let runMode = RunMode(rawValue: UserDefaults.get(forKey: .runMode) ?? "manual") ?? .manual
        // switch run mode
        self.switchRunMode(runMode: runMode)
    }

    @IBAction func start(_ sender: NSMenuItem) {
        // turn off
        if UserDefaults.getBool(forKey: .v2rayTurnOn) {
            self.stopV2rayCore()
            return
        }

        // start
        self.startV2rayCore()
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
            NSLog("current server is invaid", obj.remark)
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

        self.showDock(state: true)
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
        guard let url = URL(string: "https://github.com/yanue/v2rayu/wiki") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    func showServers() {
        // reomve old items
        serverItems.submenu?.removeAllItems()
        let curSer = UserDefaults.get(forKey: .v2rayCurrentServerName)

        // add new
        var validCount = 0
        for item in V2rayServer.list() {
            if !item.isValid {
                continue
            }

            let menuItem: NSMenuItem = NSMenuItem()
            menuItem.title = item.remark
            menuItem.action = #selector(self.switchServer(_:))
            menuItem.representedObject = item
            menuItem.target = self
            menuItem.isEnabled = true

            if curSer == item.name || V2rayServer.count() == 1 {
                menuItem.state = NSControl.StateValue.on
            }

            serverItems.submenu?.addItem(menuItem)
            validCount += 1
        }

        if validCount == 0 {
            let menuItem: NSMenuItem = NSMenuItem()
            menuItem.title = "no available servers."
            menuItem.isEnabled = false
            serverItems.submenu?.addItem(menuItem)
        }
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
        // enable
        var sockPort = ""
        var httpPort = ""

        let v2ray = V2rayServer.loadSelectedItem()

        if v2ray != nil && v2ray!.isValid {
            let cfg = V2rayConfig()
            cfg.parseJson(jsonText: v2ray!.json)
            sockPort = cfg.socksPort
            httpPort = cfg.httpPort
        }

        // manual mode
        if lastRunMode == RunMode.manual.rawValue {
            // backup first
            V2rayLaunch.setSystemProxy(mode: .backup)
        }

        // global
        if runMode == .global {
            V2rayLaunch.setSystemProxy(mode: .global, httpPort: httpPort, sockPort: sockPort)
            return
        }

        // pac mode
        if runMode == .pac {
            // generate pac file
            _ = GeneratePACFile()
        }

        V2rayLaunch.setSystemProxy(mode: runMode)
    }

    @IBAction func checkForUpdate(_ sender: NSMenuItem) {
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

        // Format an export string.
        let command = "export http_proxy=http://127.0.0.1:\(httpPort);export https_proxy=http://127.0.0.1:\(httpPort);"

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
            noticeTip(title: "import server fail", subtitle: "", informativeText: "no found ss:// , ssr:// or vmess:// from Pasteboard")
        }
    }

    func importUri(url: String) {
        let uri = url.trimmingCharacters(in: .whitespaces)

        if uri.count == 0 {
            noticeTip(title: "import server fail", subtitle: "", informativeText: "import error: uri not found")
            return
        }

        if URL(string: uri) == nil {
            noticeTip(title: "import server fail", subtitle: "", informativeText: "no found ss:// , ssr:// or vmess://")
            return
        }

        if let importUri = ImportUri.importUri(uri: uri) {
            self.saveServer(importUri: importUri)
            return
        }

        noticeTip(title: "import server fail", subtitle: "", informativeText: "no found ss:// , ssr:// or vmess://")
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
        // 定义NSUserNotification
        let userNotification = NSUserNotification()
        userNotification.title = title
        userNotification.subtitle = subtitle
        userNotification.informativeText = informativeText
        // 使用NSUserNotificationCenter发送NSUserNotification
        let userNotificationCenter = NSUserNotificationCenter.default
        userNotificationCenter.scheduleNotification(userNotification)
    }
}
