//
//  Server.swift
//  V2rayU
//
//  Created by yanue on 2018/10/10.
//  Copyright © 2018 yanue. All rights reserved.
//

import Foundation
import SwiftyJSON

// ----- v2ray server manager -----
class V2rayServer: NSObject {
    static var shared = V2rayServer()
    
    static private let defaultV2rayName = "config.default"
    
    // Initialization
    override init() {
        super.init()
        V2rayServer.loadConfig()
    }
    
    // v2ray server list
    static private var v2rayItemList:[v2rayItem] = []

    // (init) load v2ray server list from UserDefaults
    static func loadConfig() {
        // static reset
        self.v2rayItemList = []
        
        // load name list from UserDefaults
        var list = UserDefaults.getArray(forKey: .v2rayServerList)

        if list == nil {
            list = ["default"]
            // store default
            let model = v2rayItem(name: self.defaultV2rayName, remark: "default",usable:false)
            model.store()
        }
        
        // load each v2rayItem
        for item in list! {
            guard let v2ray = v2rayItem.load(name: item) else {
                // delete from UserDefaults
                v2rayItem.remove(name: item)
                continue
            }
            // append
            self.v2rayItemList.append(v2ray)
        }
    }
    
    // get list from v2ray server list
    static func list() -> [v2rayItem] {
        return self.v2rayItemList
    }
    
    // get count from v2ray server list
    static func count() -> Int {
       return self.v2rayItemList.count
    }
    
    static func edit(rowIndex:Int, remark:String) {
        if !self.v2rayItemList.indices.contains(rowIndex) {
            NSLog("index out of range",rowIndex)
            return
        }
        
        // update list
        self.v2rayItemList[rowIndex].remark = remark
        
        // save
        let v2ray = self.v2rayItemList[rowIndex]
        v2ray.remark = remark
        v2ray.store()
    }
    
    // move item to new index
    static func move(oldIndex:Int, newIndex:Int) {
        if !V2rayServer.v2rayItemList.indices.contains(oldIndex) {
            NSLog("index out of range",oldIndex)
            return
        }
        if !V2rayServer.v2rayItemList.indices.contains(newIndex) {
            NSLog("index out of range",newIndex)
            return
        }
        
        let o = self.v2rayItemList[oldIndex]
        self.v2rayItemList.remove(at: oldIndex)
        self.v2rayItemList.insert(o, at: newIndex)
        
        // update server list UserDefaults
        self.saveItemList()
    }
    
    // add v2ray server (tmp)
    static func add() {
        if self.v2rayItemList.count > 20 {
            NSLog("over max len")
            return
        }
        
        let now = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let dateStr = dateFormatter.string(from: now)

        // name is : config. + current time str
        let name = "config."+dateStr
        
        let v2ray = v2rayItem(name: name, remark: "new server", usable:false)
        // save to v2ray UserDefaults
        v2ray.store()
        
        // just add to mem
        self.v2rayItemList.append(v2ray)
        
        // update server list UserDefaults
        self.saveItemList()
    }
    
    // remove v2ray server (tmp and UserDefaults and config json file)
    static func remove(idx: Int) {
        if !V2rayServer.v2rayItemList.indices.contains(idx) {
            NSLog("index out of range",idx)
            return
        }
        
        let v2ray = V2rayServer.v2rayItemList[idx]
        
        // delete from tmp
        self.v2rayItemList.remove(at: idx)
        
        // delete from v2ray UserDefaults
        v2rayItem.remove(name: v2ray.name)
    
        // update server list UserDefaults
        self.saveItemList()
        
        // if cuerrent item is default
        let curName = UserDefaults.get(forKey: .v2rayCurrentServerName)
        if  curName != nil && v2ray.name == curName {
            UserDefaults.del(forKey: .v2rayCurrentServerName)
        }
    }
    
    // update server list UserDefaults
    static private func saveItemList() {
        var v2rayServerList:Array<String> = []
        for item in V2rayServer.list(){
            v2rayServerList.append(item.name)
        }
        
        UserDefaults.setArray(forKey: .v2rayServerList, value: v2rayServerList)
    }

    // get json file url
    static func getJsonFile() -> String? {
        return Bundle.main.url(forResource: "unzip", withExtension:"sh")?.path.replacingOccurrences(of: "/unzip.sh", with: "/config.json")
    }
    
    // load json file data
    static func loadV2rayItem(idx:Int) -> v2rayItem? {
        if !V2rayServer.v2rayItemList.indices.contains(idx) {
            NSLog("index out of range",idx)
            return nil
        }
        
        return self.v2rayItemList[idx]
    }
    
    // load selected v2ray item
    static func loadSelectedItem() -> v2rayItem? {
        
        var v2ray:v2rayItem? = nil
        
        if let curName = UserDefaults.get(forKey: .v2rayCurrentServerName) {
            v2ray = v2rayItem.load(name: curName)
        }
        
        // if default server not fould
        if v2ray == nil {
            for item in self.v2rayItemList {
                if item.usable {
                    v2ray = v2rayItem.load(name: item.name)
                    break
                }
            }
        }
        
        return v2ray
    }
    
    // save json data
    static func save(idx:Int, jsonData:String) -> String {
        var isUsable = false
        
        if !self.v2rayItemList.indices.contains(idx) {
            return "index out of range"
        }
        
        let v2ray = self.v2rayItemList[idx]
        
        defer {
            // store
            v2ray.usable = isUsable
            v2ray.json = jsonData
            v2ray.store()
            
            // update current
            self.v2rayItemList[idx] = v2ray
            
            if isUsable {
                // if just one usable server
                // set as default server
                var usableCount = 0
                for item in v2rayItemList {
                    if item.usable {
                        usableCount += 1
                    }
                }
                
                // contain self
                if usableCount <= 1 {
                    UserDefaults.set(forKey: .v2rayCurrentServerName, value: v2ray.name)
                }
            }
        }

        if v2ray.name == "" {
            return "name is empty"
        }
        
        guard let json = try? JSON(data: jsonData.data(using: String.Encoding.utf8, allowLossyConversion: false)!) else {
            return "invalid json"
        }
        
        if !json.exists(){
            return "invalid json"
        }
        
        if !json["dns"].exists() {
//            return "missing dns"
        }
        
        if !json["inbound"].exists() {
            return "missing inbound"
        }
        
        if !json["outbound"].exists() {
            return "missing outbound"
        }
        
        if !json["routing"].exists() {
            return "missing routing"
        }

        isUsable = true

        return ""
    }
}

// ----- v2ray server item -----
class v2rayItem: NSObject, NSCoding {
    var name: String
    var remark: String
    var json: String
    var usable: Bool

    // init
    required init(name: String, remark: String, usable: Bool, json: String="") {
        self.name = name
        self.remark = remark
        self.json = json
        self.usable = usable
    }
    
    // decode
    required init(coder decoder: NSCoder) {
        self.name = decoder.decodeObject(forKey: "Name") as? String ?? ""
        self.remark = decoder.decodeObject(forKey: "Remark") as? String ?? ""
        self.json = decoder.decodeObject(forKey: "Json") as? String ?? ""
        self.usable = decoder.decodeBool(forKey: "Usable")
    }
    
    // object encode
    func encode(with coder: NSCoder) {
        coder.encode(name, forKey:"Name")
        coder.encode(remark, forKey:"Remark")
        coder.encode(json, forKey:"Json")
        coder.encode(usable, forKey:"Usable")
    }
    
    // store into UserDefaults
    func store() {
        let modelData = NSKeyedArchiver.archivedData(withRootObject: self)
        UserDefaults.standard.set(modelData, forKey: self.name)
    }

    // static load from UserDefaults
    static func load(name:String) -> v2rayItem? {
        guard let myModelData = UserDefaults.standard.data(forKey: name) else {
            return nil
        }
        return NSKeyedUnarchiver.unarchiveObject(with: myModelData) as? v2rayItem
    }
    
    // remove from UserDefaults
    static func remove(name:String) {
        UserDefaults.standard.removeObject(forKey: name)
    }
}
