//
//  Launch.swift
//  V2rayU
//
//  Created by yanue on 2018/10/17.
//  Copyright © 2018 yanue. All rights reserved.
//

import Cocoa
import SystemConfiguration

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
        if !needRunInstall && !FileManager.default.isExecutableFile(atPath: v2rayCoreFile) {
            NSLog("\(v2rayCoreFile) not accessable")
            needRunInstall = true
        }
        // Ensure permission with root admin
        if !needRunInstall && !checkFileIsRootAdmin(file: v2rayUTool) {
            needRunInstall = true
        }
        if !needRunInstall && !FileManager.default.fileExists(atPath: v2rayCorePath + "/geoip.dat") {
            NSLog("\(v2rayCorePath)/geoip.dat not exists,need install")
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
            "RunAtLoad": false, // 不能开机自启(需要停止)
            "KeepAlive": false, // 不能自动重启(需要停止)
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

        // start or show servers
        if UserDefaults.getBool(forKey: .v2rayTurnOn) {
            // start and show servers
            startV2rayCore()
        } else {
            // show off status
            Task {
                await AppState.shared.setRunMode(mode: .off)
            }
//            menuController.showServers()
        }
//        runTun2Socks()
        
        
        // auto update subscribe servers
        if UserDefaults.getBool(forKey: .autoUpdateServers) {
            Task {
                await SubscriptionHandler.shared.sync()
            }
        }
    }

    static func SwitchProxyMode() {
        print("SwitchProxyMode")
        V2rayLaunch.startV2rayCore()
    }

    static func setRunMode(mode: RunMode) {
        setSystemProxy(mode: mode)
        Task {
            await AppState.shared.setRunMode(mode: mode)
        }
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
        Task{
            NSLog("start v2ray-core begin")
            guard let v2ray = ProfileViewModel.getRunning() else {
                noticeTip(title: "start v2ray fail", informativeText: "v2ray config not found")
                await AppState.shared.setRunMode(mode: .off)
                return
            }
            // create json file
            createJsonFile(item: v2ray)
            // launch
            let started = V2rayLaunch.Start()
            if !started {
                NSLog("start v2ray-core failed")
                await AppState.shared.setRunMode(mode: .off)
                return
            }
            // set run mode
            var runMode = await AppState.shared.runMode
            if runMode == .off {
                runMode = .global
            }
            setRunMode(mode: runMode)
            // ping current
//            try await PingRunning.shared.startPing(item: v2ray)
        }
    }

    static func stopV2rayCore() {
        // stop launch
        V2rayLaunch.Stop()
        // off system proxy
        V2rayLaunch.setSystemProxy(mode: .off)
        // set status
        Task {
            await AppState.shared.setRunMode(mode: .off)
        }
    }
    
    static func createJsonFile(item: ProfileModel) {
        let vCfg = V2rayConfigHandler()
        let jsonText = vCfg.toJSON(item: item)
        do {
            NSLog("createJsonFile: \(JsonConfigFilePath)")
            try jsonText.write(to: URL(fileURLWithPath: JsonConfigFilePath), atomically: true, encoding: .utf8)
        } catch {
            NSLog("Failed to write JSON file: \(error)")
            noticeTip(title: "Failed to write JSON file: \(error)")
        }
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
//                preferencesWindowController.show(preferencePane: .advanceTab)
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
//                preferencesWindowController.show(preferencePane: .advanceTab)
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
        var httpPort: String = ""
        var sockPort: String = ""
        // reload
        if mode == .global {
            httpPort = UserDefaults.get(forKey: .localHttpPort,defaultValue: "1087")
            sockPort = UserDefaults.get(forKey: .localSockPort,defaultValue: "1080")
        }
        do {
            let output = try runCommand(at: v2rayUTool, with: ["-mode", mode.rawValue, "-pac-url", "", "-http-port", httpPort, "-sock-port", sockPort])
            print("setSystemProxy: ok \(output)")
        } catch let error {
            alertDialog(title: "setSystemProxy Error", message: error.localizedDescription)
            showInstallAlert()
        }
    }

}
