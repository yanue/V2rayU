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
import Alamofire

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
// Create a Process instance with async launch
var v2rayProcess = Process()

class V2rayLaunch: NSObject {
    
    static func install() {
        V2rayLaunch.Stop()

        // generate plist
        V2rayLaunch.generateLaunchAgentPlist()
        
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
        if !FileManager.default.isExecutableFile(atPath: v2rayCoreFile) {
            NSLog("\(v2rayCoreFile) not accessable")
            needRunInstall = true
        }
        if !FileManager.default.fileExists(atPath: v2rayCorePath+"/geoip.dat") {
            NSLog("\(v2rayCorePath)/geoip.dat not exists,need install")
            needRunInstall = true
        }
        if !FileManager.default.fileExists(atPath: v2rayUTool) {
            NSLog("\(v2rayUTool) not exists,need install")
            needRunInstall = true
        }
        if !FileManager.default.fileExists(atPath: PACAbpFile) {
            NSLog("\(PACAbpFile) not exists,need install")
            needRunInstall = true
        }
        if !FileManager.default.fileExists(atPath: GFWListFilePath) {
            NSLog("\(GFWListFilePath) not exists,need install")
            needRunInstall = true
        }
        if !FileManager.default.fileExists(atPath: PACUserRuleFilePath) {
            NSLog("\(PACUserRuleFilePath) not exists,need install")
            needRunInstall = true
        }

        // use /bin/bash to fix crash when V2rayUTool is not exist
        let toolVersion = shell(launchPath: "/bin/bash", arguments: ["-c", "\(v2rayUTool) version"])
        NSLog("toolVersion - \(v2rayUTool): \(String(describing: toolVersion))")
        if toolVersion != nil {
            let _version = toolVersion ?? ""            // old version
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
    
    static func generateLaunchAgentPlist() {
        let launchAgentDirPath = NSHomeDirectory() + "/Library/LaunchAgents/"
        let launchAgentPlistFile = launchAgentDirPath + LAUNCH_AGENT_NAME + ".plist"

        // Ensure launch agent directory is existed.
        let fileMgr = FileManager.default
        if !fileMgr.fileExists(atPath: launchAgentDirPath) {
            try! fileMgr.createDirectory(atPath: launchAgentDirPath, withIntermediateDirectories: true, attributes: nil)
        }

        // write launch agent
        let agentArguments = ["./v2ray-core/v2ray", "-config", "config.json"]

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
        // load launch service
//        Process.launchedProcess(launchPath: "/bin/launchctl", arguments: ["unload", "-F", launchAgentPlistFile]).waitUntilExit()
        let task = Process.launchedProcess(launchPath: "/bin/launchctl", arguments: ["load", "-wF", launchAgentPlistFile])
        task.waitUntilExit()
        if task.terminationStatus == 0 {
            NSLog("launchctl load \(launchAgentPlistFile) succeeded.")
        } else {
            NSLog("launchctl load \(launchAgentPlistFile) failed.")
        }
    }
    
    static func runAtStart(){
        // clear not available
        V2rayServer.clearItems()
        
        // install before launch
        V2rayLaunch.install()

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

        self.setSystemProxy(mode: mode)
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

    static func restartV2ray(){
        // start
        self.startV2rayCore()
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
        self.createJsonFile(item: v2ray)

        // launch
        let started = V2rayLaunch.Start()
        if !started {
            menuController.setStatusOff()
            return
        }
        
        // set run mode
        self.setRunMode(mode: runMode)

        // reload menu
        menuController.showServers()
        
        // ping current
        PingCurrent(item: v2ray).doPing()
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
        self.Stop()
        
        // start http server
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
            _ = alertDialog(title: title, message: toast)
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
            _ = alertDialog(title: title, message: toast)
            self.stopV2rayCore()
            preferencesWindowController.show(preferencePane: .advanceTab)
            return false
        }
        
        // just start: stop is so slow
        let task = Process.launchedProcess(launchPath: "/bin/launchctl", arguments: ["start", LAUNCH_AGENT_NAME])
        task.waitUntilExit()
        if task.terminationStatus == 0 {
            NSLog("Start v2ray-core succeeded.")
            return true
        } else {
            NSLog("Start v2ray-core failed.")
            makeToast(message: "Start v2ray-core failed.")
            return false
        }
    }

    static func Stop() {
        let task = Process.launchedProcess(launchPath: "/bin/launchctl", arguments: ["stop", LAUNCH_AGENT_NAME])
        task.waitUntilExit()
        if task.terminationStatus == 0 {
            NSLog("Stop v2ray-core succeeded.")
        } else {
            NSLog("Stop v2ray-core failed.")
        }
    }
    
    static func checkV2rayUTool() {
        // Ensure launch agent directory is existed.
        if !FileManager.default.isExecutableFile(atPath: v2rayUTool) {
            self.install()
        }
        
        // Ensure permission with root admin
        if !checkFileIsRootAdmin(file: v2rayUTool) {
            self.install()
        }
    }
    
    static func checkV2rayCore() {
        if !FileManager.default.fileExists(atPath: v2rayCoreFile) {
            print("\(v2rayCoreFile) not exists,need install")
            self.install()
        }
        if !FileManager.default.isExecutableFile(atPath: v2rayCoreFile) {
            print("\(v2rayCoreFile) not accessable")
            self.install()
        }
    }
    
    static func setSystemProxy(mode: RunMode) {
        self.checkV2rayUTool()
        
        print("v2rayUTool", v2rayUTool,mode)
        let pacUrl = getPacUrl()
        var httpPort: String = ""
        var sockPort: String = ""
        // reload
        if mode == .global {
            httpPort = UserDefaults.get(forKey: .localHttpPort) ?? "1087"
            sockPort = UserDefaults.get(forKey: .localSockPort) ?? "1080"
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
                _ = alertDialog(title: title, message: toast)
                preferencesWindowController.show(preferencePane: .advanceTab)
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
    Alamofire.request("https://api.github.com/repos/yanue/V2rayU/releases/latest").responseJSON { response in
        //to get status code
        if let status = response.response?.statusCode {
            if status != 200 {
                NSLog("error with response status: ", status)
                return
            }
        }

        //to get JSON return value
        if let result = response.result.value {
            guard let JSON = result as? NSDictionary else {
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
                menuController.newVersionItem.isHidden = false
                menuController.newVersionItem.title = "has new version " + newVer
            } else {
                menuController.newVersionItem.isHidden = true
            }
        }
    }
}
