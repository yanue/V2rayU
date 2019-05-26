//
//  Launch.swift
//  V2rayU
//
//  Created by yanue on 2018/10/17.
//  Copyright © 2018 yanue. All rights reserved.
//

import Cocoa
import SystemConfiguration
import Alamofire

let LAUNCH_AGENT_DIR = "/Library/LaunchAgents/"
let LAUNCH_AGENT_PLIST = "yanue.v2rayu.v2ray-core.plist"
let LAUNCH_HTTP_PLIST = "yanue.v2rayu.http.plist" // simple http server
let logFilePath = NSHomeDirectory() + "/Library/Logs/V2rayU.log"
let launchAgentDirPath = NSHomeDirectory() + LAUNCH_AGENT_DIR
let launchAgentPlistFile = launchAgentDirPath + LAUNCH_AGENT_PLIST
let launchHttpPlistFile = launchAgentDirPath + LAUNCH_HTTP_PLIST
let AppResourcesPath = Bundle.main.bundlePath + "/Contents/Resources"
let v2rayCorePath = AppResourcesPath + "/v2ray-core"
let v2rayCoreFile = v2rayCorePath + "/v2ray"
var HttpServerPacPort = UserDefaults.get(forKey: .localPacPort) ?? "1085"

let cmdSh = AppResourcesPath + "/cmd.sh"
let cmdAppleScript = "do shell script \"" + cmdSh + "\" with administrator privileges"

enum RunMode: String {
    case global
    case off
    case manual
    case pac
    case backup
    case restore
}

class V2rayLaunch: NSObject {
    static func generateLaunchAgentPlist() {
        // Ensure launch agent directory is existed.
        let fileMgr = FileManager.default
        if !fileMgr.fileExists(atPath: launchAgentDirPath) {
            try! fileMgr.createDirectory(atPath: launchAgentDirPath, withIntermediateDirectories: true, attributes: nil)
        }

        // write launch agent
        let agentArguments = ["./v2ray-core/v2ray", "-config", "config.json"]

        let dictAgent: NSMutableDictionary = [
            "Label": LAUNCH_AGENT_PLIST.replacingOccurrences(of: ".plist", with: ""),
            "WorkingDirectory": AppResourcesPath,
            "StandardOutPath": logFilePath,
            "StandardErrorPath": logFilePath,
            "ProgramArguments": agentArguments,
            "KeepAlive": true,
            "RunAtLoad": true,
        ]

        dictAgent.write(toFile: launchAgentPlistFile, atomically: true)

        // write http simple server plist
        let httpArguments = ["/usr/bin/python", "-m", "SimpleHTTPServer", HttpServerPacPort]

        let dictHttp: NSMutableDictionary = [
            "Label": LAUNCH_HTTP_PLIST.replacingOccurrences(of: ".plist", with: ""),
            "WorkingDirectory": AppResourcesPath,
            "StandardOutPath": logFilePath,
            "StandardErrorPath": logFilePath,
            "ProgramArguments": httpArguments,
            "KeepAlive": true,
            "RunAtLoad": true,
        ]

        dictHttp.write(toFile: launchHttpPlistFile, atomically: true)

        // permission
        _ = shell(launchPath: "/bin/bash", arguments: ["-c", "cd " + AppResourcesPath + " && /bin/chmod -R 755 ."])
    }

    static func Start() {
        // permission: make v2ray execable
        // ~/LaunchAgents/yanue.v2rayu.v2ray-core.plist
        _ = shell(launchPath: "/bin/bash", arguments: ["-c", "cd " + AppResourcesPath + " && /bin/chmod -R 755 ./v2ray-core"])

        // reload
        _ = shell(launchPath: "/bin/launchctl", arguments: ["unload", launchHttpPlistFile])
        _ = shell(launchPath: "/bin/launchctl", arguments: ["load", "-wF", launchHttpPlistFile])

        // unload first
        _ = shell(launchPath: "/bin/launchctl", arguments: ["unload", launchAgentPlistFile])

        let task = Process.launchedProcess(launchPath: "/bin/launchctl", arguments: ["load", "-wF", launchAgentPlistFile])
        task.waitUntilExit()
        if task.terminationStatus == 0 {
            NSLog("Start v2ray-core succeeded.")
        } else {
            NSLog("Start v2ray-core failed.")
        }
    }

    static func Stop() {
        _ = shell(launchPath: "/bin/launchctl", arguments: ["unload", launchHttpPlistFile])

        // cmd: /bin/launchctl unload /Library/LaunchAgents/yanue.v2rayu.v2ray-core.plist
        let task = Process.launchedProcess(launchPath: "/bin/launchctl", arguments: ["unload", launchAgentPlistFile])
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

    static func ClearLogs(){
        let txt = ""
        try! txt.write(to: URL.init(fileURLWithPath: logFilePath), atomically: true, encoding: String.Encoding.utf8)
    }
    
    static func chmodCmdPermission() {
        // Ensure launch agent directory is existed.
        if !FileManager.default.fileExists(atPath: cmdSh) {
            return
        }

        let res = shell(launchPath: "/bin/bash", arguments: ["-c", "cd " + AppResourcesPath + " && ls -la ./V2rayUTool | awk '{print $3,$4}'"])
        NSLog("Permission is " + (res ?? ""))
        if res == "root admin" {
            NSLog("Permission is ok")
            return
        }

        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: cmdAppleScript) {
            let output: NSAppleEventDescriptor = scriptObject.executeAndReturnError(&error)
            print(output.stringValue ?? "")
            if (error != nil) {
                print("error: \(String(describing: error))")
            }
        } else {
            print("error scriptObject")
        }
    }

    static func setSystemProxy(mode: RunMode, httpPort: String = "", sockPort: String = "") {
        let task = Process.launchedProcess(launchPath: AppResourcesPath + "/V2rayUTool", arguments: ["-mode", mode.rawValue, "-pac-url", PACUrl, "-http-port", httpPort, "-sock-port", sockPort])
        task.waitUntilExit()
        if task.terminationStatus == 0 {
            NSLog("setSystemProxy " + mode.rawValue + " succeeded.")
        } else {
            NSLog("setSystemProxy " + mode.rawValue + " failed.")
        }
    }
}
