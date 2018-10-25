//
//  V2rayConfig.swift
//  V2rayU
//
//  Created by yanue on 2018/10/25.
//  Copyright © 2018 yanue. All rights reserved.
//

import Foundation

class V2rayConfig: NSObject {
    enum v2rayLogLevel:String {
        case debug
        case info
        case warning
        case error
        case none
    }
        
    // import by url
    static func importByUrl(jsonUrl: String) {
        
    }
    
    func saveByJson() {
        
    }
    
    // create current v2ray server json file
    static func createJsonFile(item:v2rayItem) {
        let jsonText = item.json
        
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
    
    func valid() {
        
    }
    
    func replaceRegular() {
        
    }
    
}
