//
//  main.swift
//  V2rayUHelper
//
//  Created by yanue on 2018/12/19.
//  Copyright © 2018 yanue. All rights reserved.
//

import Foundation
import SystemConfiguration

var authRef: AuthorizationRef?

class V2rayUCmd: NSObject {
    static let usage = "Usage: V2rayUCmd -mode <global|manual|pac|off> -pac <url> -http-port <port> -sock-port <port>"

    enum RunMode: String {
        case global
        case manual
        case pac
        case off
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
        // setup policy database db
//        CommonAuthorization.shared.setupAuthorizationRights(authRef: authRef!)
        // authRef
        // kAuthorizationFlagDefaults | kAuthorizationFlagExtendRights | kAuthorizationFlagInteractionAllowed | kAuthorizationFlagPreAuthorize;
        let authErr = AuthorizationCreate(nil, nil, [.interactionAllowed, .extendRights, .preAuthorize], &authRef)

        // copy rights
//        let rightName: String = CommonAuthorization.systemProxyAuthRightName
//        var authItem = AuthorizationItem(name: (rightName as NSString).utf8String!, valueLength: 0, value: UnsafeMutableRawPointer(bitPattern: 0), flags: 0)
//        var authRight: AuthorizationRights = AuthorizationRights(count: 1, items: &authItem)

//        let copyRightStatus = AuthorizationCopyRights(authRef!, &authRight, nil, [.extendRights, .interactionAllowed, .preAuthorize, .partialRights], nil)

//        Swift.print("AuthorizationCopyRights result: \(copyRightStatus), right name: \(rightName)")
//        assert(copyRightStatus == errAuthorizationSuccess)
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
                proxies[kCFNetworkProxiesProxyAutoConfigURLString] = pacUrl as AnyObject
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
//            AuthorizationFree(authRef, kAuthorizationFlagDefaults)
            Swift.print("after SCPreferencesCommitChanges: commitRet = \(commitRet), applyRet = \(applyRet)")
        }
    }
}

V2rayUCmd.run()
