//
//  V2rayRouting.swift
//  V2rayU
//
//  Created by yanue on 2024/6/27.
//  Copyright © 2024 yanue. All rights reserved.
//

import Foundation


// ----- routing server manager -----
class V2rayRoutings: NSObject {
    static var shared = V2rayRoutings()

    static private let defaultV2rayName = "routing.default"
    static let lock = NSLock()
    
    // Initialization
    override init() {
        super.init()
        V2rayRoutings.loadConfig()
    }

    // routing server list
    static private var routings: [RoutingItem] = []

    // (init) load routing server list from UserDefaults
    static func loadConfig() {
        self.lock.lock()
        defer {
            self.lock.unlock()
        }

        // static reset
        self.routings = []

        // load name list from UserDefaults
        var list = UserDefaults.getArray(forKey: .routingCustomList)
        print("V2rayRoutings-loadConfig", list)
        if list == nil {
            list = ["default"]
            // store default
            let model = RoutingItem(name: self.defaultV2rayName, remark: "default")
            model.store()
        }

        // load each RoutingItem
        for item in list! {
            guard let routing = RoutingItem.load(name: item) else {
                // delete from UserDefaults
                RoutingItem.remove(name: item)
                continue
            }
            // append
            self.routings.append(routing)
        }
        print("V2rayRoutings-loadConfig", self.routings.count)
    }
    
    static func all()  -> [RoutingItem] {
        // static reset
        var items : [RoutingItem] = []

        // load name list from UserDefaults
        var list = UserDefaults.getArray(forKey: .routingCustomList)

        if list == nil {
            list = ["default"]
            // store default
            let model = RoutingItem(name: self.defaultV2rayName, remark: "default")
            model.store()
        }

        // load each RoutingItem
        for item in list! {
            guard let routing = RoutingItem.load(name: item) else {
                // delete from UserDefaults
                RoutingItem.remove(name: item)
                continue
            }
            // append
            items.append(routing)
        }
        return items
    }
    

    // get list from routing server list
    static func list() -> [RoutingItem] {
        return self.routings
    }

    // get count from routing server list
    static func count() -> Int {
        return self.routings.count
    }

    static func edit(rowIndex: Int, remark: String) {
        if !self.routings.indices.contains(rowIndex) {
            NSLog("index out of range", rowIndex)
            return
        }

        // update list
        self.routings[rowIndex].remark = remark

        // save
        let routing = self.routings[rowIndex]
        routing.remark = remark
        routing.store()
    }

    // move item to new index
    static func move(oldIndex: Int, newIndex: Int) {
        if !V2rayRoutings.routings.indices.contains(oldIndex) {
            NSLog("index out of range", oldIndex)
            return
        }
        if !V2rayRoutings.routings.indices.contains(newIndex) {
            NSLog("index out of range", newIndex)
            return
        }

        let o = self.routings[oldIndex]
        self.routings.remove(at: oldIndex)
        self.routings.insert(o, at: newIndex)

        // update server list UserDefaults
        self.saveItemList()
    }

    // add routing server (by scan qrcode)
    static func add(remark: String, json: String) {
        var remark_ = remark
        if remark.count == 0 {
            remark_ = "new routing"
        }

        // name is : routing. + uuid
        let name = "routing." + UUID().uuidString

        let routing = RoutingItem(name: name, remark: remark_, json: json)
        // save to routing UserDefaults
        routing.store()
        

        // just add to mem
        self.routings.append(routing)
        print("routing", name, self.routings)

        // update server list UserDefaults
        self.saveItemList()
    }
    
    static func edit(rowIndex: Int, remark: String,json: String) {
        if !self.routings.indices.contains(rowIndex) {
            NSLog("index out of range", rowIndex)
            return
        }

        // save
        let v2ray = self.routings[rowIndex]
        v2ray.remark = remark
        v2ray.json = json
        v2ray.store()
        
        // update list
        self.routings[rowIndex] = v2ray
    }
    
    // remove routing server (tmp and UserDefaults and config json file)
    static func remove(idx: Int) {
        if !V2rayRoutings.routings.indices.contains(idx) {
            NSLog("index out of range", idx)
            return
        }

        let routing = V2rayRoutings.routings[idx]

        // delete from tmp
        self.routings.remove(at: idx)

        // delete from routing UserDefaults
        RoutingItem.remove(name: routing.name)

        // update server list UserDefaults
        self.saveItemList()

        // if cuerrent item is default
        let curName = UserDefaults.get(forKey: .v2rayCurrentServerName)
        if curName != nil && routing.name == curName {
            UserDefaults.del(forKey: .v2rayCurrentServerName)
        }
    }

    // update server list UserDefaults
    static func saveItemList() {
        var routingCustomList: Array<String> = []
        for item in V2rayRoutings.list() {
            routingCustomList.append(item.name)
        }
        
        print("routingCustomList", routingCustomList);
        UserDefaults.setArray(forKey: .routingCustomList, value: routingCustomList)
    }

    // load json file data
    static func load(idx: Int) -> RoutingItem? {
        if !V2rayRoutings.routings.indices.contains(idx) {
            NSLog("index out of range", idx)
            return nil
        }

        return self.routings[idx]
    }

    // save json data
    static func save(idx: Int, jsonData: String) -> String {
        if !self.routings.indices.contains(idx) {
            return "index out of range"
        }

        let routing = self.routings[idx]

        // store
        routing.json = jsonData
        routing.store()

        // update current
        self.routings[idx] = routing
        return ""
    }

    static func save(routing: RoutingItem, jsonData: String) {
        // store
        routing.json = jsonData
        routing.store()

        // refresh data
        for (idx, item) in self.routings.enumerated() {
            if item.name == routing.name {
                self.routings[idx].json = jsonData
                break
            }
        }
    }

    // get by name
    static func getIndex(name: String) -> Int {
        for (idx, item) in self.routings.enumerated() {
            if item.name == name {
                return idx
            }
        }
        return -1
    }
}

// ----- routing routing item -----
class RoutingItem: NSObject, NSCoding {
    var name: String
    var remark: String
    var json: String

    // Initializer
    init(name: String, remark: String, json: String = "") {
        self.name = name
        self.remark = remark
        self.json = json
    }

    // NSCoding required initializer (decoding)
    required init(coder decoder: NSCoder) {
        self.name = decoder.decodeObject(forKey: "Name") as? String ?? ""
        self.remark = decoder.decodeObject(forKey: "Remark") as? String ?? ""
        self.json = decoder.decodeObject(forKey: "Json") as? String ?? ""
    }

    // NSCoding required method (encoding)
    func encode(with coder: NSCoder) {
        coder.encode(name, forKey: "Name")
        coder.encode(remark, forKey: "Remark")
        coder.encode(json, forKey: "Json")
    }

    // Store into UserDefaults
    func store() {
        let modelData = NSKeyedArchiver.archivedData(withRootObject: self)
        UserDefaults.standard.set(modelData, forKey: self.name)
    }

    // static load from UserDefaults
    static func load(name: String) -> RoutingItem? {
        guard let myModelData = UserDefaults.standard.data(forKey: name) else {
            print("load userDefault not found:",name)
            return nil
        }
        do {
            // unarchivedObject(ofClass:from:)
            let result = try NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(myModelData)
            return result as? RoutingItem
        } catch let error {
            print("load userDefault error:", error)
            return nil
        }
    }

    // remove from UserDefaults
    static func remove(name: String) {
        UserDefaults.standard.removeObject(forKey: name)
    }
}
