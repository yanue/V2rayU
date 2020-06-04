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
    @IBOutlet weak var sockHost: NSTextField!
    @IBOutlet weak var httpHost: NSTextField!
    @IBOutlet weak var pacPort: NSTextField!

    @IBOutlet weak var enableUdp: NSButton!
    @IBOutlet weak var enableMux: NSButton!
    @IBOutlet weak var enableSniffing: NSButton!

    @IBOutlet weak var muxConcurrent: NSTextField!
    @IBOutlet weak var logLevel: NSPopUpButton!
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
        let enableSniffingState = UserDefaults.getBool(forKey: .enableSniffing)

        let localSockPort = UserDefaults.get(forKey: .localSockPort) ?? "1080"
        let localSockHost = UserDefaults.get(forKey: .localSockHost) ?? "127.0.0.1"
        let localHttpPort = UserDefaults.get(forKey: .localHttpPort) ?? "1087"
        let localHttpHost = UserDefaults.get(forKey: .localHttpHost) ?? "127.0.0.1"
        let localPacPort = UserDefaults.get(forKey: .localPacPort) ?? "11085"
        let muxConcurrent = UserDefaults.get(forKey: .muxConcurrent) ?? "8"

        // select item
        print("host", localSockHost, localHttpHost)
        self.logLevel.selectItem(withTitle: UserDefaults.get(forKey: .v2rayLogLevel) ?? "info")

        self.enableUdp.state = enableUdpState ? .on : .off
        self.enableMux.state = enableMuxState ? .on : .off
        self.enableSniffing.state = enableSniffingState ? .on : .off
        self.sockPort.stringValue = localSockPort
        self.sockHost.stringValue = localSockHost
        self.httpPort.stringValue = localHttpPort
        self.httpHost.stringValue = localHttpHost
        self.pacPort.stringValue = localPacPort
        self.muxConcurrent.intValue = Int32(muxConcurrent) ?? 8;
    }

    @IBAction func saveSettings(_ sender: Any) {
        self.saveBtn.state = .on
        saveSettingsAndReload()
    }

    func saveSettingsAndReload() {
        let httpPortVal = String(self.httpPort.intValue)
        let sockPortVal = String(self.sockPort.intValue)
        let pacPortVal = String(self.pacPort.intValue)

        let enableUdpVal = self.enableUdp.state.rawValue > 0
        let enableMuxVal = self.enableMux.state.rawValue > 0
        let enableSniffingVal = self.enableSniffing.state.rawValue > 0

        let muxConcurrentVal = self.muxConcurrent.intValue

        if httpPortVal == sockPortVal || httpPortVal == pacPortVal || sockPortVal == pacPortVal {
            self.tips.stringValue = "the ports(http,sock,pac) cannot be the same"

            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                // your code here
                self.tips.stringValue = ""
            }
            return
        }

        // save
        UserDefaults.setBool(forKey: .enableUdp, value: enableUdpVal)
        UserDefaults.setBool(forKey: .enableMux, value: enableMuxVal)
        UserDefaults.setBool(forKey: .enableSniffing, value: enableSniffingVal)

        UserDefaults.set(forKey: .localHttpPort, value: httpPortVal)
        UserDefaults.set(forKey: .localHttpHost, value: self.httpHost.stringValue)
        UserDefaults.set(forKey: .localSockPort, value: sockPortVal)
        UserDefaults.set(forKey: .localSockHost, value: self.sockHost.stringValue)
        UserDefaults.set(forKey: .localPacPort, value: pacPortVal)
        UserDefaults.set(forKey: .muxConcurrent, value: String(muxConcurrentVal))
        print("self.sockHost.stringValue", self.sockHost.stringValue)

        var logLevelName = "info"

        if let logLevelVal = self.logLevel.selectedItem {
            print("logLevelVal", logLevelVal)
            logLevelName = logLevelVal.title
            UserDefaults.set(forKey: .v2rayLogLevel, value: logLevelVal.title)
        }
        // replace
        v2rayConfig.httpPort = httpPortVal
        v2rayConfig.socksPort = sockPortVal
        v2rayConfig.enableUdp = enableUdpVal
        v2rayConfig.enableMux = enableMuxVal
        v2rayConfig.mux = Int(muxConcurrentVal)
        v2rayConfig.logLevel = logLevelName

        // set current server item and reload v2ray-core
        regenerateAllConfig()

        // set HttpServerPacPort
        HttpServerPacPort = pacPortVal
        PACUrl = "http://127.0.0.1:" + String(HttpServerPacPort) + "/pac/proxy.js"

        _ = GeneratePACFile(rewrite: true)
        // restart pac http server
        V2rayLaunch.startHttpServer()

        self.tips.stringValue = "save success."

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            // your code here
            self.tips.stringValue = ""
        }
    }
}
