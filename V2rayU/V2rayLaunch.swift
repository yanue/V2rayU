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
            let task = Process.launchedProcess(launchPath: "/bin/launchctl", arguments: ["stop", LAUNCH_AGENT_NAME])
            task.waitUntilExit()

            let task1 = Process.launchedProcess(launchPath: "/bin/launchctl", arguments: ["unload", LAUNCH_AGENT_NAME])
            task1.waitUntilExit()
            
            try? FileManager.default.removeItem(at: URL(fileURLWithPath: launchAgentPlistFile))
        }
    }

    static func Start() {
        // start http server
        startHttpServer()
        
        // permission
        _ = shell(launchPath: "/bin/bash", arguments: ["-c", "cd " + AppHomePath + " && /bin/chmod +x ./v2ray-core/v2ray"])

        // stop before
        self.stopV2ray()

        // reinstance
        // can't use `/bin/bash -c cmd...` otherwize v2ray process will become a ghost process
        v2rayProcess = Process()
        v2rayProcess.launchPath = v2rayCoreFile
        v2rayProcess.arguments = ["-config", JsonConfigFilePath]
        v2rayProcess.terminationHandler = { process in
            if process.terminationStatus != EXIT_SUCCESS {
                NSLog("process is not kill \(process.description) -  \(process.processIdentifier) - \(process.terminationStatus)")
            }
        }
        // async launch and can't waitUntilExit
        v2rayProcess.launch()

    }

    static func Stop() {
        // stop pac server
        webServer.stop()

        self.stopV2ray()
    }
    
    static func stopV2ray() {
        print("stopV2ray", v2rayProcess.isRunning)
        // exit process
        if v2rayProcess.isRunning {
            // terminate v2ray process
            v2rayProcess.terminate()
            v2rayProcess.waitUntilExit()
        }
        
        // close port
        let httpPort = UInt16(UserDefaults.get(forKey: .localHttpPort) ?? "1080") ?? 1080
        let sockPort = UInt16( UserDefaults.get(forKey: .localSockPort) ?? "1087") ?? 1087
        
        closePort(port: httpPort)
        closePort(port: sockPort)
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
            let pacPort = UInt16(UserDefaults.get(forKey: .localPacPort) ?? "11085") ?? 11085
            closePort(port: pacPort)
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
