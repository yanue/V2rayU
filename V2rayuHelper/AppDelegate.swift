//
//  AppDelegate.swift
//  V2rayuHelper
//
//  Created by yanue on 2018/10/19.
//  Copyright © 2018 yanue. All rights reserved.
//

import Cocoa

class V2rayuHelperApplication: NSApplication {
    let strongDelegate = AppDelegate()
    
    override init() {
        super.init()
        self.delegate = strongDelegate
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    
    public func applicationDidFinishLaunching(_ notification: Notification) {
        let mainAppIdentifier = "net.yanue.V2rayU"
        let running = NSWorkspace.shared.runningApplications
        var alreadyRunning = false
        
        for app in running {
            if app.bundleIdentifier == mainAppIdentifier {
                alreadyRunning = true
                break
            }
        }
        
        if !alreadyRunning {
            DistributedNotificationCenter.default().addObserver(NSApp, selector: #selector(NSApplication.terminate(_:)), name: Notification.Name("terminateV2ray"), object: mainAppIdentifier)
            
            let path = Bundle.main.bundlePath as NSString
            var components = path.pathComponents
            components.removeLast()
            components.removeLast()
            components.removeLast()
            components.append("MacOS")
            components.append("V2rayU")
            
            let newPath = NSString.path(withComponents: components)
            NSWorkspace.shared.launchApplication(newPath)
        } else {
            NSApp.terminate(self)
        }
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        print("helper app terminated")
        // Insert code here to tear down your application
    }
    
    
}

