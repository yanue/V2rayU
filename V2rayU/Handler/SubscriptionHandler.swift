import Cocoa
import Yams

// ----- v2ray subscribe  updater -----
let NOTIFY_UPDATE_SubSync = Notification.Name(rawValue: "NOTIFY_UPDATE_SubSync")

class V2raySubSync: NSObject {
    var V2raySubSyncing = false
    let maxConcurrentTasks = 1 // work pool

    static var shared = V2raySubSync()
    // Initialization
    override init() {
        super.init()
        NSLog("V2raySubSync init")
    }

    // sync from Subscription list
    public func sync() {
        if V2raySubSyncing {
            NSLog("V2raySubSync Syncing ...")
            return
        }
        self.V2raySubSyncing = true
        NSLog("V2raySubSync start")

        let list = V2raySubscription.list()

        if list.count == 0 {
            self.logTip(title: "fail: ", uri: "", informativeText: " please add Subscription Url")
        }
        // sync queue with DispatchGroup
        Task {
            do {
                try await self.syncTaskGroup(items: list)
            } catch let error {
                NSLog("pingTaskGroup error: \(error)")
            }
        }
    }

    func syncTaskGroup(items: [V2raySubItem]) async throws {
        let taskChunks = stride(from: 0, to: items.count, by: maxConcurrentTasks).map {
            Array(items[$0..<min($0 + maxConcurrentTasks, items.count)])
        }
        NSLog("syncTaskGroup-start: taskChunks=\(taskChunks.count)")
        for (i, chunk) in taskChunks.enumerated() {
            NSLog("syncTaskGroup-start-\(i): count=\(chunk.count)")
            try await withThrowingTaskGroup(of: Void.self) { group in
                for item in chunk {
                    group.addTask {
                        do {
                            try await self.dlFromUrl(url: item.url, subscribe: item.name)
                        } catch {
                            NSLog("dlFromUrl error: \(error)")
                        }
                        return
                    }
                }
                // 等待当前批次所有任务完成
                try await group.waitForAll()
            }
            NSLog("syncTaskGroup-end-\(i)")
        }
        NSLog("syncTaskGroup-end")
        self.refreshMenu()
    }

    func refreshMenu()  {
        NSLog("V2raySubSync refreshMenu")
        self.V2raySubSyncing = false
        usleep(useconds_t(1 * second))
        do {
            // refresh server
            menuController.showServers()
            // sleep 2
            sleep(2)
            // do ping
            ping.pingAll()
        }
    }

    public func dlFromUrl(url: String, subscribe: String) async throws {
        logTip(title: "loading from : ", uri: "", informativeText: url + "\n\n")

        guard let reqUrl = URL(string: url) else {
            logTip(title: "loading from : ", uri: "", informativeText: "url is not valid: " + url + "\n\n")
            return
        }

        // url request with proxy
        let session = URLSession(configuration: getProxyUrlSessionConfigure())
        do {
            let (data, _) = try await session.data(for: URLRequest(url: reqUrl))
            if let outputStr = String(data: data, encoding: String.Encoding.utf8) {
                self.handle(base64Str: outputStr, subscribe: subscribe, url: url)
            } else {
                self.logTip(title: "loading fail: ", uri: url, informativeText: "data is nil")
            }
        } catch let error {
            // failed to write file – bad permissions, bad filename, missing permissions, or more likely it can't be converted to the encoding
            NSLog("save json file fail: \(error)")
        }
    }

    func handle(base64Str: String, subscribe: String, url: String) {
        guard let strTmp = base64Str.trimmingCharacters(in: .whitespacesAndNewlines).base64Decoded() else {
            self.logTip(title: "parse fail : ", uri: "", informativeText: base64Str)
            return
        }

        self.logTip(title: "handle url: ", uri: "", informativeText: url + "\n\n")

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

            print("\(importUri.remark) - \(newUri)")

            if let v2rayOld = V2rayServer.existItem(url: newUri) {
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
