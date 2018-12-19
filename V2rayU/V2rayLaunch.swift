//
//  Launch.swift
//  V2rayU
//
//  Created by yanue on 2018/10/17.
//  Copyright © 2018 yanue. All rights reserved.
//

import Foundation
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
let httpServerPort = 18765

enum RunMode: String {
    case global
    case off
    case manual
    case pac
}

class V2rayLaunch: NSObject {
    static var authRef: AuthorizationRef?

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
        let httpArguments = ["/usr/bin/python", "-m", "SimpleHTTPServer", String(httpServerPort)]

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

        // unload first
        _ = shell(launchPath: "/bin/launchctl", arguments: ["unload", launchAgentPlistFile])
        _ = shell(launchPath: "/bin/launchctl", arguments: ["load", "-wF", launchHttpPlistFile])

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

        // if enable system proxy
        let runMode = RunMode(rawValue: UserDefaults.get(forKey: .runMode) ?? "manual") ?? .manual

        if runMode == .global || runMode == .pac {
            // close system proxy
            V2rayLaunch.setSystemProxy(mode: .off)
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

    static func setSystemProxy(mode: RunMode, httpPort: String = "", sockPort: String = "") {

        // setup policy database db
        CommonAuthorization.shared.setupAuthorizationRights(authRef: self.authRef!)

        // copy rights
        let rightName: String = CommonAuthorization.systemProxyAuthRightName
        var authItem = AuthorizationItem(name: (rightName as NSString).utf8String!, valueLength: 0, value: UnsafeMutableRawPointer(bitPattern: 0), flags: 0)
        var authRight: AuthorizationRights = AuthorizationRights(count: 1, items: &authItem)

        let copyRightStatus = AuthorizationCopyRights(self.authRef!, &authRight, nil, [.extendRights, .interactionAllowed, .preAuthorize, .partialRights], nil)

        Swift.print("AuthorizationCopyRights result: \(copyRightStatus), right name: \(rightName)")
        assert(copyRightStatus == errAuthorizationSuccess)

        // set system proxy
        let prefRef = SCPreferencesCreateWithAuthorization(kCFAllocatorDefault, "systemProxySet" as CFString, nil, self.authRef)!
        let sets = SCPreferencesGetValue(prefRef, kSCPrefNetworkServices)!

        var proxies = [NSObject: AnyObject]()

        // global proxy
        if mode == .global {
            // socks
            if sockPort != "" && Int(sockPort) ?? 0 > 1024 {
                proxies[kCFNetworkProxiesSOCKSEnable] = 1 as NSNumber
                proxies[kCFNetworkProxiesSOCKSProxy] = "127.0.0.1" as AnyObject?
                proxies[kCFNetworkProxiesSOCKSPort] = Int(sockPort)! as NSNumber
                proxies[kCFNetworkProxiesExcludeSimpleHostnames] = 1 as NSNumber
            }

            // check http port
            if httpPort != "" && Int(httpPort) ?? 0 > 1024 {
                // http
                proxies[kCFNetworkProxiesHTTPEnable] = 1 as NSNumber
                proxies[kCFNetworkProxiesHTTPProxy] = "127.0.0.1" as AnyObject?
                proxies[kCFNetworkProxiesHTTPPort] = Int(httpPort)! as NSNumber
                proxies[kCFNetworkProxiesExcludeSimpleHostnames] = 1 as NSNumber

                // https
                proxies[kCFNetworkProxiesHTTPSEnable] = 1 as NSNumber
                proxies[kCFNetworkProxiesHTTPSProxy] = "127.0.0.1" as AnyObject?
                proxies[kCFNetworkProxiesHTTPSPort] = Int(httpPort)! as NSNumber
                proxies[kCFNetworkProxiesExcludeSimpleHostnames] = 1 as NSNumber
            }
        }

        if mode == .pac {
            proxies[kCFNetworkProxiesProxyAutoConfigURLString] = PACUrl as AnyObject
            proxies[kCFNetworkProxiesProxyAutoConfigEnable] = 1 as NSNumber
        }

        // restore system proxy setting in off or manual
        if mode == .off || mode == .manual {
            proxies[kCFNetworkProxiesProxyAutoConfigURLString] = "" as AnyObject?
            proxies[kCFNetworkProxiesProxyAutoConfigEnable] = 0 as NSNumber
            // set enable 0
            proxies[kCFNetworkProxiesSOCKSEnable] = 0 as NSNumber
            proxies[kCFNetworkProxiesHTTPEnable] = 0 as NSNumber
            proxies[kCFNetworkProxiesHTTPSEnable] = 0 as NSNumber
        }

        sets.allKeys!.forEach { (key) in
            let dict = sets.object(forKey: key)!
            let hardware = (dict as AnyObject).value(forKeyPath: "Interface.Hardware")

            if hardware != nil && ["AirPort", "Wi-Fi", "Ethernet"].contains(hardware as! String) {
                SCPreferencesPathSetValue(prefRef, "/\(kSCPrefNetworkServices)/\(key)/\(kSCEntNetProxies)" as CFString, proxies as CFDictionary)
            }
        }

        // commit to system preferences.
        let commitRet = SCPreferencesCommitChanges(prefRef)
        let applyRet = SCPreferencesApplyChanges(prefRef)
        SCPreferencesSynchronize(prefRef)

        Swift.print("after SCPreferencesCommitChanges: commitRet = \(commitRet), applyRet = \(applyRet)")
    }
}
