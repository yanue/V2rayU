//
//  Preferences.swift
//  V2rayU
//
//  Created by yanue on 2018/10/19.
//  Copyright © 2018 yanue. All rights reserved.
//

import Cocoa
import Preferences

final class PreferenceAdvanceViewController: NSViewController, PreferencePane {
    let preferencePaneIdentifier = PreferencePane.Identifier.advanceTab
    let preferencePaneTitle = "Advance"
    let toolbarItemIcon = NSImage(named: NSImage.advancedName)!

    @IBOutlet weak var saveBtn: NSButtonCell!
    @IBOutlet weak var sockPort: NSTextField!
    @IBOutlet weak var httpPort: NSTextField!
    @IBOutlet weak var pacPort: NSTextField!

    @IBOutlet weak var enableUdp: NSButton!
    @IBOutlet weak var enableMux: NSButton!

    @IBOutlet weak var muxConcurrent: NSTextField!
    @IBOutlet weak var logLevel: NSPopUpButton!
    @IBOutlet weak var dnsServers: NSTextField!
    @IBOutlet weak var tips: NSTextField!
    
    override var nibName: NSNib.Name? {
        return "PreferenceAdvance"
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // fix: https://github.com/sindresorhus/Preferences/issues/31
        self.preferredContentSize = NSMakeSize(self.view.frame.size.width, self.view.frame.size.height);
        self.tips.stringValue = ""

        let enableMuxState = UserDefaults.getBool(forKey: .enableMux)
        let enableUdpState = UserDefaults.getBool(forKey: .enableUdp)

        let localSockPort = UserDefaults.get(forKey: .localSockPort) ?? "1080"
        let localHttpPort = UserDefaults.get(forKey: .localHttpPort) ?? "1087"
        let localPacPort = UserDefaults.get(forKey: .localPacPort) ?? "1085"

        let dnsServers = UserDefaults.get(forKey: .dnsServers) ?? ""
        let muxConcurrent = UserDefaults.get(forKey: .muxConcurrent) ?? "8"

        // select item
        print("logLevel",UserDefaults.get(forKey: .v2rayLogLevel) ?? "info")
        self.logLevel.selectItem(withTitle: UserDefaults.get(forKey: .v2rayLogLevel) ?? "info")

        self.enableUdp.state = enableUdpState ? .on : .off
        self.enableMux.state = enableMuxState ? .on : .off
        self.sockPort.stringValue = localSockPort
        self.httpPort.stringValue = localHttpPort
        self.pacPort.stringValue = localPacPort
        self.dnsServers.stringValue = dnsServers
        self.muxConcurrent.intValue = Int32(muxConcurrent) ?? 8;
    }

    @IBAction func saveSettings(_ sender: Any) {
        self.saveBtn.state = .on
        saveSettingsAndReload()
    }

    func saveSettingsAndReload() {

        let httpPortVal = self.httpPort.stringValue.replacingOccurrences(of: ",", with: "")
        let sockPortVal = self.sockPort.stringValue.replacingOccurrences(of: ",", with: "")
        let pacPortVal = self.pacPort.stringValue.replacingOccurrences(of: ",", with: "")

        let enableUdpVal = self.enableUdp.state.rawValue > 0
        let enableMuxVal = self.enableMux.state.rawValue > 0

        let dnsServersVal = self.dnsServers.stringValue
        let muxConcurrentVal = self.muxConcurrent.intValue
        
        // save
        UserDefaults.setBool(forKey: .enableUdp, value: enableUdpVal)
        UserDefaults.setBool(forKey: .enableMux, value: enableMuxVal)

        UserDefaults.set(forKey: .localHttpPort, value: httpPortVal)
        UserDefaults.set(forKey: .localSockPort, value: sockPortVal)
        UserDefaults.set(forKey: .localPacPort, value: pacPortVal)

        UserDefaults.set(forKey: .dnsServers, value: dnsServersVal)
        UserDefaults.set(forKey: .muxConcurrent, value: String(muxConcurrentVal))
        
        var logLevelName = "info"
        
        if let logLevelVal = self.logLevel.selectedItem {
            print("logLevelVal",logLevelVal)
            logLevelName = logLevelVal.title
            UserDefaults.set(forKey: .v2rayLogLevel, value: logLevelVal.title)
        }
        // replace
        v2rayConfig.httpPort = httpPortVal
        v2rayConfig.socksPort = sockPortVal
        v2rayConfig.enableUdp = enableUdpVal
        v2rayConfig.enableMux = enableMuxVal
        v2rayConfig.dns = dnsServersVal
        v2rayConfig.mux = Int(muxConcurrentVal)
        v2rayConfig.logLevel = logLevelName

        // set current server item and reload v2ray-core
        let item = V2rayServer.loadSelectedItem()
        if item != nil {
            // parse json
            v2rayConfig.parseJson(jsonText: item!.json)
            // combine with new settings and save
            _ = V2rayServer.save(idx: V2rayServer.getIndex(name: item!.name), isValid: v2rayConfig.isValid, jsonData: v2rayConfig.combineManual())
            // restart service
            menuController.startV2rayCore()
            // todo reload configWindow
        }

        // set HttpServerPacPort
        HttpServerPacPort = pacPortVal
        PACUrl = "http://127.0.0.1:" + String(HttpServerPacPort) + "/pac/pac.js"

        _ = GeneratePACFile()
        // restart pac http server
        V2rayLaunch.startHttpServer()
        
        self.tips.stringValue = "save success."
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            // your code here
            self.tips.stringValue = ""
        }
    }
}
