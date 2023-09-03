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

class V2rayLaunch: NSObject {
    static func install() {
        // generate plist
        V2rayLaunch.generateLaunchAgentPlist()

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
            "KeepAlive": false, // 不能开启,否则重启会自动启动
        ]

        dictAgent.write(toFile: launchAgentPlistFile, atomically: true)
        // load launch service
        Process.launchedProcess(launchPath: "/bin/launchctl", arguments: ["load", "-wF", launchAgentPlistFile])
    }

    static func Start() {
        // start http server
        startHttpServer()

        // just start: stop is so slow
        let task = Process.launchedProcess(launchPath: "/bin/launchctl", arguments: ["start", LAUNCH_AGENT_NAME])
        task.waitUntilExit()
        if task.terminationStatus == 0 {
            NSLog("Start v2ray-core succeeded.")
        } else {
            NSLog("Start v2ray-core failed.")
        }
    }

    static func Stop() {
        // stop pac server
        webServer.stop()

        let task = Process.launchedProcess(launchPath: "/bin/launchctl", arguments: ["stop", LAUNCH_AGENT_NAME])
        task.waitUntilExit()
        if task.terminationStatus == 0 {
            NSLog("Stop v2ray-core succeeded.")
        } else {
            NSLog("Stop v2ray-core failed.")
        }
    }

    static func OpenLogs() {
        if !FileManager.default.fileExists(atPath: logFilePath) {
            let txt = ""
            try! txt.write(to: URL.init(fileURLWithPath: logFilePath), atomically: true, encoding: String.Encoding.utf8)
        }

        let task = Process.launchedProcess(launchPath: "/usr/bin/open", arguments: [logFilePath])
        task.waitUntilExit()
        if task.terminationStatus == 0 {
            NSLog("open logs succeeded.")
        } else {
            NSLog("open logs failed.")
        }
    }

    static func ClearLogs() {
        let txt = ""
        try! txt.write(to: URL.init(fileURLWithPath: logFilePath), atomically: true, encoding: String.Encoding.utf8)
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
            var pacPort = UInt16(UserDefaults.get(forKey: .localPacPort) ?? "11085") ?? 11085
            let (isNew, usablePacPort) = getUsablePort(port: pacPort)
            if isNew {
                // port has been used
                print("changePort - usablePacPort: nowPort=\(usablePacPort),oldPort=\(pacPort)")
                // update UserDefault
                UserDefaults.set(forKey: .localPacPort, value: String(usablePacPort))
                // change pacPort
                pacPort = usablePacPort
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
        // check socksPort is usable
        let socksPort = UInt16(vCfg.socksPort) ?? 1080
        let (isNew, usableSocksPort) = getUsablePort(port: socksPort)
        if isNew {
            // port has been used
            print("changePort - usableSocksPort: nowPort=\(usableSocksPort),oldPort=\(socksPort)")
            // replace
            vCfg.socksPort = String(usableSocksPort)
            // update UserDefault
            UserDefaults.set(forKey: .localSockPort, value: String(usableSocksPort))
        }
        let httpPort = UInt16(vCfg.httpPort) ?? 1087
        let (isNewHttp, usableHttpPort) = getUsablePort(port: httpPort)
        if isNewHttp {
            // port has been used
            print("changePort - useableHttpPort: nowPort=\(usableHttpPort),oldPort=\(httpPort)")
            // replace
            vCfg.httpPort = String(usableHttpPort)
            // update UserDefault
            UserDefaults.set(forKey: .localHttpPort, value: String(usableHttpPort))
        }
        
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
