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
    static private var tableViewData:[v2rayItem] = []

    // (init) load v2ray server list from UserDefaults
    static func loadConfig() {
        // static reset
        self.tableViewData = []
        
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
            guard let v2ray = v2rayItem.load(name:item) else {
                // delete from UserDefaults
                v2rayItem.remove(name: item)
                continue
            }
            
            // append
            self.tableViewData.append(v2ray)
        }
    }
    
    // get list from v2ray server list
    static func list() -> [v2rayItem] {
        return self.tableViewData
    }
    
    // get count from v2ray server list
    static func count() -> Int {
       return self.tableViewData.count
    }
    
    // add v2ray server (tmp)
    static func add() {
        if self.tableViewData.count > 20 {
            print("over max len")
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
        self.tableViewData.append(v2ray)
        
        // update server list UserDefaults
        self.saveItemList()
    }
    
    // remove v2ray server (tmp and UserDefaults and config json file)
    static func remove(idx: Int) {
        if !V2rayServer.tableViewData.indices.contains(idx) {
            print("index out of range",idx)
            return
        }
        
        let v2ray = V2rayServer.tableViewData[idx]
        
        // delete from tmp
        self.tableViewData.remove(at: idx)
        
        // delete from v2ray UserDefaults
        v2rayItem.remove(name: v2ray.name)
    
        // update server list UserDefaults
        self.saveItemList()
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
        if !V2rayServer.tableViewData.indices.contains(idx) {
            print("index out of range",idx)
            return nil
        }
        
        return self.tableViewData[idx]
    }
    
    // load selected v2ray item
    static func loadSelectedItem() -> v2rayItem? {
        guard let curName = UserDefaults.get(forKey: .v2rayCurrentServerName) else {
            return nil
        }
        
       return v2rayItem.load(name: curName)
    }
    
    // save json data into local file
    static func save(jsonData:String,idx:Int)  {
        if !self.tableViewData.indices.contains(idx) {
            print("index out of range",idx)
            return
        }

        let v2ray = self.tableViewData[idx]
        if v2ray.name == "" {
            print("name is empty")
            return
        }
        
        guard let json = try? JSON(data: jsonData.data(using: String.Encoding.utf8, allowLossyConversion: false)!) else {
            print("invalid json")
            return
        }
        
        if !json.exists(){
            print("invalid json")
            return
        }
        
        if !json["dns"].exists() {
            print("missing inbound")
            return
        }
        
        if !json["inbound"].exists() {
            print("missing inbound")
            return
        }
        
        if !json["outbound"].exists() {
            print("missing outbound")
            return
        }
        
        if !json["routing"].exists() {
            print("missing routing")
            return
        }
        
        // store
        v2ray.usable = true
        v2ray.json = jsonData
        v2ray.store()
        
        // update current
        self.tableViewData[idx].usable = true
    }
}

// ----- v2ray server item -----
class v2rayItem: NSObject, NSCoding {
    var name: String
    var remark: String
    var usable: Bool
    var json: String
    
    // init
    required init(name:String="", remark:String="", usable: Bool=false, json:String="") {
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
        self.usable = decoder.decodeObject(forKey: "Usable") as? Bool ?? false
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
