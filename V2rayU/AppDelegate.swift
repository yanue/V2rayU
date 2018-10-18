//
//  AppDelegate.swift
//  V2rayU
//
//  Created by yanue on 2018/10/9.
//  Copyright © 2018 yanue. All rights reserved.
//

import Cocoa
import ServiceManagement
import os.log
import LaunchAtLogin

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    // bar menu
    @IBOutlet weak var statusMenu: NSMenu!
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
        os_log("v2rayu init.")

        print(LaunchAtLogin.isEnabled)
        //=> false
        
        LaunchAtLogin.isEnabled = true
        
        print(LaunchAtLogin.isEnabled)
        //=> true
    
        // 定义NSUserNotification
        let userNotification = NSUserNotification()
        userNotification.title = "消息Title"
        userNotification.subtitle = "消息SubTitle"
        userNotification.informativeText = "消息InformativeText"
        // 使用NSUserNotificationCenter发送NSUserNotification
        let userNotificationCenter = NSUserNotificationCenter.default
        userNotificationCenter.scheduleNotification(userNotification)
       
        //
//        UserDefaults.standard.register(defaults: ["NSApplicationCrashOnExceptions": true])
//
//        print("startedAtLogin", isRunning)
//
//        // v2ray-core check version
//        V2rayCore().check()
//        generateSSLocalLauchAgentPlist()
//        StartV2rayCore()
    }
  
    
    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
        print("Terminate")
        StopV2rayCore()
    }
}


