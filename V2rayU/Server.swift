//
//  Server.swift
//  V2rayU
//
//  Created by yanue on 2018/10/10.
//  Copyright © 2018 yanue. All rights reserved.
//

import Foundation

struct serverItem:Decodable {
    let remark: String
    let name: String
    let usable: String?
}

class ConfigServer: NSObject {
    var tableViewData:[serverItem] = []
    
    // init
    override init() {
        super.init()
        self.loadConfig()
    }
    
    // load to dictionary
    func source() -> [Dictionary<String, String>] {
        var res:[Dictionary<String, String>]=[]
        for item in tableViewData {
            var dict1:Dictionary<String, String> = [:]
            dict1["remark"]=item.remark
            dict1["name"]=item.name
            dict1["usable"]=item.usable
            res.append(dict1)
        }
        return res
    }

    func list() -> [serverItem] {
        return tableViewData
    }
    
    func count() -> Int {
       return self.tableViewData.count
    }
    
    func add() -> [serverItem] {
        self.tableViewData.append(serverItem(remark: "new server", name: "new server", usable:"0"))
        return self.tableViewData
    }

    func remove(idx: Int) -> [serverItem] {
        guard idx >= 0 && idx < tableViewData.count else {
            print("Index out of bounds while deleting item at index \(index) in \(self). This action is ignored.")
            return tableViewData
        }
        // delete from tmp
        tableViewData.remove(at: idx)
        // todo delete file
        return tableViewData
    }
    
    func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        print("paths",paths)
        return paths[0]
    }
    
    func json(from object:Any) -> String? {
        guard let data = try? JSONSerialization.data(withJSONObject: object, options: []) else {
            return nil
        }
        return String(data: data, encoding: String.Encoding.utf8)
    }
    
    func loadConfig() {
        let configFile = getDocumentsDirectory().appendingPathComponent(".config")
        //reading
        do {
            let text = try String(contentsOf: configFile, encoding: .utf8)
            let data = text.data(using: .utf8)!

            guard let items = (try? JSONDecoder().decode([serverItem].self, from: data)) else {
                print("Error: Couldn't decode config data ")
                return
            }
            
            self.tableViewData = []
            for item in items {
                 self.tableViewData.append(item)
            }
        } catch {
            /* error handling here */
            print("Error: Couldn't decode data into Blog")
            return
        }
    }
    
    func loadFile(idx:Int) -> String {
        if !tableViewData.indices.contains(idx) {
            print("index out of range",idx)
            return ""
        }
        
        let name = self.tableViewData[idx].name
        if name == "" {
            print("name is empty")
            return ""
        }
        
        let jsonFile = getDocumentsDirectory().appendingPathComponent(name+".json")
        //reading
        do {
            let text = try String(contentsOf: jsonFile, encoding: .utf8)
            return text
        } catch {
            /* error handling here */
            print("Error: load json config file")
            return ""
        }
    }
    
    func save(text:String,idx:Int)  {
        if !tableViewData.indices.contains(idx) {
            print("index out of range",idx)
            return
        }

        let name = self.tableViewData[idx].name
        if name == "" {
            print("name is empty")
            return
        }
        
        // todo check json
        let jsonFile = getDocumentsDirectory().appendingPathComponent(name+".json")
        
        do {
            try text.write(to: jsonFile, atomically: true, encoding: String.Encoding.utf8)
        } catch {
            // failed to write file – bad permissions, bad filename, missing permissions, or more likely it can't be converted to the encoding
        }
        
        // todo check json
        let configFile = getDocumentsDirectory().appendingPathComponent(".config")
        do {
            let config = self.json(from: self.source())
            try config?.write(to: configFile, atomically: true, encoding: String.Encoding.utf8)
        } catch {
            // failed to write file – bad permissions, bad filename, missing permissions, or more likely it can't be converted to the encoding
        }
    }
    
}
