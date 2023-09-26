//
//  V2raySubscribe.swift
//  V2rayU
//
//  Created by yanue on 2019/5/15.
//  Copyright © 2019 yanue. All rights reserved.
//

import Cocoa
import Alamofire
import SwiftyJSON
import Yams

// ----- v2ray subscribe manager -----
class V2raySubscribe: NSObject {
    static var shared = V2raySubscribe()
    static let lock = NSLock()
    
    // Initialization
    override init() {
        super.init()
        print("V2raySubscribe init")
        V2raySubscribe.loadConfig()
    }

    // v2ray subscribe list
    static private var v2raySubList: [V2raySubItem] = []

    // (init) load v2ray subscribe list from UserDefaults
    static func loadConfig() {
        self.lock.lock()
        defer {
            self.lock.unlock()
        }
        // static reset
        self.v2raySubList = []

        // load name list from UserDefaults
        let list = UserDefaults.getArray(forKey: .v2raySubList)
//        print("loadConfig", list)

        if list == nil {
            return
        }
        // load each V2raySubItem
        for item in list! {
            guard let v2ray = V2raySubItem.load(name: item) else {
                // delete from UserDefaults
                V2raySubItem.remove(name: item)
                continue
            }
            // append
            self.v2raySubList.append(v2ray)
        }
    }

    // get list from v2ray subscribe list
    static func list() -> [V2raySubItem] {
        return self.v2raySubList
    }

    // get count from v2ray subscribe list
    static func count() -> Int {
        return self.v2raySubList.count
    }

    static func edit(rowIndex: Int, remark: String) {
        if !self.v2raySubList.indices.contains(rowIndex) {
            NSLog("index out of range", rowIndex)
            return
        }

        // update list
        self.v2raySubList[rowIndex].remark = remark

        // save
        let v2ray = self.v2raySubList[rowIndex]
        v2ray.remark = remark
        v2ray.store()
    }

    static func edit(rowIndex: Int, url: String) {
        if !self.v2raySubList.indices.contains(rowIndex) {
            NSLog("index out of range", rowIndex)
            return
        }

        // update list
        self.v2raySubList[rowIndex].url = url

        // save
        let v2ray = self.v2raySubList[rowIndex]
        v2ray.url = url
        v2ray.store()
    }

    // move item to new index
    static func move(oldIndex: Int, newIndex: Int) {
        if !V2raySubscribe.v2raySubList.indices.contains(oldIndex) {
            NSLog("index out of range", oldIndex)
            return
        }
        if !V2raySubscribe.v2raySubList.indices.contains(newIndex) {
            NSLog("index out of range", newIndex)
            return
        }

        let o = self.v2raySubList[oldIndex]
        self.v2raySubList.remove(at: oldIndex)
        self.v2raySubList.insert(o, at: newIndex)

        // update subscribe list UserDefaults
        self.saveItemList()
    }

    // add v2ray subscribe (by scan qrcode)
    static func add(remark: String, url: String) {
        if self.v2raySubList.count > 50 {
//            NSLog("over max len")
//            return
        }

        // name is : subscribe. + uuid
        let name = "subscribe." + UUID().uuidString

        let v2ray = V2raySubItem(name: name, remark: remark, url: url)
        // save to v2ray UserDefaults
        v2ray.store()

        // just add to mem
        self.v2raySubList.append(v2ray)

        // update subscribe list UserDefaults
        self.saveItemList()
    }

    // remove v2ray subscribe (tmp and UserDefaults and config json file)
    static func remove(idx: Int) {
        if !V2raySubscribe.v2raySubList.indices.contains(idx) {
            NSLog("index out of range", idx)
            return
        }

        let v2ray = V2raySubscribe.v2raySubList[idx]

        // delete from tmp
        self.v2raySubList.remove(at: idx)

        // delete from v2ray UserDefaults
        V2raySubItem.remove(name: v2ray.name)

        // update subscribe list UserDefaults
        self.saveItemList()
    }

    // update subscribe list UserDefaults
    static private func saveItemList() {
        var v2raySubList: Array<String> = []
        for item in V2raySubscribe.list() {
            v2raySubList.append(item.name)
        }

        UserDefaults.setArray(forKey: .v2raySubList, value: v2raySubList)
    }

    // load json file data
    static func loadSubItem(idx: Int) -> V2raySubItem? {
        if !V2raySubscribe.v2raySubList.indices.contains(idx) {
            NSLog("index out of range", idx)
            return nil
        }

        return self.v2raySubList[idx]
    }
}

// ----- v2ray subscribe item -----
class V2raySubItem: NSObject, NSCoding {
    var name: String
    var remark: String
    var isValid: Bool
    var url: String

    // init
    required init(name: String, remark: String, url: String, isValid: Bool = true) {
        self.name = name
        self.remark = remark
        self.isValid = isValid
        self.url = url
    }

    // decode
    required init(coder decoder: NSCoder) {
        self.name = decoder.decodeObject(forKey: "Name") as? String ?? ""
        self.remark = decoder.decodeObject(forKey: "Remark") as? String ?? ""
        self.isValid = decoder.decodeBool(forKey: "IsValid")
        self.url = decoder.decodeObject(forKey: "Url") as? String ?? ""
    }

    // object encode
    func encode(with coder: NSCoder) {
        coder.encode(name, forKey: "Name")
        coder.encode(remark, forKey: "Remark")
        coder.encode(isValid, forKey: "IsValid")
        coder.encode(url, forKey: "Url")
    }

    // store into UserDefaults
    func store() {
        let modelData = NSKeyedArchiver.archivedData(withRootObject: self)
        UserDefaults.standard.set(modelData, forKey: self.name)
    }

    // static load from UserDefaults
    static func load(name: String) -> V2raySubItem? {
        guard let myModelData = UserDefaults.standard.data(forKey: name) else {
            return nil
        }
        do {
            let result = try NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(myModelData)
            return result as? V2raySubItem
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

// ----- v2ray subscribe  updater -----
let NOTIFY_UPDATE_SubSync = Notification.Name(rawValue: "NOTIFY_UPDATE_SubSync")
var inSyncSubscribe = false

class V2raySubSync: NSObject {
    var todos: Dictionary = [String: Bool]()
    let lock = NSLock()
    let semaphore = DispatchSemaphore(value: 1) // work pool

    // sync from Subscribe list
    public func sync() {
        if inSyncSubscribe {
            print("Subscribe in loading ...")
            return
        }
        print("sync from Subscribe list")
        V2raySubscribe.loadConfig()
        let list = V2raySubscribe.list()

        if list.count == 0 {
            self.logTip(title: "fail: ", uri: "", informativeText: " please add Subscription Url")
        }
        // sync queue with DispatchGroup
        let subQueue = DispatchQueue(label: "subQueue",attributes: .concurrent)
        for item in list {
            subQueue.async {
                self.todos[item.url] = true
                self.semaphore.wait()
                self.dlFromUrl(url: item.url, subscribe: item.name)
            }
        }
    }

    public func dlFromUrl(url: String, subscribe: String) {
        logTip(title: "loading from : ", uri: "", informativeText: url + "\n\n")

        guard let reqUrl = URL(string: url) else {
            logTip(title: "loading from : ", uri: "", informativeText: "url is not valid: " + url + "\n\n")
            self.refreshMenu(url: url)
            return
        }
        
        // url request with proxy
        let session = URLSession(configuration: getProxyUrlSessionConfigure())
        let task = session.dataTask(with: URLRequest(url: reqUrl)){(data: Data?, response: URLResponse?, error: Error?) in
            defer {
                self.refreshMenu(url: url)
            }
            if error != nil {
                self.logTip(title: "loading fail: ", uri: url, informativeText: "error: \(String(describing: error))")
            } else {
                if data != nil {
                    if let outputStr = String(data: data!, encoding: String.Encoding.utf8) {
                        self.handle(base64Str: outputStr, subscribe: subscribe, url: url)
                    } else {
                        self.logTip(title: "loading fail: ", uri: url, informativeText: "data is nil")
                    }
                } else {
                    self.logTip(title: "loading fail: ", uri: url, informativeText: "data is nil")
                }
            }
        }
        task.resume()
    }

    func handle(base64Str: String, subscribe: String, url: String) {
        guard let strTmp = base64Str.trimmingCharacters(in: .whitespacesAndNewlines).base64Decoded() else {
            self.logTip(title: "parse fail : ", uri: "", informativeText: base64Str)
            return
        }

        self.logTip(title: "del old from url : ", uri: "", informativeText: url + "\n\n")

        // remove old v2ray servers by subscribe
        V2rayServer.remove(subscribe: subscribe)

        if self.importByYaml(strTmp: strTmp, subscribe: subscribe) {
            return
        }
        self.importByNormal(strTmp: strTmp, subscribe: subscribe)
    }
    
    func getOld(subscribe: String) -> [String] {
        // reload all
        V2rayServer.loadConfig()
        // get old
        var oldList: [String] = []
        for (_, item) in V2rayServer.list().enumerated() {
            if item.subscribe == subscribe {
                oldList.append(item.name)
            }
        }
        return oldList
    }

    func importByYaml(strTmp: String, subscribe: String) -> Bool {
        // parse clash yaml
        do {
            let oldList = getOld(subscribe: subscribe)
            var exists: Dictionary = [String: Bool]()
            
            let decoder = YAMLDecoder()
            let decoded = try decoder.decode(Clash.self, from: strTmp)
            for item in decoded.proxies {
                if let importUri = importByClash(clash: item) {
                    importUri.remark = item.name
                    if let v2rayOld = self.saveImport(importUri: importUri, subscribe: subscribe) {
                        exists[v2rayOld.name] = true
                    }
                }
            }
                
            logTip(title: "need remove?: ", informativeText: "old=\(oldList.count) - new=\(exists.count)")

            // remove not exist
            for name in oldList {
                if !(exists[name] ?? false) {
                    // delete from v2ray UserDefaults
                    V2rayItem.remove(name: name)
                    logTip(title: "remove: ", informativeText: name)
                }
            }
            
            return true
        } catch {
            NSLog("parseYaml \(error)")
        }
        
        return false
    }
    
    func importByNormal(strTmp: String, subscribe: String)  {
        let oldList = getOld(subscribe: subscribe)
        var exists: Dictionary = [String: Bool]()
        
        let list = strTmp.trimmingCharacters(in: .newlines).components(separatedBy: CharacterSet.newlines)
        var count = 0
        for uri in list {
            count += 1
            if count > 50 {
                break // limit 50
            }
            // import every server
            if (uri.count > 0) {
                let filterUri =  uri.trimmingCharacters(in: .whitespacesAndNewlines)
                if let importUri = ImportUri.importUri(uri: filterUri,checkExist: false) {
                    if let v2rayOld = self.saveImport(importUri: importUri, subscribe: subscribe) {
                        exists[v2rayOld.name] = true
                    }
                }
            }
        }
        
        logTip(title: "need remove?: ", informativeText: "old=\(oldList.count) - new=\(exists.count)")
        
        // remove not exist
        for name in oldList {
            if !(exists[name] ?? false) {
                // delete from v2ray UserDefaults
                V2rayItem.remove(name: name)
                logTip(title: "remove: ", informativeText: name)
            }
        }
        
    }
    
    func refreshMenu(url: String)  {
        lock.lock()
        
        semaphore.signal()

        todos.removeValue(forKey: url)
        let remainCount = todos.count
        
        lock.unlock()
        
        if remainCount == 0 {
            inSyncSubscribe = false
            usleep(useconds_t(1 * second))
            do {
                // refresh server
                DispatchQueue.main.async {
                    menuController.showServers()
                }
                usleep(useconds_t(2 * second))
                // do ping
                ping.pingAll()
            }
        }
    }
    
    func saveImport(importUri: ImportUri, subscribe: String) -> V2rayItem? {
        if importUri.isValid {
            var newUri = importUri.uri
            // clash has no uri
            if newUri.count == 0 {
                // old share uri
                let v2ray = V2rayItem(name: "tmp", remark: importUri.remark, isValid: importUri.isValid, json: importUri.json, url: "", subscribe: subscribe)
                let share = ShareUri()
                share.qrcode(item: v2ray)
                newUri = share.uri
            }
            if let v2rayOld = V2rayServer.exist(url: newUri) {
                v2rayOld.json = importUri.json
                v2rayOld.isValid = importUri.isValid
                v2rayOld.remark = importUri.remark
                v2rayOld.store()
                logTip(title: "success update: ", informativeText: importUri.remark)
                return v2rayOld
            } else {
                // add server
                V2rayServer.add(remark: importUri.remark, json: importUri.json, isValid: true, url: newUri, subscribe: subscribe)
                logTip(title: "success add: ", informativeText: importUri.remark)
            }
        } else {
            logTip(title: "fail: ", informativeText: importUri.error)
        }
        return nil
    }

    func logTip(title: String = "", uri: String = "", informativeText: String = "") {
        NotificationCenter.default.post(name: NOTIFY_UPDATE_SubSync, object: title + informativeText + "\n")
        print("SubSync", title + informativeText)
        if uri != "" {
            NotificationCenter.default.post(name: NOTIFY_UPDATE_SubSync, object: "url: " + uri + "\n\n\n")
        }
    }
}

// MARK: - clash

struct Clash: Codable {
    var port, socksPort, redirPort, mixedPort: Int?
    var allowLAN: Bool?
    var mode: String
    var logLevel: String?
    var externalController: String?
    var proxies: [clashProxy]
    var rules: [String]?
}

// MARK: - Proxy
struct clashProxy: Codable {
    var type: String
    var name: String
    var server: String
    var port: Int
    var username: String? // socks5 | http
    var password: String?
    var sni: String?
    var skipCERTVerify: Bool?
    var cipher: String? // ss | ssr
    var uuid: String? // vmess | vless
    var alterId: Int? // vmess | vless
    var tls: Bool? // tls
    var fp: String?
    var `protocol`: String? // ssr
    var obfs: String? // ssr
    var udp: Bool? // socks5
    var network: String? // ws | h2
    var servername: String? // priority over wss host, REALITY servername,SNI
    var clientFingerprint: String? // vless
    var fingerprint: String? // vmess
    var security: String? // vmess
    var flow: String? // vless
    var wsOpts: clashWsOpts? // vmess
    var httpOpts: clashHttpOpts? // vmess
    var h2Opts: clashH2Opts? // vmess
    var grpcOpts: grpcOpts? // vmess
    var realityOpts: realityOpts? // vless
}

struct clashWsOpts: Codable {
    var path: String?
}

struct clashHttpOpts: Codable {
    var path: [String]?
}

struct clashH2Opts: Codable {
    var path: String?
    var host: [String]?
}

struct grpcOpts: Codable {
    var grpcServiceName: String?
}

struct realityOpts: Codable {
    var publicKey: String?
    var shortId: String?
}

/**
 - {"type":"ss","name":"v2rayse_test_1","server":"198.57.27.218","port":5004,"cipher":"aes-256-gcm","password":"g5MeD6Ft3CWlJId"}
 - {"type":"ssr","name":"v2rayse_test_3","server":"20.239.49.44","port":59814,"protocol":"origin","cipher":"dummy","obfs":"plain","password":"3df57276-03ef-45cf-bdd4-4edb6dfaa0ef"}
 - {"type":"vmess","name":"v2rayse_test_2","ws-opts":{"path":"/"},"server":"154.23.190.162","port":443,"uuid":"b9984674-f771-4e67-a198-","alterId":"0","cipher":"auto","network":"ws"}
 - {"type":"vless","name":"test","server":"1.2.3.4","port":7777,"uuid":"abc-def-ghi-fge-zsx","skip-cert-verify":true,"network":"tcp","tls":true,"udp":true}
 - {"type":"trojan","name":"v2rayse_test_4","server":"ca-trojan.bonds.id","port":443,"password":"bc7593fe-0604-4fbe--b4ab-11eb-b65e-1239d0255272","udp":true,"skip-cert-verify":true}
 - {"type":"http","name":"http_proxy","server":"124.15.12.24","port":251,"username":"username","password":"password","udp":true}
 - {"type":"socks5","name":"socks5_proxy","server":"124.15.12.24","port":2312,"udp":true}
 - {"type":"socks5","name":"telegram_proxy","server":"1.2.3.4","port":123,"username":"username","password":"password","udp":true}
 */
