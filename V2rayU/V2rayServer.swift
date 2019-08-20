//
//  Server.swift
//  V2rayU
//
//  Created by yanue on 2018/10/10.
//  Copyright © 2018 yanue. All rights reserved.
//

import Cocoa
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
    static private var v2rayItemList: [V2rayItem] = []

    // (init) load v2ray server list from UserDefaults
    static func loadConfig() {
        // static reset
        self.v2rayItemList = []

        // load name list from UserDefaults
        var list = UserDefaults.getArray(forKey: .v2rayServerList)

        if list == nil {
            list = ["default"]
            // store default
            let model = V2rayItem(name: self.defaultV2rayName, remark: "default", isValid: false)
            model.store()
        }

        // load each V2rayItem
        for item in list! {
            guard let v2ray = V2rayItem.load(name: item) else {
                // delete from UserDefaults
                V2rayItem.remove(name: item)
                continue
            }
            // append
            self.v2rayItemList.append(v2ray)
        }
    }

    // get list from v2ray server list
    static func list() -> [V2rayItem] {
        return self.v2rayItemList
    }

    // get count from v2ray server list
    static func count() -> Int {
        return self.v2rayItemList.count
    }

    static func edit(rowIndex: Int, remark: String) {
        if !self.v2rayItemList.indices.contains(rowIndex) {
            NSLog("index out of range", rowIndex)
            return
        }

        // update list
        self.v2rayItemList[rowIndex].remark = remark

        // save
        let v2ray = self.v2rayItemList[rowIndex]
        v2ray.remark = remark
        v2ray.store()
    }

    static func edit(rowIndex: Int, url: String) {
        if !self.v2rayItemList.indices.contains(rowIndex) {
            NSLog("index out of range", rowIndex)
            return
        }

        // update list
        self.v2rayItemList[rowIndex].url = url

        // save
        let v2ray = self.v2rayItemList[rowIndex]
        v2ray.url = url
        v2ray.store()
    }


    // move item to new index
    static func move(oldIndex: Int, newIndex: Int) {
        if !V2rayServer.v2rayItemList.indices.contains(oldIndex) {
            NSLog("index out of range", oldIndex)
            return
        }
        if !V2rayServer.v2rayItemList.indices.contains(newIndex) {
            NSLog("index out of range", newIndex)
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
        // name is : config. + uuid
        let name = "config." + UUID().uuidString

        let v2ray = V2rayItem(name: name, remark: "new server", isValid: false)
        // save to v2ray UserDefaults
        v2ray.store()

        // just add to mem
        self.v2rayItemList.append(v2ray)

        // update server list UserDefaults
        self.saveItemList()
    }

    // add v2ray server (by scan qrcode)
    static func add(remark: String, json: String, isValid: Bool, url: String = "", subscribe: String = "") {
        var remark_ = remark
        if remark.count == 0 {
            remark_ = "new server"
        }

        // name is : config. + uuid
        let name = "config." + UUID().uuidString

        let v2ray = V2rayItem(name: name, remark: remark_, isValid: isValid, json: json, url: url, subscribe: subscribe)
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
            NSLog("index out of range", idx)
            return
        }

        let v2ray = V2rayServer.v2rayItemList[idx]

        // delete from tmp
        self.v2rayItemList.remove(at: idx)

        // delete from v2ray UserDefaults
        V2rayItem.remove(name: v2ray.name)

        // update server list UserDefaults
        self.saveItemList()

        // if cuerrent item is default
        let curName = UserDefaults.get(forKey: .v2rayCurrentServerName)
        if curName != nil && v2ray.name == curName {
            UserDefaults.del(forKey: .v2rayCurrentServerName)
        }
    }

    // remove v2ray server by subscribe
    static func remove(subscribe: String) {
        let curName = UserDefaults.get(forKey: .v2rayCurrentServerName)

        for item in V2rayServer.v2rayItemList {
            print("remove item: ", subscribe, item.subscribe)
            if item.subscribe == subscribe {
                V2rayItem.remove(name: item.name)
                // if cuerrent item is default
                if curName != nil && item.name == curName {
                    UserDefaults.del(forKey: .v2rayCurrentServerName)
                }
            }
        }

        // update server list UserDefaults
        self.saveItemList()

        // reload
        V2rayServer.loadConfig()

        // reload config
        if menuController.configWindow != nil {
            menuController.configWindow.serversTableView.reloadData()
        }

        // refresh server
        menuController.showServers()
    }

    // update server list UserDefaults
    static private func saveItemList() {
        var v2rayServerList: Array<String> = []
        for item in V2rayServer.list() {
            v2rayServerList.append(item.name)
        }

        UserDefaults.setArray(forKey: .v2rayServerList, value: v2rayServerList)
    }

    // check url is exists
    static func exist(url: String) -> Bool {
        for item in self.v2rayItemList {
            if item.url == url {
                return true
            }
        }

        return false
    }

    // get json file url
    static func getJsonFile() -> String? {
        return Bundle.main.url(forResource: "unzip", withExtension: "sh")?.path.replacingOccurrences(of: "/unzip.sh", with: "/config.json")
    }

    // load json file data
    static func loadV2rayItem(idx: Int) -> V2rayItem? {
        if !V2rayServer.v2rayItemList.indices.contains(idx) {
            NSLog("index out of range", idx)
            return nil
        }

        return self.v2rayItemList[idx]
    }

    // load selected v2ray item
    static func loadSelectedItem() -> V2rayItem? {

        var v2ray: V2rayItem? = nil

        if let curName = UserDefaults.get(forKey: .v2rayCurrentServerName) {
            v2ray = V2rayItem.load(name: curName)
        }

        // if default server not found
        if v2ray == nil {
            for item in self.v2rayItemList {
                if item.isValid {
                    v2ray = V2rayItem.load(name: item.name)
                    break
                }
            }
        }

        return v2ray
    }

    // save json data
    static func save(idx: Int, isValid: Bool, jsonData: String) -> String {
        if !self.v2rayItemList.indices.contains(idx) {
            return "index out of range"
        }

        let v2ray = self.v2rayItemList[idx]

        // store
        v2ray.isValid = isValid
        v2ray.json = jsonData
        v2ray.store()

        // update current
        self.v2rayItemList[idx] = v2ray
        var usableCount = 0

        if isValid {
            // if just one isValid server
            // set as default server
            for item in v2rayItemList {
                if item.isValid {
                    usableCount += 1
                }
            }

            // contain self
            if usableCount <= 1 {
                UserDefaults.set(forKey: .v2rayCurrentServerName, value: v2ray.name)
            }
        }

        return ""
    }

    // get by name
    static func getIndex(name: String) -> Int {
        for (idx, item) in self.v2rayItemList.enumerated() {
            if item.name == name {
                return idx
            }
        }
        return -1
    }
}

// ----- v2ray server item -----
class V2rayItem: NSObject, NSCoding {
    var name: String
    var remark: String
    var json: String
    var isValid: Bool
    var url: String
    var subscribe: String // subscript name: uuid

    // init
    required init(name: String, remark: String, isValid: Bool, json: String = "", url: String = "", subscribe: String = "") {
        self.name = name
        self.remark = remark
        self.json = json
        self.isValid = isValid
        self.url = url
        self.subscribe = subscribe
    }

    // decode
    required init(coder decoder: NSCoder) {
        self.name = decoder.decodeObject(forKey: "Name") as? String ?? ""
        self.remark = decoder.decodeObject(forKey: "Remark") as? String ?? ""
        self.json = decoder.decodeObject(forKey: "Json") as? String ?? ""
        self.isValid = decoder.decodeBool(forKey: "IsValid")
        self.url = decoder.decodeObject(forKey: "Url") as? String ?? ""
        self.subscribe = decoder.decodeObject(forKey: "Subscribe") as? String ?? ""
    }

    // object encode
    func encode(with coder: NSCoder) {
        coder.encode(name, forKey: "Name")
        coder.encode(remark, forKey: "Remark")
        coder.encode(json, forKey: "Json")
        coder.encode(isValid, forKey: "IsValid")
        coder.encode(url, forKey: "Url")
        coder.encode(subscribe, forKey: "Subscribe")
    }

    // store into UserDefaults
    func store() {
        let modelData = NSKeyedArchiver.archivedData(withRootObject: self)
        UserDefaults.standard.set(modelData, forKey: self.name)
    }

    // static load from UserDefaults
    static func load(name: String) -> V2rayItem? {
        guard let myModelData = UserDefaults.standard.data(forKey: name) else {
            return nil
        }
        do {
            let result = try NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(myModelData)
            return result as? V2rayItem
        } catch {
            print("load userDefault error:", error)
            return nil
        }
    }

    // remove from UserDefaults
    static func remove(name: String) {
        UserDefaults.standard.removeObject(forKey: name)
    }
}
