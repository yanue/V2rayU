import Cocoa
import Combine
import Yams

// ----- v2ray subscribe  updater -----
let NOTIFY_UPDATE_SubSync = Notification.Name(rawValue: "NOTIFY_UPDATE_SubSync")

actor SubscriptionHandler {
    static var shared = SubscriptionHandler()
    
    private var SubscriptionHandlering = false
    private let maxConcurrentTasks = 1 // work pool
    private var cancellables = Set<AnyCancellable>()
    
    // sync from Subscription list
    public func sync() {
        if SubscriptionHandlering {
            NSLog("SubscriptionHandler Syncing ...")
            return
        }
        SubscriptionHandlering = true
        NSLog("SubscriptionHandler start")

        let list = SubViewModel.all()

        if list.count == 0 {
            logTip(title: "fail: ", uri: "", informativeText: " please add Subscription Url")
        }
        
        // 开始执行异步任务
        syncTaskGroup(items: list)
    }

    private func syncTaskGroup(items: [SubModel]) {
        // 使用 Combine 处理多个异步任务
        items.publisher.flatMap(maxPublishers: .max(self.maxConcurrentTasks)) { item in
            Future<Void, Error> { promise in
                Task {
                    do {
                        try await self.dlFromUrl(url: item.url, sub: item)
                        promise(.success(()))
                    } catch {
                        promise(.failure(error))
                    }
                }
            }
        }
        .collect()
        .sink(receiveCompletion: { completion in
            switch completion {
            case .finished:
                NSLog("All tasks completed")
            case let .failure(error):
                NSLog("Error: \(error)")
            }
            self.SubscriptionHandlering = false
            self.refreshMenu()
        }, receiveValue: { _ in })
        .store(in: &cancellables)
    }

    func refreshMenu() {
        NSLog("SubscriptionHandler refreshMenu")
        self.SubscriptionHandlering = false
        do {
            // refresh server
//            menuController.showServers()
            // sleep 2
            sleep(2)
            // do ping
            Task {
                await PingAll.shared.run()
            }
        }
    }

    public func dlFromUrl(url: String, sub: SubModel) async throws {
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
                handle(base64Str: outputStr, sub: sub, url: url)
            } else {
                logTip(title: "loading fail: ", uri: url, informativeText: "data is nil")
            }
        } catch let error {
            // failed to write file – bad permissions, bad filename, missing permissions, or more likely it can't be converted to the encoding
            NSLog("save json file fail: \(error)")
        }
    }

    func handle(base64Str: String, sub: SubModel, url: String) {
        guard let strTmp = base64Str.trimmingCharacters(in: .whitespacesAndNewlines).base64Decoded() else {
            logTip(title: "parse fail : ", uri: "", informativeText: base64Str)
            return
        }

        logTip(title: "handle url: ", uri: "", informativeText: url + "\n\n")

        if importByYaml(strTmp: strTmp, sub: sub) {
            return
        }
        importByNormal(strTmp: strTmp, sub: sub)
    }

    func getOldCount(sub: SubModel) -> Int {
        // reload all
        return ProfileViewModel.count(filter: [ProfileModel.Columns.subid.name: sub.uuid])
    }

    func importByYaml(strTmp: String, sub: SubModel) -> Bool {
        var list: [ProfileModel] = []
        let oldCount = getOldCount(sub: sub)

        // parse clash yaml
        do {
            let decoder = YAMLDecoder()
            let decoded = try decoder.decode(Clash.self, from: strTmp)
            if decoded.proxies.isEmpty {
                return false
            }
            for clash in decoded.proxies {
                if let item = clash.toProfile() {
                    list.append(item)
                }
            }

            logTip(title: "importByYaml: ", informativeText: "old=\(oldCount) - new=\(list.count)")

            if list.isEmpty {
                return false
            }
            // 删除旧的
            ProfileViewModel.delete(filter: [ProfileModel.Columns.subid.name: sub.uuid])

            // 插入新的
            ProfileViewModel.insert_many(items: list)

            return true
        } catch {
            NSLog("parseYaml \(error)")
        }

        return false
    }

    func importByNormal(strTmp: String, sub: SubModel) {
        var list: [ProfileModel] = []
        let oldCount = getOldCount(sub: sub)

        let lines = strTmp.trimmingCharacters(in: .newlines).components(separatedBy: CharacterSet.newlines)
        var count = 0
        for uri in lines {
            let filterUri = uri.trimmingCharacters(in: .whitespacesAndNewlines)
            // import every server
            if filterUri.count == 0 {
                continue
            }
            let importTask = ImportUri(share_uri: filterUri)
            if let profile = importTask.doImport() {
                profile.subid = sub.uuid
                list.append(profile)
            } else {
                logTip()
            }
        }

        logTip(title: "importByNormal: ", informativeText: "old=\(oldCount) - new=\(list.count)")

        // 删除旧的
        ProfileViewModel.delete(filter: [ProfileModel.Columns.subid.name: sub.uuid])

        // 插入新的
        ProfileViewModel.insert_many(items: list)
    }

    func logTip(title: String = "", uri: String = "", informativeText: String = "") {
        NotificationCenter.default.post(name: NOTIFY_UPDATE_SubSync, object: title + informativeText + "\n")
        print("SubSync", title + informativeText)
        if uri != "" {
            NotificationCenter.default.post(name: NOTIFY_UPDATE_SubSync, object: "url: " + uri + "\n\n\n")
        }
    }
}
