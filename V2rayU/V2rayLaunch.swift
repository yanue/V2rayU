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
import Swifter

let LAUNCH_AGENT_NAME = "yanue.v2rayu.v2ray-core"
let AppResourcesPath = Bundle.main.bundlePath + "/Contents/Resources"
let AppHomePath = NSHomeDirectory() + "/.V2rayU"
let v2rayCorePath = AppHomePath + "/v2ray-core"
let v2rayCoreFile = v2rayCorePath + "/v2ray"
let logFilePath = AppHomePath + "/v2ray-core.log"
var HttpServerPacPort = UserDefaults.get(forKey: .localPacPort) ?? "11085"
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
            try! fileMgr.createDirectory(atPath: AppHomePath, withIntermediateDirectories: true, attributes: nil)
        }

        // make sure new version
        print("install", AppResourcesPath)
        var needRunInstall = false
        if !FileManager.default.fileExists(atPath: v2rayCoreFile) {
            print("app home dir not exists,need install")
            needRunInstall = true
        }

        let launchKey = "launchedBefore-" + appVersion
        let launchedBefore = UserDefaults.standard.bool(forKey: launchKey)
        if !launchedBefore {
            print("First launch, need install.")
            UserDefaults.standard.set(true, forKey: launchKey)
            needRunInstall = true
        }

        print("launchedBefore", launchedBefore, needRunInstall)
        if !needRunInstall {
            print("not install")
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
            "KeepAlive": false,
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

    static func setSystemProxy(mode: RunMode, httpPort: String = "", sockPort: String = "") {
        // Ensure launch agent directory is existed.
        let fileMgr = FileManager.default
        if !fileMgr.isExecutableFile(atPath: AppHomePath + "/V2rayUTool") {
            self.install()
        }

        let task = Process.launchedProcess(launchPath: AppHomePath + "/V2rayUTool", arguments: ["-mode", mode.rawValue, "-pac-url", PACUrl, "-http-port", httpPort, "-sock-port", sockPort])
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

            let pacPort = UInt16(UserDefaults.get(forKey: .localPacPort) ?? "11085") ?? 11085
            try webServer.start(pacPort)
            print("webServer.start at:\(pacPort)")
        } catch let error {
            print("webServer.start error:\(error)")
        }
    }

    static func checkPorts() -> Bool {
        return true
        // stop old v2ray process
        self.Stop()
        // stop pac server
        webServer.stop()

        let localSockPort = UserDefaults.get(forKey: .localSockPort) ?? "1080"
        let localSockHost = UserDefaults.get(forKey: .localSockHost) ?? "127.0.0.1"
        let localHttpPort = UserDefaults.get(forKey: .localHttpPort) ?? "1087"
        let localHttpHost = UserDefaults.get(forKey: .localHttpHost) ?? "127.0.0.1"
        let localPacPort = UserDefaults.get(forKey: .localPacPort) ?? "11085"

        // check same port
        if localSockPort == localHttpPort {
            makeToast(message: "the ports (sock,http) cannot be the same: " + localHttpPort)
            return false
        }

        if localHttpPort == localPacPort {
            makeToast(message: "the ports (http,pac) cannot be the same:" + localPacPort)
            return false
        }

        if localSockPort == localPacPort {
            makeToast(message: "the ports (sock,pac) cannot be the same:" + localPacPort)
            return false
        }

        // check port is used
        if !self.checkPort(host: localSockHost, port: localSockPort, tip: "socks") {
            return false
        }

        if !self.checkPort(host: localHttpHost, port: localHttpPort, tip: "http") {
            return false
        }

        if !self.checkPort(host: "0.0.0.0", port: localPacPort, tip: "pac") {
            return false
        }

        return true
    }

    static func checkPort(host: String, port: String, tip: String) -> Bool {
        // shell("/bin/bash",["-c","cd ~ && ls -la"])
        let cmd = "cd " + AppHomePath + " && chmod +x ./V2rayUHelper && ./V2rayUHelper -cmd port -h " + host + " -p " + port
        let res = shell(launchPath: "/bin/bash", arguments: ["-c", cmd])

        NSLog("checkPort: res=(\(String(describing: res))) cmd=(\(cmd))")

        if res != "ok" {
            makeToast(message: tip + " error - " + (res ?? ""), displayDuration: 5)
            return false
        }
        return true
    }
}
