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
    public func sync(useProxy: Bool = true) {
        if SubscriptionHandlering {
            logger.info("SubscriptionHandler Syncing ...")
            return
        }
        SubscriptionHandlering = true
        logger.info("SubscriptionHandler start")

        let list = SubscriptionStore.shared.fetchAll()

        if list.count == 0 {
            logTip(title: "fail: ", uri: "", informativeText: " please add Subscription Url")
        }

        // 开始执行异步任务
        syncTaskGroup(items: list, useProxy: useProxy)
    }

    func syncOne(item: SubscriptionEntity, useProxy: Bool = true) {
        if SubscriptionHandlering {
            logger.info("SubscriptionHandler Syncing ...")
            return
        }
        SubscriptionHandlering = true
        logger.info("SubscriptionHandler start syncOne")

        Task {
            defer {
                self.SubscriptionHandlering = false
                self.refreshMenu()
            }
            do {
                // 确保订阅仍然存在（防止定时器在删除后未取消导致重新插入）
                guard SubscriptionStore.shared.fetchOne(uuid: item.uuid) != nil else {
                    logger.info("syncOne: subscription \(item.uuid) has been deleted, skipping")
                    return
                }

                let result = try await self.dlFromUrl(url: item.url, sub: item, useProxy: useProxy)
                logger.info("SubscriptionHandler syncOne success")
                
                // 下载成功后只更新 updateTime / configType / 用量；不用 upsert，避免把同步期间删掉的订阅插回去 (#1668)
                SubscriptionEntity.markSynced(uuid: item.uuid, configType: result.configType, userInfo: result.userInfo)
            } catch {
                logger.info("SubscriptionHandler syncOne error: \(error)")
                logTip(title: "syncOne fail: ", uri: item.url, informativeText: error.localizedDescription)
            }
        }
    }

    private func syncTaskGroup(items: [SubscriptionEntity], useProxy: Bool = true) {
        // 使用 Combine 处理多个异步任务
        items.publisher.flatMap(maxPublishers: .max(maxConcurrentTasks)) { item in
            Future<Void, Error> { promise in
                Task {
                    do {
                        // 确保订阅仍然存在
                        guard SubscriptionStore.shared.fetchOne(uuid: item.uuid) != nil else {
                            logger.info("syncTaskGroup: subscription \(item.uuid) has been deleted, skipping")
                            promise(.success(()))
                            return
                        }

                        let result = try await self.dlFromUrl(url: item.url, sub: item, useProxy: useProxy)
                        // 下载成功后只更新 updateTime / configType / 用量；不用 upsert，避免把同步期间删掉的订阅插回去 (#1668)
                        SubscriptionEntity.markSynced(uuid: item.uuid, configType: result.configType, userInfo: result.userInfo)
                    } catch {
                        // 单个订阅失败(如过期返回 403)只记录，不能让整批中断、后面的订阅都不更新
                        logger.info("SubscriptionHandler sync \(item.remark) error: \(error)")
                        self.logTip(title: "sync fail: ", uri: item.url, informativeText: error.localizedDescription)
                    }
                    promise(.success(()))
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
            Task {
                self.onSyncComplete()
            }
        }, receiveValue: { _ in })
        .store(in: &cancellables)
    }

    /// actor-isolated 完成回调
    private func onSyncComplete() {
        SubscriptionHandlering = false
        refreshMenu()
    }

    func refreshMenu() {
        logger.info("SubscriptionHandler refreshMenu")
        SubscriptionHandlering = false
        // refresh server
        Task {
            await AppMenuManager.shared.refreshServerItems()
            await AppMenuManager.shared.updateMenuTitles()
        }
        // 仅在有节点时才触发 ping，避免在无节点时将 inPing 卡住
        let hasProfiles = !ProfileStore.shared.fetchAll().isEmpty
        if hasProfiles {
            // 使用 Task.sleep 替代 sleep() 避免阻塞 actor
            Task {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                // do ping
                await LatencyTestRunner.shared.runAll()
            }
        }
    }

    struct DownloadResult {
        /// 识别出的订阅格式 ("clash" / "normal")
        var configType: String
        /// 响应头里的流量用量, 机场没返回时为 nil
        var userInfo: SubscriptionUserInfo?
    }

    public func dlFromUrl(url: String, sub: SubscriptionEntity, useProxy: Bool = true) async throws -> DownloadResult {
        let trimmedUrl = url.trimmingCharacters(in: .whitespacesAndNewlines)
        logTip(title: "loading from : ", uri: "", informativeText: trimmedUrl + "\n\n")

        guard let reqUrl = URL(string: trimmedUrl) else {
            logTip(title: "loading from : ", uri: "", informativeText: "url is not valid: " + trimmedUrl + "\n\n")
            throw NSError(domain: "SubscriptionHandler", code: 1001, userInfo: [NSLocalizedDescriptionKey: "url is not valid: \(trimmedUrl)"])
        }

        let configuration: URLSessionConfiguration = useProxy ? getProxyUrlSessionConfigure() : .default
        let session = URLSession(configuration: configuration)
        do {
            let (data, response) = try await session.data(for: subscriptionRequest(url: reqUrl))
            // 服务器返回错误时直接报错，不把错误页当节点解析（解析不出节点会把旧节点全删掉）
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                let body = String(data: data.prefix(200), encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                logTip(title: "loading fail: ", uri: url, informativeText: "HTTP \(http.statusCode) \(body)")
                throw NSError(domain: "SubscriptionHandler", code: 1003, userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode): \(body)"])
            }
            if let outputStr = String(data: data, encoding: String.Encoding.utf8) {
                let userInfo = SubscriptionUserInfo.parse(response: response)
                if let userInfo {
                    logTip(title: "userinfo: ", informativeText: "used=\(SubscriptionUserInfo.formatBytes(userInfo.used)) total=\(SubscriptionUserInfo.formatBytes(userInfo.total)) expire=\(userInfo.expireText)")
                }
                let configType = handle(base64Str: outputStr, sub: sub, url: url)
                return DownloadResult(configType: configType, userInfo: userInfo)
            } else {
                logTip(title: "loading fail: ", uri: url, informativeText: "data is nil")
                throw NSError(domain: "SubscriptionHandler", code: 1002, userInfo: [NSLocalizedDescriptionKey: "subscription data is not valid UTF-8"])
            }
        } catch let error {
            // failed to write file – bad permissions, bad filename, missing permissions, or more likely it can't be converted to the encoding
            logger.info("save json file fail: \(error)")
            throw error
        }
    }

    func handle(base64Str: String, sub: SubscriptionEntity, url: String) -> String {
        // 下载期间订阅可能已被删除，此时不再导入节点 (#1668)
        guard SubscriptionStore.shared.fetchOne(uuid: sub.uuid) != nil else {
            logTip(title: "skip: ", uri: url, informativeText: "subscription has been deleted")
            return sub.configType
        }
        let trimmed = base64Str.trimmingCharacters(in: .whitespacesAndNewlines)

        // 如果用户手动指定了 configType，则强制使用对应解析方式
        // configType 是指定或上次识别出的格式；按它解析不出节点时（如面板改了返回格式）再按另一种试，
        // 不然会一直保留旧节点、看起来却是"更新成功"。仍返回原 configType，不改用户的选择
        if sub.configType == "clash" {
            if let strTmp = trimmed.base64Decoded() {
                if importByYaml(strTmp: strTmp, sub: sub) { return "clash" }
            }
            if importByYaml(strTmp: trimmed, sub: sub) { return "clash" }
            logTip(title: "clash parse fail: ", uri: url, informativeText: "no valid clash proxies found, try share links")
            importByNormal(strTmp: trimmed.base64Decoded() ?? trimmed, sub: sub)
            return "clash"
        }
        if sub.configType == "normal" {
            if importByNormal(strTmp: trimmed.base64Decoded() ?? trimmed, sub: sub) {
                return "normal"
            }
            if let strTmp = trimmed.base64Decoded(), importByYaml(strTmp: strTmp, sub: sub) { return "normal" }
            _ = importByYaml(strTmp: trimmed, sub: sub)
            return "normal"
        }

        // Auto mode — try base64 decode first
        if let strTmp = trimmed.base64Decoded() {
            logTip(title: "handle url: ", uri: "", informativeText: url + "\n\n")
            if importByYaml(strTmp: strTmp, sub: sub) {
                return "clash"
            }
            importByNormal(strTmp: strTmp, sub: sub)
            return "normal"
        }

        // Not valid base64 — try parsing as plain text directly
        logTip(title: "not base64, try direct parse: ", uri: "", informativeText: url + "\n\n")
        if importByYaml(strTmp: trimmed, sub: sub) {
            return "clash"
        }
        importByNormal(strTmp: trimmed, sub: sub)
        return "normal"
    }

    func getOldCount(sub: SubscriptionEntity) -> Int {
        return ProfileStore.shared.count(filter: [ProfileEntity.Columns.subid.name: sub.uuid])
    }

    func importByYaml(strTmp: String, sub: SubscriptionEntity) -> Bool {
        var list: [ProfileEntity] = []

        // parse clash yaml
        do {
            let decoder = YAMLDecoder()
            let decoded = try decoder.decode(Clash.self, from: strTmp)
            if decoded.proxies.isEmpty {
                return false
            }
            for clash in decoded.proxies {
                if var item = clash.toProfile() {
                    item.subid = sub.uuid
                    list.append(item)
                }
            }

            if list.isEmpty {
                return false
            }

            logTip(title: "importByYaml: ", informativeText: "old=\(getOldCount(sub: sub)) - new=\(list.count)")
            applyProfiles(list, sub: sub)
            return true
        } catch {
            logger.info("parseYaml \(error)")
        }

        return false
    }

    /// - Returns: 是否解析出了节点
    @discardableResult
    func importByNormal(strTmp: String, sub: SubscriptionEntity) -> Bool {
        var list: [ProfileEntity] = []
        
        // 文本按行拆分
        let lines = strTmp.trimmingCharacters(in: .newlines).components(separatedBy: CharacterSet.newlines)
        for (i, uri) in lines.enumerated() {
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
                logTip(title: "line \(i) importByNormal fail ", uri: uri, informativeText: "line \(i) import uri fail: " + importTask.error)
            }
        }

        // 一个节点都没解析出来（多半是服务器返回了错误内容），保留旧节点
        guard !list.isEmpty else {
            logTip(title: "importByNormal: ", informativeText: "\(sub.remark), \(sub.url) no valid profile, keep old profiles")
            return false
        }
        applyProfiles(list, sub: sub)
        return true
    }

    /// 按新旧节点对比更新订阅下的节点：保留旧节点的 uuid 和测速、流量等数据
    private func applyProfiles(_ list: [ProfileEntity], sub: SubscriptionEntity) {
        let olds = ProfileStore.shared.getGroupProfiles(subid: sub.uuid)

        // 先按完整分享链接对比
        var oldMap = [String: ProfileEntity]()
        for item in olds {
            oldMap[item.uniqueKey()] = item
        }

        var matched = [(old: ProfileEntity, new: ProfileEntity)]()
        var pending = [ProfileEntity]()
        var usedOld = Set<String>()
        var seenKeys = Set<String>()

        for item in list {
            let key = item.uniqueKey()
            // 跳过同一批次中重复的 key（订阅内容里相同的 URI 可能出现多次）
            guard seenKeys.insert(key).inserted else {
                logTip(title: "skip duplicate: ", informativeText: "\(item.remark), \(item.address):\(item.port)")
                continue
            }
            if let old = oldMap[key], !usedOld.contains(old.uuid) {
                usedOld.insert(old.uuid)
                matched.append((old, item))
            } else {
                pending.append(item)
            }
        }

        // 分享链接对不上时再按服务器本身对比：备注里常带剩余流量等每次都变的内容，
        // 只按链接对比会删旧建新、uuid 改变，正在使用的节点就丢了 (#1669)
        var oldByServer = [String: [ProfileEntity]]()
        for item in olds where !usedOld.contains(item.uuid) {
            oldByServer[item.serverKey(), default: []].append(item)
        }
        var adds = [ProfileEntity]()
        for item in pending {
            if var candidates = oldByServer[item.serverKey()], !candidates.isEmpty {
                let old = candidates.removeFirst()
                oldByServer[item.serverKey()] = candidates
                usedOld.insert(old.uuid)
                matched.append((old, item))
            } else {
                adds.append(item)
            }
        }
        let dels = olds.filter { !usedOld.contains($0.uuid) }

        for (old, item) in matched {
            ProfileStore.shared.updateProfile(oldDto: old, newDto: item)
        }
        if !adds.isEmpty {
            ProfileStore.shared.insertMany(adds)
        }
        for del in dels {
            logTip(title: "delete old profile: ", informativeText: "\(sub.remark) - \(del.remark), \(del.address):\(del.port)")
        }
        if !dels.isEmpty {
            let uuids = dels.map(\.uuid)
            ProfileStore.shared.delete(uuids: uuids)
            Task { @MainActor in
                CombinedConfigStore.removeProfiles(uuids: Set(uuids))
            }
        }

        logTip(title: "import: ", informativeText: "\(sub.remark), \(sub.url) added=\(adds.count), deleted=\(dels.count), exists=\(matched.count)")
    }

    func logTip(title: String = "", uri: String = "", informativeText: String = "") {
        NotificationCenter.default.post(name: NOTIFY_UPDATE_SubSync, object: title + informativeText + "\n")
        logger.info("SubSync: \(title + informativeText)")
        if uri != "" {
            NotificationCenter.default.post(name: NOTIFY_UPDATE_SubSync, object: "url: " + uri + "\n\n\n")
        }
    }
}

