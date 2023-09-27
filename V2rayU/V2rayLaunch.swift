//
//  Launch.swift
//  V2rayU
//
//  Created by yanue on 2018/10/17.
//  Copyright © 2018 yanue. All rights reserved.
//

import Cocoa
import SystemConfiguration
import Swifter

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
// Create a Process instance with async launch
var v2rayProcess = Process()

class V2rayLaunch: NSObject {
    
    static func install() {
        // rempve plist of old version ( < 4.0 )
         V2rayLaunch.removeLaunchAgentPlist()

        // Ensure launch agent directory is existed.
        let fileMgr = FileManager.default
        if !fileMgr.fileExists(atPath: AppHomePath) {
            print("app home dir \(AppHomePath) not exists,need install")
            try! fileMgr.createDirectory(atPath: AppHomePath, withIntermediateDirectories: true, attributes: nil)
        }

        // make sure new version
        print("install", AppResourcesPath)
        var needRunInstall = false
        if !FileManager.default.fileExists(atPath: v2rayCoreFile) {
            print("\(v2rayCoreFile) not exists,need install")
            needRunInstall = true
        }
        if !FileManager.default.fileExists(atPath: v2rayCorePath+"/geoip.dat") {
            print("\(v2rayCorePath)/geoip.dat not exists,need install")
            needRunInstall = true
        }
        if !FileManager.default.fileExists(atPath: v2rayUTool) {
            print("\(v2rayUTool) not exists,need install")
            needRunInstall = true
        }
        if !FileManager.default.fileExists(atPath: PACAbpFile) {
            print("\(PACAbpFile) not exists,need install")
            needRunInstall = true
        }
        if !FileManager.default.fileExists(atPath: GFWListFilePath) {
            print("\(GFWListFilePath) not exists,need install")
            needRunInstall = true
        }
        if !FileManager.default.fileExists(atPath: PACUserRuleFilePath) {
            print("\(PACUserRuleFilePath) not exists,need install")
            needRunInstall = true
        }
        print("launchedBefore", needRunInstall)
        if !needRunInstall {
            print("no need install")
            return
        }
        
        let doSh = "cd " + AppResourcesPath + " && sudo chown root:admin ./install.sh && sudo chmod a+rsx  ./install.sh && ./install.sh"
        print("runAppleScript:" + doSh)
        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: "do shell script \"" + doSh + "\" with administrator privileges") {
            let output: NSAppleEventDescriptor = scriptObject.executeAndReturnError(&error)
            print(output.stringValue ?? "")
            if (error != nil) {
                print("error: \(String(describing: error))")
            }
        }
    }
    
    static func removeLaunchAgentPlist() {
        let LAUNCH_AGENT_NAME = "yanue.v2rayu.v2ray-core"
        let launchAgentDirPath = NSHomeDirectory() + "/Library/LaunchAgents/"
        let launchAgentPlistFile = launchAgentDirPath + LAUNCH_AGENT_NAME + ".plist"
        // old version ( < 4.0 )
        if FileManager.default.fileExists(atPath: launchAgentPlistFile) {
            Process.launchedProcess(launchPath: "/bin/launchctl", arguments: ["stop", LAUNCH_AGENT_NAME]).waitUntilExit()
            Process.launchedProcess(launchPath: "/bin/launchctl", arguments: ["remove", LAUNCH_AGENT_NAME]).waitUntilExit()
            Process.launchedProcess(launchPath: "/bin/launchctl", arguments: ["unload", LAUNCH_AGENT_NAME]).waitUntilExit()
            
            try? FileManager.default.removeItem(at: URL(fileURLWithPath: launchAgentPlistFile))
        }
    }

    static func runAtStart(){
        // install before launch
        V2rayLaunch.install()

        // kill v2ray
        killSelfV2ray()

        // start http server
        startHttpServer()

        // start or show servers
        if UserDefaults.getBool(forKey: .v2rayTurnOn) {
            // start and show servers
            self.startV2rayCore()
        } else {
            // show off status
            menuController.setStatusOff()
            // show servers
            menuController.showServers()
        }

        // auto update subscribe servers
        if UserDefaults.getBool(forKey: .autoUpdateServers) {
            v2raySubSync.sync()
        }
    }

    static func SwitchProxyMode() {
        let runMode = RunMode(rawValue: UserDefaults.get(forKey: .runMode) ?? "global") ?? .global

        switch runMode {
        case .pac:
            self.SwitchRunMode(mode: .global)
            break
        case .global:
            self.SwitchRunMode(mode: .manual)
            break
        case .manual:
            self.SwitchRunMode(mode: .pac)
            break

        default: break
        }
    }

    static func SwitchRunMode(mode: RunMode) {
        // save
        UserDefaults.set(forKey: .runMode, value: runMode.rawValue)

        // launch
        let started = V2rayLaunch.Start()
        if !started {
            menuController.setStatusOff()
            return
        }

        // set icon
        menuController.setStatusOn(mode: mode)

        self.setSystemProxy(mode: mode)
    }

    static func ToggleRunning() {
        if UserDefaults.getBool(forKey: .v2rayTurnOn) {
            V2rayLaunch.stopV2rayCore()
        } else {
            V2rayLaunch.startV2rayCore()
        }
    }

    static func restartV2ray(){
        // stop first
        V2rayLaunch.Stop()
        // start
        self.startV2rayCore()
    }

    // start v2ray core
    static func startV2rayCore() {
        NSLog("start v2ray-core begin")
        guard let v2ray = V2rayServer.loadSelectedItem() else {
            noticeTip(title: "start v2ray fail", subtitle: "", informativeText: "v2ray config not found")
            menuController.setStatusOff()
            return
        }

        if !v2ray.isValid {
            noticeTip(title: "start v2ray fail", subtitle: "", informativeText: "invalid v2ray config")
            menuController.setStatusOff()
            return
        }

        let runMode = RunMode(rawValue: UserDefaults.get(forKey: .runMode) ?? "global") ?? .global

        // create json file
        self.createJsonFile(item: v2ray)

        // switch run mode
        self.SwitchRunMode(mode: runMode)

        // reload menu
        menuController.showServers()
    }

    static func stopV2rayCore() {
        // set status
        menuController.setStatusOff()
        // stop launch
        V2rayLaunch.Stop()
        // off system proxy
        V2rayLaunch.setSystemProxy(mode: .off)
        // reload menu
        menuController.showServers()
    }

    static func Start() -> Bool {
        // permission
        _ = shell(launchPath: "/bin/bash", arguments: ["-c", "cd " + AppHomePath + " && /bin/chmod +x ./v2ray-core/v2ray"])

        // stop before
        self.stopV2ray()

        // restart http server
        startHttpServer()

        // close port
        let httpPort = getHttpProxyPort()
        let sockPort = getSocksProxyPort()
    
        // port has been used
        if isPortOpen(port: httpPort) {
            var toast = "http端口 \(httpPort) 已被使用, 请更换"
            var title = "端口已被占用"
            if Locale.current.languageCode == "en" {
                toast = "http port \(httpPort) has been used, please replace it from advance setting"
                title = "Port is already in use"
            }
            alertDialog(message: toast, title: title)
            self.stopV2rayCore()
            preferencesWindowController.show(preferencePane: .advanceTab)
            return false
        }
        
        // port has been used
        if isPortOpen(port: sockPort) {
            var toast = "socks端口 \(sockPort) 已被使用, 请更换"
            var title = "端口已被占用"
            if Locale.current.languageCode == "en" {
                toast = "socks port \(sockPort) has been used, please replace it from advance setting"
                title = "Port is already in use"
            }
            alertDialog(message: toast, title: title)
            self.stopV2rayCore()
            preferencesWindowController.show(preferencePane: .advanceTab)
            return false
        }

        // reinstance
        // can't use `/bin/bash -c cmd...` otherwise v2ray process will become a ghost process
        v2rayProcess = Process()
        v2rayProcess.launchPath = v2rayCoreFile
        v2rayProcess.arguments = ["-config", JsonConfigFilePath]
//        v2rayProcess.standardError = nil
//        v2rayProcess.standardOutput = nil
        v2rayProcess.terminationHandler = { process in
            if process.terminationStatus == EXIT_SUCCESS {
                NSLog("process been killed: \(process.description) -  \(process.processIdentifier) - \(process.terminationStatus)")
                // reconnect
                if UserDefaults.getBool(forKey: .v2rayTurnOn) && !inPingCurrent {
                    DispatchQueue.main.async {
                        NSLog("V2rayLaunch process been killed, restart now")
                        V2rayLaunch.Stop()
                        _ = V2rayLaunch.Start()
                    }
                }
            }
        }
        // async launch and can't waitUntilExit
        v2rayProcess.launch()
        
        // ping and select server
        if let v2ray = V2rayServer.loadSelectedItem() {
            // ping and refresh
            DispatchQueue.global(qos: .background).async {
                PingCurrent(item: v2ray).doPing()
            }
        }
        
        return true
    }

    static func Stop() {
        self.stopV2ray()
    }
    
    static func stopV2ray() {
        print("stopV2ray", v2rayProcess.isRunning)
        // exit process
        if v2rayProcess.isRunning {
            // terminate v2ray process
            v2rayProcess.interrupt()
            v2rayProcess.terminate()
            v2rayProcess.waitUntilExit()
            usleep(useconds_t(1 * second))
        }
        // kill self v2ray
        killSelfV2ray()
    }

    static func setSystemProxy(mode: RunMode) {
        // Ensure launch agent directory is existed.
        if !FileManager.default.isExecutableFile(atPath: v2rayUTool) {
            self.install()
        }
        
        // Ensure permission with root admin
        if checkFileIsRootAdmin(file: v2rayUTool) {
            self.install()
        }
        
        print("v2rayUTool", v2rayUTool)
        let pacUrl = getPacUrl()
        var httpPort: String = ""
        var sockPort: String = ""
        // reload
        if mode == .global {
            httpPort = UserDefaults.get(forKey: .localHttpPort) ?? "1080"
            sockPort = UserDefaults.get(forKey: .localSockPort) ?? "1087"
        }

        let task = Process.launchedProcess(launchPath: v2rayUTool, arguments: ["-mode", mode.rawValue, "-pac-url", pacUrl, "-http-port", httpPort, "-sock-port", sockPort])
        task.waitUntilExit()
        if task.terminationStatus == 0 {
            NSLog("setSystemProxy " + mode.rawValue + " succeeded.")
        } else {
            NSLog("setSystemProxy " + mode.rawValue + " failed.")
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
                var toast = "pac端口 \(pacPort) 已被使用, 请更换"
                var title = "端口已被占用"
                if Locale.current.languageCode == "en" {
                    toast = "pac port \(pacPort) has been used, please replace from advance setting"
                    title = "Port is already in use"
                }
                alertDialog(message: toast, title: title)
                preferencesWindowController.show(preferencePane: .advanceTab)
                return
            }
            
            try webServer.start(pacPort)
            print("webServer.start at:\(pacPort)")
        } catch let error {
            print("webServer.start error:\(error)")
        }
    }

    static func checkPorts() -> Bool {
        return true
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
        V2rayServer.save(v2ray: item, jsonData: jsonText)

        // path: /Application/V2rayU.app/Contents/Resources/config.json
        guard let jsonFile = V2rayServer.getJsonFile() else {
            NSLog("unable get config file path")
            return
        }

        do {

            let jsonFilePath = URL.init(fileURLWithPath: jsonFile)

            // delete before config
            if FileManager.default.fileExists(atPath: jsonFile) {
                try? FileManager.default.removeItem(at: jsonFilePath)
            }

            try jsonText.write(to: jsonFilePath, atomically: true, encoding: String.Encoding.utf8)
        } catch let error {
            // failed to write file – bad permissions, bad filename, missing permissions, or more likely it can't be converted to the encoding
            NSLog("save json file fail: \(error)")
        }
    }
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
            guard let JSON = result as NSDictionary else {
                NSLog("error: no tag_name")
                return
            }

            // get tag_name (version)
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
            // get old version
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
