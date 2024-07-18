//
//  Launch.swift
//  V2rayU
//
//  Created by yanue on 2018/10/17.
//  Copyright © 2018 yanue. All rights reserved.
//

import Cocoa
import Swifter
import SystemConfiguration

let LAUNCH_AGENT_NAME = "yanue.v2rayu.v2ray-core"
let AppResourcesPath = Bundle.main.bundlePath + "/Contents/Resources"
let AppHomePath = NSHomeDirectory() + "/.V2rayU"
let v2rayUTool = AppHomePath + "/V2rayUTool"
let v2rayCorePath = AppHomePath + "/v2ray-core"
let v2rayCoreFile = v2rayCorePath + "/v2ray"
let logFilePath = AppHomePath + "/v2ray-core.log"
let JsonConfigFilePath = AppHomePath + "/config.json"
var webServer = HttpServer()

enum RunMode: String {
    case global
    case off
    case manual
    case pac
    case backup
    case restore
}

// 高版本macos执行NSAppleScript会出现授权失败
func executeAppleScriptWithOsascript(script: String) {
    do {
        let output = try runCommand(at: "/usr/bin/osascript", with: ["-e", "do shell script \"" + script + "\" with administrator privileges"])
        print("executeAppleScript-Output: \(output)")
    } catch {
        print("executeAppleScript-Error: \(error)")
        var title = "Install V2rayUTool Failed";
        var toast =  "Error: \(error),\nYou need execute scripts manually:\n \(script)";
        if isMainland {
            title = "安装 V2rayUTool 失败"
            toast = "安装失败: \(error)\n, 你需要在命令行手动执行一下: \(script)"
        }
        alertDialog(title: title, message: toast)
    }
}

class V2rayLaunch: NSObject {
    static func checkInstall() {
        // Ensure launch agent directory is existed.
        let fileMgr = FileManager.default
        if !fileMgr.fileExists(atPath: AppHomePath) {
            print("app home dir \(AppHomePath) not exists,need install")
            try! fileMgr.createDirectory(atPath: AppHomePath, withIntermediateDirectories: true, attributes: nil)
        }

        // make sure new version
        NSLog("install", AppResourcesPath)
        var needRunInstall = false
        if !FileManager.default.fileExists(atPath: v2rayCoreFile) {
            NSLog("\(v2rayCoreFile) not exists,need install")
            needRunInstall = true
        }
        if !needRunInstall && !FileManager.default.isExecutableFile(atPath: v2rayCoreFile) {
            NSLog("\(v2rayCoreFile) not accessable")
            needRunInstall = true
        }
        if !needRunInstall && !FileManager.default.isExecutableFile(atPath: v2rayUTool) {
            needRunInstall = true
        }
        if !needRunInstall && !FileManager.default.fileExists(atPath: v2rayCorePath + "/geoip.dat") {
            NSLog("\(v2rayCorePath)/geoip.dat not exists,need install")
            needRunInstall = true
        }
        if !needRunInstall && !FileManager.default.fileExists(atPath: PACAbpFile) {
            NSLog("\(PACAbpFile) not exists,need install")
            needRunInstall = true
        }
        if !needRunInstall && !FileManager.default.fileExists(atPath: GFWListFilePath) {
            NSLog("\(GFWListFilePath) not exists,need install")
            needRunInstall = true
        }
        if !needRunInstall && !FileManager.default.fileExists(atPath: PACUserRuleFilePath) {
            NSLog("\(PACUserRuleFilePath) not exists,need install")
            needRunInstall = true
        }
        if !needRunInstall && !FileManager.default.fileExists(atPath: v2rayUTool) {
            NSLog("\(v2rayUTool) not exists,need install")
            needRunInstall = true
        }
        // Ensure permission with root admin
        if !needRunInstall && !checkFileIsRootAdmin(file: v2rayUTool) {
            needRunInstall = true
        }
        if !needRunInstall {
            // use /bin/bash to fix crash when V2rayUTool is not exist
            let toolVersion = shell(launchPath: "/bin/bash", arguments: ["-c", "\(v2rayUTool) version"])
            NSLog("toolVersion - \(v2rayUTool): \(String(describing: toolVersion))")
            if toolVersion != nil {
                let _version = toolVersion ?? "" // old version
                if _version.contains("Usage:") {
                    NSLog("\(v2rayUTool) old version,need install")
                    needRunInstall = true
                } else {
                    if !(_version >= "4.0.0") {
                        NSLog("\(v2rayUTool) old version,need install")
                        needRunInstall = true
                    }
                }
            } else {
                NSLog("\(v2rayUTool) not exists,need install")
                needRunInstall = true
            }
        }
        print("launchedBefore", needRunInstall)
        if !needRunInstall {
            print("no need install")
            return
        }

        showInstallAlert()

        V2rayLaunch.Stop()

        // generate plist
        V2rayLaunch.generateLaunchAgentPlist()
    }

    static func showInstallAlert() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.alertStyle = .warning
            if isMainland {
                alert.messageText = "安装V2rayUTool"
                alert.informativeText = "V2rayU 需要使用管理员权限安装 V2rayUTool 到 ~/.V2rayU/V2rayUTool"
                alert.addButton(withTitle: "安装")
                alert.addButton(withTitle: "退出")
            } else {
                alert.messageText = " Install V2rayUTool"
                alert.informativeText = "V2rayU needs to install V2rayUTool into ~/.V2rayU/V2rayUTool with administrator privileges"
                alert.addButton(withTitle: "Install")
                alert.addButton(withTitle: "Quit")
            }
            switch alert.runModal() {
            case .alertFirstButtonReturn:
                install()
            default:
                NSApp.terminate(self)
            }
        }
    }

    static func install() {
        let doSh = "cd " + AppResourcesPath + " && sudo chown root:admin ./install.sh && sudo chmod a+rsx  ./install.sh && ./install.sh"
        // Create authorization reference for the user
        executeAppleScriptWithOsascript(script: doSh)
    }

    static func generateLaunchAgentPlist() {
        let launchAgentDirPath = NSHomeDirectory() + "/Library/LaunchAgents/"
        let launchAgentPlistFile = launchAgentDirPath + LAUNCH_AGENT_NAME + ".plist"

        // Ensure launch agent directory is existed.
        let fileMgr = FileManager.default
        if !fileMgr.fileExists(atPath: launchAgentDirPath) {
            try! fileMgr.createDirectory(atPath: launchAgentDirPath, withIntermediateDirectories: true, attributes: nil)
        }

        // write launch agent
        // 兼容 v2ray | xray
        let agentArguments = ["./v2ray-core/v2ray", "run", "-config", "config.json"]

        let dictAgent: NSMutableDictionary = [
            "Label": LAUNCH_AGENT_NAME,
            "WorkingDirectory": AppHomePath,
            "StandardOutPath": logFilePath,
            "StandardErrorPath": logFilePath,
            "ProgramArguments": agentArguments,
            "RunAtLoad": false, // can not set true
            "KeepAlive": false, // can not set true
        ]

        dictAgent.write(toFile: launchAgentPlistFile, atomically: true)
        // unload launch service(避免更改后无法生效)
        do {
            _ = try runCommand(at: "/bin/launchctl", with: ["unload", "-F", launchAgentPlistFile])
        } catch {
        }
        // load launch service
        do {
            let output = try runCommand(at: "/bin/launchctl", with: ["load", "-wF", launchAgentPlistFile])
            NSLog("launchctl load \(launchAgentPlistFile) succeeded. \(output)")
        } catch let error {
            NSLog("launchctl load \(launchAgentPlistFile) failed. \(error)")
        }
    }

    static func runAtStart() {
        // clear not available
        V2rayServer.clearItems()

        // start http server
        startHttpServer()

        // start or show servers
        if UserDefaults.getBool(forKey: .v2rayTurnOn) {
            // start and show servers
            startV2rayCore()
        } else {
            // show off status
            menuController.setStatusOff()
            // show servers
            menuController.showServers()
        }

        // auto update subscribe servers
        if UserDefaults.getBool(forKey: .autoUpdateServers) {
            V2raySubSync.shared.sync()
        }
    }

    static func SwitchProxyMode() {
        print("SwitchProxyMode")
        V2rayLaunch.startV2rayCore()
    }

    static func setRunMode(mode: RunMode) {
        // save
        UserDefaults.set(forKey: .runMode, value: mode.rawValue)

        // set icon
        menuController.setStatusOn(mode: mode)

        setSystemProxy(mode: mode)
    }

    static func ToggleRunning() {
        if UserDefaults.getBool(forKey: .v2rayTurnOn) {
            print("ToggleRunning stop")
            V2rayLaunch.stopV2rayCore()
        } else {
            print("ToggleRunning start")
            V2rayLaunch.startV2rayCore()
        }
    }

    static func restartV2ray() {
        // start
        startV2rayCore()
    }

    // start v2ray core
    static func startV2rayCore() {
        NSLog("start v2ray-core begin")
        guard let v2ray = V2rayServer.loadSelectedItem() else {
            noticeTip(title: "start v2ray fail", informativeText: "v2ray config not found")
            menuController.setStatusOff()
            return
        }

        let runMode = RunMode(rawValue: UserDefaults.get(forKey: .runMode) ?? "global") ?? .global

        // create json file
        createJsonFile(item: v2ray)

        // launch
        let started = V2rayLaunch.Start()
        if !started {
            menuController.setStatusOff()
            return
        }

        // set run mode
        setRunMode(mode: runMode)

        // reload menu
        menuController.showServers()

        // ping current
        PingCurrent.shared.startPing(with: v2ray)
    }

    static func stopV2rayCore() {
        // stop launch
        V2rayLaunch.Stop()
        // off system proxy
        V2rayLaunch.setSystemProxy(mode: .off)
        // set status
        menuController.setStatusOff()
        // reload menu
        menuController.showServers()
    }

    static func Start() -> Bool {
        Stop()

        // close port
        let httpPort = getHttpProxyPort()
        let sockPort = getSocksProxyPort()

        // port has been used
        if isPortOpen(port: httpPort) {
            var toast = "http port \(httpPort) has been used, please replace it from advance setting"
            var title = "Port is already in use"
            if isMainland {
                 toast = "http端口 \(httpPort) 已被使用, 请更换"
                 title = "端口已被占用"
            }
            alertDialog(title: title, message: toast)
            DispatchQueue.main.async {
                preferencesWindowController.show(preferencePane: .advanceTab)
                showDock(state: true)
            }
            return false
        }

        // port has been used
        if isPortOpen(port: sockPort) {
            var toast = "socks port \(sockPort) has been used, please replace it from advance setting"
            var title = "Port is already in use"
            if isMainland {
                toast = "socks端口 \(sockPort) 已被使用, 请更换"
                title = "端口已被占用"
            }
            alertDialog(title: title, message: toast)
            DispatchQueue.main.async {
                preferencesWindowController.show(preferencePane: .advanceTab)
                showDock(state: true)
            }
            return false
        }

        // just start: stop is so slow
        do {
            let output = try runCommand(at: "/bin/launchctl", with: ["start", LAUNCH_AGENT_NAME])
            print("Start v2ray-core: ok \(output)")
            return true
        } catch let error {
            alertDialog(title: "Start v2ray-core failed.", message: error.localizedDescription)
            return false
        }
    }

    static func Stop() {
        do {
            let output = try runCommand(at: "/bin/launchctl", with: ["stop", LAUNCH_AGENT_NAME])
            print("setSystemProxy: ok \(output)")
        } catch let error {
            alertDialog(title: "Stop Error", message: error.localizedDescription)
        }
    }

    static func checkV2rayCore() {
        if !FileManager.default.fileExists(atPath: v2rayCoreFile) {
            print("\(v2rayCoreFile) not exists,need install")
            install()
        }
        if !FileManager.default.isExecutableFile(atPath: v2rayCoreFile) {
            print("\(v2rayCoreFile) not accessable")
            install()
        }
    }

    static func setSystemProxy(mode: RunMode) {
        print("setSystemProxy", v2rayUTool, mode)
        let pacUrl = getPacUrl()
        var httpPort: String = ""
        var sockPort: String = ""
        // reload
        if mode == .global {
            httpPort = UserDefaults.get(forKey: .localHttpPort) ?? "1087"
            sockPort = UserDefaults.get(forKey: .localSockPort) ?? "1080"
        }
        do {
            let output = try runCommand(at: v2rayUTool, with: ["-mode", mode.rawValue, "-pac-url", pacUrl, "-http-port", httpPort, "-sock-port", sockPort])
            print("setSystemProxy: ok \(output)")
        } catch let error {
            alertDialog(title: "setSystemProxy Error", message: error.localizedDescription)
            showInstallAlert()
        }
    }

    // start http server for pac
    static func startHttpServer() {
        do {
            // stop first
            webServer.stop()

            // then new HttpServer
            webServer = HttpServer()
            webServer["/:path"] = shareFilesFromDirectory(AppHomePath)
            webServer["/pac/:path"] = shareFilesFromDirectory(AppHomePath + "/pac")

            // check pacPort is usable
            let pacPort = getPacPort()
            // port has been used
            if isPortOpen(port: pacPort) {
                var toast = "pac port \(pacPort) has been used, please replace from advance setting"
                var title = "Port is already in use"
                if isMainland {
                    toast = "pac端口 \(pacPort) 已被使用, 请更换"
                    title = "端口已被占用"
                }
                alertDialog(title: title, message: toast)
                DispatchQueue.main.async {
                    preferencesWindowController.show(preferencePane: .advanceTab)
                    showDock(state: true)
                }
                return
            }

            try webServer.start(pacPort)
            print("webServer.start at:\(pacPort)")
        } catch let error {
            print("webServer.start error:\(error)")
        }
    }

    // create current v2ray server json file
    static func createJsonFile(item: V2rayItem) {
        var jsonText = item.json

        // parse old
        let vCfg = V2rayConfig()
        vCfg.parseJson(jsonText: item.json)
        vCfg.v2ray.log.access = logFilePath
        vCfg.v2ray.log.error = logFilePath

        // combine new default config
        jsonText = vCfg.combineManual()

        do {
            let jsonFilePath = URL(fileURLWithPath: JsonConfigFilePath)

            // delete before config
            if FileManager.default.fileExists(atPath: JsonConfigFilePath) {
                try? FileManager.default.removeItem(at: jsonFilePath)
            }

            try jsonText.write(to: jsonFilePath, atomically: true, encoding: String.Encoding.utf8)
        } catch let error {
            // failed to write file – bad permissions, bad filename, missing permissions, or more likely it can't be converted to the encoding
            NSLog("save json file fail: \(error)")
        }
    }
}
