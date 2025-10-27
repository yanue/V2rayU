import Cocoa
import Combine
import Yams

// ----- v2ray subscribe  updater -----
let NOTIFY_UPDATE_SubSync = Notification.Name(rawValue: "NOTIFY_UPDATE_SubSync")

actor SubscriptionHandler {
    static let shared = SubscriptionHandler()

    private var SubscriptionHandlering = false
    private let maxConcurrentTasks = 1 // work pool
    private var cancellables = Set<AnyCancellable>()

    // sync from Subscription list
    public func sync() {
        if SubscriptionHandlering {
            logger.info("SubscriptionHandler Syncing ...")
            return
        }
        SubscriptionHandlering = true
        logger.info("SubscriptionHandler start")

        let list = SubViewModel().all()

        if list.count == 0 {
            logTip(title: "fail: ", uri: "", informativeText: " please add Subscription Url")
        }

        // 开始执行异步任务
        syncTaskGroup(items: list)
    }

    func syncOne(item: SubDTO) {
        if SubscriptionHandlering {
            logger.info("SubscriptionHandler Syncing ...")
            return
        }
        SubscriptionHandlering = true
        logger.info("SubscriptionHandler start syncOne")
        Task {
            do {
                try await self.dlFromUrl(url: item.url, sub: item)
                logger.info("SubscriptionHandler syncOne success")
            } catch {
                logger.info("SubscriptionHandler syncOne error: \(error)")
                logTip(title: "syncOne fail: ", uri: item.url, informativeText: error.localizedDescription)
            }
        }
    }

    private func syncTaskGroup(items: [SubDTO]) {
        // 使用 Combine 处理多个异步任务
        items.publisher.flatMap(maxPublishers: .max(maxConcurrentTasks)) { item in
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
                logger.info("All tasks completed")
            case let .failure(error):
                logger.info("Error: \(error)")
            }
            self.SubscriptionHandlering = false
            self.refreshMenu()
        }, receiveValue: { _ in })
        .store(in: &cancellables)
    }

    func refreshMenu() {
        logger.info("SubscriptionHandler refreshMenu")
        SubscriptionHandlering = false
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

    public func dlFromUrl(url: String, sub: SubDTO) async throws {
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
            logger.info("save json file fail: \(error)")
        }
    }

    func handle(base64Str: String, sub: SubDTO, url: String) {
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

    func getOldCount(sub: SubDTO) -> Int {
        return ProfileViewModel.count(filter: [ProfileDTO.Columns.subid.name: sub.uuid])
    }

    func importByYaml(strTmp: String, sub: SubDTO) -> Bool {
        var list: [ProfileDTO] = []
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
            ProfileViewModel.delete(filter: [ProfileDTO.Columns.subid.name: sub.uuid])

            // 插入新的
            ProfileViewModel.insert_many(items: list)

            return true
        } catch {
            logger.info("parseYaml \(error)")
        }

        return false
    }

    func importByNormal(strTmp: String, sub: SubDTO) {
        var list: [ProfileDTO] = []
        
        // 文本按行拆分
        let lines = strTmp.trimmingCharacters(in: .newlines).components(separatedBy: CharacterSet.newlines)
        for uri in lines {
            let filterUri = uri.trimmingCharacters(in: .whitespacesAndNewlines)
            // import every server
            if filterUri.count == 0 {
                continue
            }
            let importTask = ImportUri(share_uri: filterUri)
            if var profile = importTask.doImport() {
                profile.subid = sub.uuid
                list.append(profile)
            } else {
                logTip()
            }
        }

        // 查询旧的
        let olds = ProfileViewModel.getGroupProfiles(subid: sub.uuid)

        // 组合旧的 unique key 集合
        var oldMap = [String: ProfileDTO]()
        for item in olds {
            let key = item.uniqueKey()
            oldMap[key] = item
        }

        var adds = [ProfileDTO]()
        var dels = [ProfileDTO]()
        var exists = Set<String>()

        // 遍历新的列表
        for item in list {
            let key = item.uniqueKey()
            if let old = oldMap[key] {
                exists.insert(key)
                // 更新旧的
                ProfileViewModel.update_profile(oldDto:  old, newDto: item)
                logTip(title: "update existing profile: ", informativeText: "\(sub.remark), \(item.remark), \(item.address):\(item.port)")
            } else {
                // 新增
                logTip(title: "add new profile: ", informativeText: "\(sub.remark), \(item.remark), \(item.address):\(item.port)")
                adds.append(item)
            }
        }

        // 找出需要删除的（旧的但不在新的里）
        for (key, item) in oldMap {
            if !exists.contains(key) {
                logTip(title: "delete old profile: ", informativeText: "\(sub.remark), \(sub.url) - \(item.remark), \(item.address):\(item.port)")
                dels.append(item)
            }
        }

        // 插入新的
        if !adds.isEmpty {
            ProfileViewModel.insert_many(items: adds)
        }
        
        // 删除旧的
        for del in dels {
            ProfileViewModel.delete(uuid: del.uuid)
        }
        
        logTip(title: "importByNormal: ", informativeText: "\(sub.remark), \(sub.url) added=\(adds.count), deleted=\(dels.count), exists=\(exists.count)")
    }

    func logTip(title: String = "", uri: String = "", informativeText: String = "") {
        NotificationCenter.default.post(name: NOTIFY_UPDATE_SubSync, object: title + informativeText + "\n")
        logger.info("SubSync: \(title + informativeText)")
        if uri != "" {
            NotificationCenter.default.post(name: NOTIFY_UPDATE_SubSync, object: "url: " + uri + "\n\n\n")
        }
    }
}
