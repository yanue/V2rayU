//
//  Launch.swift
//  V2rayU
//
//  Created by yanue on 2018/10/17.
//  Copyright © 2018 yanue. All rights reserved.
//

import Foundation

let LAUNCH_AGENT_DIR = "/Library/LaunchAgents/"
let LAUNCH_AGENT_PLIST = "yanue.v2rayu.v2ray-core.plist"
let logFilePath = NSHomeDirectory() + "/Library/Logs/v2rayu.log"
let launchAgentDirPath = NSHomeDirectory() + LAUNCH_AGENT_DIR
let launchAgentPlistFile = launchAgentDirPath + LAUNCH_AGENT_PLIST
let AppResourcesPath = Bundle.main.bundlePath + "/Contents/Resources"
let v2rayCoreFile = "v2ray-core/v2ray"
let v2rayCoreFullPath = AppResourcesPath + "/" + v2rayCoreFile

func generateSSLocalLauchAgentPlist() {

    // Ensure launch agent directory is existed.
    let fileMgr = FileManager.default
    if !fileMgr.fileExists(atPath: launchAgentDirPath) {
        try! fileMgr.createDirectory(atPath: launchAgentDirPath, withIntermediateDirectories: true, attributes: nil)
    }
    
    let arguments = [v2rayCoreFile, "-config", "config.json"]
    
    let dict: NSMutableDictionary = [
        "Label": LAUNCH_AGENT_PLIST.replacingOccurrences(of: ".plist", with: ""),
        "WorkingDirectory": AppResourcesPath,
        "StandardOutPath": logFilePath,
        "StandardErrorPath": logFilePath,
        "ProgramArguments": arguments,
        "KeepAlive":true,
        "RunAtLoad":true,
    ]
    
    dict.write(toFile: launchAgentPlistFile, atomically: true)
}

func StartV2rayCore() {
    // cmd: /bin/launchctl load -wF /Library/LaunchAgents/yanue.v2rayu.v2ray-core.plist
    let task = Process.launchedProcess(launchPath: "/bin/launchctl", arguments: ["load" ,"-wF",launchAgentPlistFile])
    task.waitUntilExit()
    if task.terminationStatus == 0 {
        NSLog("Start v2ray-core succeeded.")
    } else {
        NSLog("Start v2ray-core failed.")
    }
}

func StopV2rayCore() {
    // cmd: /bin/launchctl unload /Library/LaunchAgents/yanue.v2rayu.v2ray-core.plist
    let task = Process.launchedProcess(launchPath: "/bin/launchctl", arguments: ["unload" ,launchAgentPlistFile])
    task.waitUntilExit()
    if task.terminationStatus == 0 {
        NSLog("Stop v2ray-core succeeded.")
    } else {
        NSLog("Stop v2ray-core failed.")
    }
}

func OpenLogs(){
    let task = Process.launchedProcess(launchPath: "/usr/bin/open", arguments: [logFilePath])
    task.waitUntilExit()
    if task.terminationStatus == 0 {
        NSLog("open logs succeeded.")
    } else {
        NSLog("open logs failed.")
    }
}
