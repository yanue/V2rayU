//
//  main.swift
//  V2rayUTool
//
//  Created by yanue on 2018/12/19.
//  Copyright © 2018 yanue. All rights reserved.
//

import Cocoa
import SystemConfiguration

var authRef: AuthorizationRef?
let SysProxyBackupPlist = NSHomeDirectory() + "/Library/Preferences/net.yanue.V2rayU.system_proxy_backup.plist"

class V2rayUTool: NSObject {
    static let usage = "Usage: V2rayUTool -mode <global|manual|pac|off|restore|backup> -pac <url> -http-port <port> -sock-port <port>"

    enum RunMode: String {
        case global
        case manual
        case pac
        case off
        case backup
        case restore
    }

    static func run() {
        let arguments = CommandLine.arguments
        if arguments.count < 9 {
            print(self.usage)
            return
        }

        let modeArg = arguments[2]
        let pac = arguments[4]
        let httpPort = arguments[6]
        let sockPort = arguments[8]
        let mode = self.RunMode(rawValue: modeArg) ?? .manual

        self.setProxy(mode: mode, pacUrl: pac, httpPort: httpPort, sockPort: sockPort)
    }

    static func setProxy(mode: RunMode, pacUrl: String, httpPort: String, sockPort: String) {
        let authErr = AuthorizationCreate(nil, nil, [.interactionAllowed, .extendRights, .preAuthorize], &authRef)
        if (authErr != noErr) {
            authRef = nil;
            NSLog("Error when create authorization");
            return;
        } else {
            if (authRef == nil) {
                NSLog("No authorization has been granted to modify network configuration");
                return;
            }

            // set system proxy
            let prefRef = SCPreferencesCreateWithAuthorization(kCFAllocatorDefault, "V2rayU" as CFString, nil, authRef)!
            let sets = SCPreferencesGetValue(prefRef, kSCPrefNetworkServices)!

            // backup system proxy
            if mode == .backup {
                (sets as! NSDictionary).write(toFile: SysProxyBackupPlist, atomically: true)
                return
            }

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

            // pac mode
            if mode == .pac {
                proxies[kCFNetworkProxiesProxyAutoConfigURLString] = pacUrl as AnyObject
                proxies[kCFNetworkProxiesProxyAutoConfigEnable] = 1 as NSNumber
            }

            // restore system proxy setting in off or manual or restore
            var originalSets: Dictionary<String, Dictionary<String, Any>>?
            if mode == .off || mode == .manual || mode == .restore {
                originalSets = (NSDictionary(contentsOfFile: SysProxyBackupPlist) as? Dictionary<String, Dictionary<String, Any>>)
            }

            sets.allKeys!.forEach { (key) in
                let dict = sets.object(forKey: key)!
                let hardware = (dict as AnyObject).value(forKeyPath: "Interface.Hardware")

                if hardware != nil && ["AirPort", "Wi-Fi", "Ethernet"].contains(hardware as! String) {
                    // restore system proxy setting in off or manual or restore
                    if (mode == .off || mode == .manual || mode == .restore) && originalSets != nil && originalSets!.keys.contains(key) {
                        if let nowSet = originalSets![key] {
                            proxies = nowSet["Proxies"] as! [NSObject: AnyObject];
                        }
                    }

                    SCPreferencesPathSetValue(prefRef, "/\(kSCPrefNetworkServices)/\(key)/\(kSCEntNetProxies)" as CFString, proxies as CFDictionary)
                }
            }

            // commit to system preferences.
            let commitRet = SCPreferencesCommitChanges(prefRef)
            let applyRet = SCPreferencesApplyChanges(prefRef)
            SCPreferencesSynchronize(prefRef)
            // AuthorizationFree(authRef, kAuthorizationFlagDefaults)
            Swift.print("after SCPreferencesCommitChanges: commitRet = \(commitRet), applyRet = \(applyRet)")
        }
    }
}

V2rayUTool.run()
