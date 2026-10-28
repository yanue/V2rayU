//
//  LegacyMigrationHandler.swift
//  V2rayU
//
//  Created by yanue on 2025/1/1.
//  Copyright © 2025 yanue. All rights reserved.
//
//  本文件用于从 V2rayU v4 版本（UserDefaults 存储）迁移数据到 v5 版本（SQLite 存储）
//  v4 版本使用 NSKeyedArchiver 存储 V2rayItem 和 V2raySubItem 对象
//

import AppKit
import CryptoKit
import GRDB

// MARK: - 旧版数据模型

/// v4 版本的服务器配置对象
/// 对应 UserDefaults 中 key 为 "config.xxx" 的数据
class LegacyV2rayItem: NSObject, NSCoding {
    var name: String = ""           // 配置名称，格式为 "config." + UUID
    var remark: String = ""        // 服务器备注/名称
    var json: String = ""          // V2ray JSON 配置
    var isValid: Bool = false      // 配置是否有效
    var url: String = ""           // 分享链接 URI
    var subscribe: String = ""    // 所属订阅，格式为 "subscribe." + UUID
    var speed: String = ""         // 延迟速度，格式为 "XXXms"

    required override init() {
        super.init()
    }

    required init(coder decoder: NSCoder) {
        // 尝试多种可能的大小写和命名方式
        self.name = decoder.decodeObject(forKey: "Name") as? String ?? decoder.decodeObject(forKey: "name") as? String ?? ""
        self.remark = decoder.decodeObject(forKey: "Remark") as? String ?? decoder.decodeObject(forKey: "remark") as? String ?? ""
        self.json = decoder.decodeObject(forKey: "Json") as? String ?? decoder.decodeObject(forKey: "json") as? String ?? decoder.decodeObject(forKey: "JSON") as? String ?? ""
        self.isValid = decoder.decodeBool(forKey: "IsValid") || decoder.decodeBool(forKey: "isValid")
        self.url = decoder.decodeObject(forKey: "Url") as? String ?? decoder.decodeObject(forKey: "url") as? String ?? decoder.decodeObject(forKey: "URL") as? String ?? ""
        self.subscribe = decoder.decodeObject(forKey: "Subscribe") as? String ?? decoder.decodeObject(forKey: "subscribe") as? String ?? ""
        self.speed = decoder.decodeObject(forKey: "Speed") as? String ?? decoder.decodeObject(forKey: "speed") as? String ?? ""
    }

    func encode(with coder: NSCoder) {
        coder.encode(name, forKey: "Name")
        coder.encode(remark, forKey: "Remark")
        coder.encode(json, forKey: "Json")
        coder.encode(isValid, forKey: "IsValid")
        coder.encode(url, forKey: "Url")
        coder.encode(subscribe, forKey: "Subscribe")
        coder.encode(speed, forKey: "Speed")
    }

    /// 从 UserDefaults 加载指定名称的配置
    /// - Parameters:
    ///   - name: 配置的完整名称（包括 "config." 前缀）
    ///   - defaults: UserDefaults 实例
    /// - Returns: 解析后的 V2rayItem 对象，失败返回 nil
    static func load(name: String, defaults: UserDefaults) -> LegacyV2rayItem? {
        // 从 UserDefaults 获取编码后的数据
        guard let myModelData = defaults.data(forKey: name) else {
            logger.debug("LegacyV2rayItem.load: No data for key '\(name)'")
            return nil
        }

        do {
            // 创建解档器
            let unarchiver = try NSKeyedUnarchiver(forReadingFrom: myModelData)
            unarchiver.requiresSecureCoding = false

            // 注册类名映射，解决 v4 和 v5 类名不同的问题
            // v4 版本可能使用不同的 bundle id 或类名
            unarchiver.setClass(LegacyV2rayItem.self, forClassName: "V2rayU.V2rayItem")
            unarchiver.setClass(LegacyV2rayItem.self, forClassName: "V2rayItem")
            unarchiver.setClass(LegacyV2rayItem.self, forClassName: "yanue.V2rayU.V2rayItem")
            unarchiver.setClass(NSString.self, forClassName: "NSString")

            // 解档根对象
            let result = unarchiver.decodeObject(forKey: NSKeyedArchiveRootObjectKey)
            logger.debug("LegacyV2rayItem.load: Successfully loaded '\(name)', result type: \(String(describing: type(of: result)))")

            // 调试：检查解档结果的所有属性
            if let item = result as? LegacyV2rayItem {
                logger.debug("LegacyV2rayItem.load: decoded - name='\(item.name)', remark='\(item.remark)', url='\(item.url.count > 30 ? String(item.url.prefix(30)) + "..." : item.url)', json.count=\(item.json.count), subscribe='\(item.subscribe)', speed='\(item.speed)', isValid=\(item.isValid)")
                return item
            } else {
                // 尝试直接解码所有属性
                logger.debug("LegacyV2rayItem.load: result is nil or not LegacyV2rayItem, trying direct decode")
                let directName = unarchiver.decodeObject(forKey: "Name") as? String ?? ""
                let directRemark = unarchiver.decodeObject(forKey: "Remark") as? String ?? ""
                let directUrl = unarchiver.decodeObject(forKey: "Url") as? String ?? ""
                let directJson = unarchiver.decodeObject(forKey: "Json") as? String ?? ""
                let directSubscribe = unarchiver.decodeObject(forKey: "Subscribe") as? String ?? ""
                let directSpeed = unarchiver.decodeObject(forKey: "Speed") as? String ?? ""
                let directIsValid = unarchiver.decodeBool(forKey: "IsValid")
                logger.debug("LegacyV2rayItem.load: direct - name='\(directName)', remark='\(directRemark)', url='\(directUrl.count > 30 ? String(directUrl.prefix(30)) + "..." : directUrl)', json='\(directJson.prefix(50))...', subscribe='\(directSubscribe)', speed='\(directSpeed)', isValid=\(directIsValid)")

                // 手动创建 LegacyV2rayItem 并填充数据
                let item = LegacyV2rayItem()
                item.name = directName
                item.remark = directRemark
                item.url = directUrl
                item.json = directJson
                item.subscribe = directSubscribe
                item.speed = directSpeed
                item.isValid = directIsValid
                logger.debug("LegacyV2rayItem.load: manually created item")
                return item
            }
        } catch {
            logger.error("LegacyV2rayItem.load: Failed to load '\(name)': \(error)")
            return nil
        }
    }
}

/// v4 版本的订阅配置对象
/// 对应 UserDefaults 中 key 为 "subscribe.xxx" 的数据
class LegacyV2raySubItem: NSObject, NSCoding {
    var name: String = ""       // 订阅名称，格式为 "subscribe." + UUID
    var remark: String = ""    // 订阅备注
    var isValid: Bool = true   // 订阅是否有效
    var url: String = ""      // 订阅 URL

    required override init() {
        super.init()
    }

    required init(coder decoder: NSCoder) {
        self.name = decoder.decodeObject(forKey: "Name") as? String ?? decoder.decodeObject(forKey: "name") as? String ?? ""
        self.remark = decoder.decodeObject(forKey: "Remark") as? String ?? decoder.decodeObject(forKey: "remark") as? String ?? ""
        self.isValid = decoder.decodeBool(forKey: "IsValid") || decoder.decodeBool(forKey: "isValid")
        self.url = decoder.decodeObject(forKey: "Url") as? String ?? decoder.decodeObject(forKey: "url") as? String ?? decoder.decodeObject(forKey: "URL") as? String ?? ""
    }

    func encode(with coder: NSCoder) {
        coder.encode(name, forKey: "Name")
        coder.encode(remark, forKey: "Remark")
        coder.encode(isValid, forKey: "IsValid")
        coder.encode(url, forKey: "Url")
    }

    /// 从 UserDefaults 加载指定名称的订阅
    /// - Parameters:
    ///   - name: 订阅的完整名称（包括 "subscribe." 前缀）
    ///   - defaults: UserDefaults 实例
    /// - Returns: 解析后的 V2raySubItem 对象，失败返回 nil
    static func load(name: String, defaults: UserDefaults) -> LegacyV2raySubItem? {
        // 从 UserDefaults 获取编码后的数据
        guard let myModelData = defaults.data(forKey: name) else {
            logger.debug("LegacyV2raySubItem.load: No data for key '\(name)'")
            return nil
        }

        do {
            // 创建解档器
            let unarchiver = try NSKeyedUnarchiver(forReadingFrom: myModelData)
            unarchiver.requiresSecureCoding = false

            // 注册类名映射
            unarchiver.setClass(LegacyV2raySubItem.self, forClassName: "V2rayU.V2raySubItem")
            unarchiver.setClass(LegacyV2raySubItem.self, forClassName: "V2raySubItem")
            unarchiver.setClass(LegacyV2raySubItem.self, forClassName: "yanue.V2rayU.V2raySubItem")
            unarchiver.setClass(NSString.self, forClassName: "NSString")

            // 解档根对象
            let result = unarchiver.decodeObject(forKey: NSKeyedArchiveRootObjectKey)
            logger.debug("LegacyV2raySubItem.load: Successfully loaded '\(name)', result type: \(String(describing: type(of: result)))")

            if let item = result as? LegacyV2raySubItem {
                logger.debug("LegacyV2raySubItem.load: decoded - name='\(item.name)', remark='\(item.remark)', url='\(item.url.prefix(30))...', isValid=\(item.isValid)")
                return item
            } else {
                // 尝试直接解码
                logger.debug("LegacyV2raySubItem.load: result is nil or not LegacyV2raySubItem, trying direct decode")
                let directName = unarchiver.decodeObject(forKey: "Name") as? String ?? ""
                let directRemark = unarchiver.decodeObject(forKey: "Remark") as? String ?? ""
                let directUrl = unarchiver.decodeObject(forKey: "Url") as? String ?? ""
                let directIsValid = unarchiver.decodeBool(forKey: "IsValid")
                logger.debug("LegacyV2raySubItem.load: direct - name='\(directName)', remark='\(directRemark)', url='\(directUrl.prefix(30))...', isValid=\(directIsValid)")

                let item = LegacyV2raySubItem()
                item.name = directName
                item.remark = directRemark
                item.url = directUrl
                item.isValid = directIsValid
                return item
            }
        } catch {
            logger.error("LegacyV2raySubItem.load: Failed to load '\(name)': \(error)")
            return nil
        }
    }
}

/// 对应 UserDefaults 中 key 为 "routing.xxx" 的数据 (v4 RoutingItem)
/// - 内置路由(routing.global / routing.lan / routing.cn / routing.lanAndCn): 用户可编辑 block / proxy / direct 列表
/// - 自定义路由(routing.<UUID>): 规则写在 json 里(xray 路由格式)
class LegacyRoutingItem: NSObject, NSCoding {
    var name: String = ""
    var remark: String = ""
    var json: String = ""
    var domainStrategy: String = "AsIs"
    var block: String = ""
    var proxy: String = ""
    var direct: String = ""

    required override init() {
        super.init()
    }

    required init(coder decoder: NSCoder) {
        self.name = decoder.decodeObject(forKey: "Name") as? String ?? ""
        self.remark = decoder.decodeObject(forKey: "Remark") as? String ?? ""
        self.json = decoder.decodeObject(forKey: "Json") as? String ?? ""
        self.domainStrategy = decoder.decodeObject(forKey: "DomainStrategy") as? String ?? "AsIs"
        self.block = decoder.decodeObject(forKey: "Block") as? String ?? ""
        self.proxy = decoder.decodeObject(forKey: "Proxy") as? String ?? ""
        self.direct = decoder.decodeObject(forKey: "Direct") as? String ?? ""
    }

    func encode(with coder: NSCoder) {
        coder.encode(name, forKey: "Name")
        coder.encode(remark, forKey: "Remark")
        coder.encode(json, forKey: "Json")
        coder.encode(domainStrategy, forKey: "DomainStrategy")
        coder.encode(block, forKey: "Block")
        coder.encode(proxy, forKey: "Proxy")
        coder.encode(direct, forKey: "Direct")
    }

    static func load(name: String, defaults: UserDefaults) -> LegacyRoutingItem? {
        guard let data = defaults.data(forKey: name) else { return nil }
        do {
            let unarchiver = try NSKeyedUnarchiver(forReadingFrom: data)
            unarchiver.requiresSecureCoding = false
            unarchiver.setClass(LegacyRoutingItem.self, forClassName: "V2rayU.RoutingItem")
            unarchiver.setClass(LegacyRoutingItem.self, forClassName: "RoutingItem")
            let item = unarchiver.decodeObject(forKey: NSKeyedArchiveRootObjectKey) as? LegacyRoutingItem
            unarchiver.finishDecoding()
            return item
        } catch {
            logger.error("LegacyRoutingItem.load: Failed to load '\(name)': \(error)")
            return nil
        }
    }

    static let builtinNames: Set<String> = [RoutingRuleGlobal, RoutingRuleLAN, RoutingRuleCn, RoutingRuleLANAndCn]

    /// 转成 v5 路由 (v5 只有 block / proxy / direct 三个列表)
    /// - 自定义路由: json 里每条规则按 outboundTag 把 domain / ip 拆进对应列表;
    ///   带端口、网络、入站等其他匹配条件的规则无法表示, 跳过(只取 domain/ip 会扩大匹配范围, 改变分流结果)
    /// - 内置路由: 用户没改过(三个列表都为空)时返回 nil, 由 v5 自带的内置路由覆盖;
    ///   改过时生成一条同名(保留内置行为)的新路由, 列表 = v5 内置默认 + 用户添加, 不改动 v5 已有的内置路由
    /// - Returns: (路由, 跳过的规则数); 没有可迁移的内容时返回 nil
    func toEntity(uuid: String, defaultRules: [String: RoutingEntity]) -> (entity: RoutingEntity, skippedRules: Int)? {
        var block = Self.lines(block)
        var proxy = Self.lines(proxy)
        var direct = Self.lines(direct)
        var strategy = domainStrategy
        var skipped = 0

        if let data = json.data(using: .utf8),
           let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let s = root["domainStrategy"] as? String, !s.isEmpty {
                strategy = s
            }
            let allowedKeys: Set<String> = ["type", "domain", "ip", "outboundTag"]
            for rule in root["rules"] as? [[String: Any]] ?? [] {
                let tag = rule["outboundTag"] as? String ?? ""
                let values = (rule["domain"] as? [String] ?? []) + (rule["ip"] as? [String] ?? [])
                guard ["block", "proxy", "direct"].contains(tag), !values.isEmpty,
                      Set(rule.keys).isSubset(of: allowedKeys) else {
                    skipped += 1
                    continue
                }
                switch tag {
                case "block": block += values
                case "proxy": proxy += values
                default: direct += values
                }
            }
        }

        if V2rayRouting.domainStrategy(rawValue: strategy) == nil {
            strategy = "AsIs"
        }

        let isBuiltin = Self.builtinNames.contains(name)
        if isBuiltin {
            guard !(block.isEmpty && proxy.isEmpty && direct.isEmpty), let base = defaultRules[name] else { return nil }
            block = Self.lines(base.block) + block
            proxy = Self.lines(base.proxy) + proxy
            direct = Self.lines(base.direct) + direct
            if strategy == "AsIs" {
                strategy = base.domainStrategy
            }
        } else if block.isEmpty && proxy.isEmpty && direct.isEmpty {
            return nil
        }

        let builtinRemark = (isMainland ? defaultRuleCn[name] : defaultRuleEn[name]) ?? ""
        let baseRemark = remark.isEmpty ? (builtinRemark.isEmpty ? name : builtinRemark) : remark
        let entity = RoutingEntity(
            uuid: uuid,
            name: isBuiltin ? name : (name.isEmpty ? "routing.\(uuid)" : name),
            remark: isBuiltin ? "\(baseRemark) (v4)" : baseRemark,
            domainStrategy: strategy,
            block: Self.unique(block).joined(separator: "\n"),
            proxy: Self.unique(proxy).joined(separator: "\n"),
            direct: Self.unique(direct).joined(separator: "\n")
        )
        return (entity, skipped)
    }

    private static func lines(_ text: String) -> [String] {
        text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private static func unique(_ items: [String]) -> [String] {
        var seen = Set<String>()
        return items.filter { seen.insert($0).inserted }
    }

    /// v4 路由在 v5 中的 uuid: 自定义路由沿用 "routing.<UUID>" 里的 UUID; 其他(内置)按名称生成固定 uuid, 重复迁移不会重复插入
    static func migratedUuid(for name: String) -> String {
        if name.hasPrefix("routing."), UUID(uuidString: String(name.dropFirst("routing.".count))) != nil {
            return String(name.dropFirst("routing.".count))
        }
        let digest = Array(Insecure.MD5.hash(data: Data("v2rayu-v4-\(name)".utf8)))
        return NSUUID(uuidBytes: digest).uuidString
    }
}

// MARK: - 迁移结果枚举

/// 迁移操作的结果
enum LegacyMigrationResult {
    case success(profiles: Int, subscriptions: Int, routings: Int)  // 迁移成功
    case noData                                          // 没有旧数据
    case error(String)                                   // 迁移失败
}

// MARK: - 迁移处理器

/// 异步迁移处理器，负责从 v4 版本迁移数据到 v5 版本
actor LegacyMigrationHandler {

    /// 单例实例
    static let shared = LegacyMigrationHandler()

    /// 标记是否已完成迁移的 UserDefaults key
    private let hasMigratedKey = "legacyDataMigrated_v1"

    /// 标记是否已询问过用户的 UserDefaults key（用于首次启动）
    private let hasAskedKey = "legacyDataAsked_v1"

    /// 获取 v4 版本数据使用的 UserDefaults
    /// - Returns: v4 版本数据存储的 UserDefaults
    nonisolated private func getLegacyDefaults() -> UserDefaults {
        return UserDefaults(suiteName: "net.yanue.V2rayU") ?? .standard
    }

    /// 检查是否已经完成迁移
    /// - Returns: 如果已迁移返回 true
    nonisolated func hasMigrated() -> Bool {
        return UserDefaults.standard.bool(forKey: hasMigratedKey)
    }

    /// 检查是否已经询问过用户（首次启动时使用）
    nonisolated func hasAsked() -> Bool {
        return UserDefaults.standard.bool(forKey: hasAskedKey)
    }

    /// 标记已询问用户
    nonisolated func markAsAsked() {
        UserDefaults.standard.set(true, forKey: hasAskedKey)
    }

    /// 标记迁移完成
    nonisolated func markAsMigrated() {
        UserDefaults.standard.set(true, forKey: hasMigratedKey)
    }

    /// 检查是否有旧版数据可迁移
    /// - Returns: (服务器数量, 订阅数量)
    nonisolated func checkLegacyData() -> (servers: Int, subscriptions: Int) {
        let defaults = getLegacyDefaults()
        let serverList = defaults.array(forKey: "v2rayServerList") as? [String] ?? []
        let subList = defaults.array(forKey: "v2raySubList") as? [String] ?? []
        return (serverList.count, subList.count)
    }

    /// 检查是否有可迁移的旧版数据
    /// - Returns: 是否有旧数据
    nonisolated func hasLegacyData() -> Bool {
        let data = checkLegacyData()
        return data.servers > 0 || data.subscriptions > 0
    }

    /// 首次启动时检查并弹窗
    /// - Returns: 是否执行了迁移（true=迁移了，false=用户取消或无数据）
    @MainActor
    func checkAndPromptForMigration() async -> Bool {
        // 如果已经询问过，直接返回
        guard !hasAsked() else {
            logger.debug("Legacy migration: Already asked user, skipping prompt")
            return false
        }

        // 检查是否有旧数据
        let data = checkLegacyData()
        guard data.servers > 0 || data.subscriptions > 0 else {
            logger.info("Legacy migration: No legacy data found")
            markAsAsked()
            return false
        }

        // 标记已询问（防止重复弹窗）
        markAsAsked()

        // 显示系统弹窗
        let alert = NSAlert()
        alert.messageText = String(localized: .ImportLegacyDataTitle)
        alert.informativeText = String(localized: .ImportLegacyInfo, arguments: data.servers, data.subscriptions)
        alert.alertStyle = .informational
        alert.addButton(withTitle: String(localized: .ImportLegacyButton))
        alert.addButton(withTitle: String(localized: .ImportLegacySkip))

        let response = await presentAlert(alert)

        if response == .alertFirstButtonReturn {
            logger.info("Legacy migration: User chose to migrate")
            let result = await migrate()
            switch result {
            case .success(let profiles, let subs, let routings):
                logger.info("Legacy migration: Success - \(profiles) profiles, \(subs) subscriptions, \(routings) routings")
                return true
            case .noData:
                logger.info("Legacy migration: No data to migrate")
                return false
            case .error(let msg):
                logger.error("Legacy migration: Failed - \(msg)")
                return false
            }
        } else {
            logger.info("Legacy migration: User chose to skip")
            markAsMigrated()
            return false
        }
    }

    /// 执行数据迁移（用户主动触发，忽略已迁移标记）
    ///
    /// 迁移流程：
    /// 1. 读取 v2rayServerList 和 v2raySubList
    /// 2. 先迁移订阅（建立订阅 ID 映射）
    /// 3. 再迁移服务器（关联订阅 ID）
    /// 4. 标记迁移完成
    ///
    /// - Returns: 迁移结果
    func migrate() async -> LegacyMigrationResult {
        logger.info("Legacy migration: Starting migration process (user triggered)")

        // 读取服务器列表和订阅列表
        // v4 版本使用 net.yanue.V2rayU domain 的 UserDefaults 存储
        let defaults = getLegacyDefaults()
        let serverList = defaults.array(forKey: "v2rayServerList") as? [String] ?? []
        let subList = defaults.array(forKey: "v2raySubList") as? [String] ?? []
        let routingList = defaults.array(forKey: "routingCustomList") as? [String] ?? []

        logger.info("Legacy migration: Found \(serverList.count) servers, \(subList.count) subscriptions, \(routingList.count) routings")

        // 如果没有旧数据，直接返回
        guard !serverList.isEmpty || !subList.isEmpty || !routingList.isEmpty else {
            logger.info("Legacy migration: No legacy data found")
            return .noData
        }

        var profileCount = 0   // 成功迁移的服务器数量
        var subCount = 0       // 成功迁移的订阅数量

        do {
            // 建立旧版订阅 ID 到新版订阅 ID 的映射
            // 用于后续服务器关联订阅
            var subidMapping: [String: String] = [:]

            // 第一步：迁移订阅
            logger.info("Legacy migration: Starting subscription migration")
            for subName in subList {
                logger.debug("Legacy migration: Loading subscription '\(subName)'")

                guard let legacySub = LegacyV2raySubItem.load(name: subName, defaults: defaults) else {
                    logger.warning("Legacy migration: Failed to load subscription '\(subName)'")
                    continue
                }

                // 使用 subName（UserDefaults 列表中的 key）作为订阅的 uuid
                // 例如: "subscribe.95E19B5D-FCED-4DED-BB39-810AF7409FFB" -> "95E19B5D-FCED-4DED-BB39-810AF7409FFB"
                let subUuid: String
                if subName.hasPrefix("subscribe.") {
                    let potentialUuid = String(subName.dropFirst("subscribe.".count))
                    if let _ = UUID(uuidString: potentialUuid) {
                        subUuid = potentialUuid
                    } else {
                        logger.warning("Legacy migration: subName '\(subName)' is not valid UUID, generating new uuid")
                        subUuid = UUID().uuidString
                    }
                } else {
                    subUuid = UUID().uuidString
                }

                // 检查是否已存在该 uuid 的订阅，避免重复导入
                if await subscriptionExists(uuid: subUuid) {
                    logger.info("Legacy migration: Subscription with uuid '\(subUuid)' already exists, skipping")
                    continue
                }

                // 创建新的订阅实体
                let newSub = SubscriptionEntity(
                    uuid: subUuid,
                    remark: legacySub.remark,
                    url: legacySub.url,
                    enable: legacySub.isValid,
                    sort: subCount
                )

                logger.debug("Legacy migration: Creating subscription '\(legacySub.remark)' with uuid '\(subUuid)'")

                // 插入数据库
                try await insertSubscription(newSub)

                // 提取旧版订阅 ID（去掉 "subscribe." 前缀）
                let legacySubId = String(subName.dropFirst("subscribe.".count))
                subidMapping[legacySubId] = newSub.uuid
                subCount += 1

                logger.info("Legacy migration: Migrated subscription '\(legacySub.remark)'")
            }

            // 第二步：迁移服务器
            logger.info("Legacy migration: Starting server migration")
            for serverName in serverList {
                logger.debug("Legacy migration: Loading server '\(serverName)'")

                guard let legacyServer = LegacyV2rayItem.load(name: serverName, defaults: defaults) else {
                    logger.warning("Legacy migration: Failed to load server '\(serverName)'")
                    continue
                }

                logger.debug("Legacy migration: Server '\(serverName)' remark='\(legacyServer.remark)', url='\(legacyServer.url)', json.count=\(legacyServer.json.count)")

                // 调试：检查 url 和 json 是否有效
                logger.debug("Legacy migration: url.isEmpty=\(legacyServer.url.isEmpty), json.isEmpty=\(legacyServer.json.isEmpty)")

                // 使用 serverName（UserDefaults 列表中的 key）作为 profile 的 uuid
                // 例如: "config.97B333FD-18C1-4AD9-A1B5-EF2C4F8E7BA1" -> "97B333FD-18C1-4AD9-A1B5-EF2C4F8E7BA1"
                let profileUuid: String
                if serverName.hasPrefix("config.") {
                    let potentialUuid = String(serverName.dropFirst("config.".count))
                    if let _ = UUID(uuidString: potentialUuid) {
                        profileUuid = potentialUuid
                    } else {
                        logger.warning("Legacy migration: serverName '\(serverName)' is not valid UUID, generating new uuid")
                        profileUuid = UUID().uuidString
                    }
                } else {
                    profileUuid = UUID().uuidString
                }

                logger.debug("Legacy migration: Checking if profile uuid '\(profileUuid)' exists...")

                // 检查是否已存在该 uuid 的 profile，避免重复导入
                let exists = await profileExists(uuid: profileUuid)
                logger.debug("Legacy migration: profileExists result: \(exists)")
                if exists {
                    logger.info("Legacy migration: Profile with uuid '\(profileUuid)' already exists, skipping")
                    continue
                }

                logger.debug("Legacy migration: Profile uuid '\(profileUuid)' does not exist, proceeding with migration")

                // 解析为新的 ProfileEntity
                if let profile = await parseToProfile(legacyServer: legacyServer, profileUuid: profileUuid, subidMapping: subidMapping) {
                    logger.debug("Legacy migration: Parsed profile '\(profile.remark)'")

                    // 插入数据库
                    try await insertProfile(profile)
                    profileCount += 1

                    logger.info("Legacy migration: Migrated server '\(profile.remark)'")
                } else {
                    logger.warning("Legacy migration: Failed to parse server '\(serverName)' - no valid URI or JSON data")
                }
            }

            // 第三步：迁移路由 (#1613)
            let routingCount = await migrateRoutings(names: routingList, defaults: defaults)

            // 标记迁移完成
            markAsMigrated()
            logger.info("Legacy migration: Completed: \(profileCount) servers, \(subCount) subscriptions, \(routingCount) routings")

            return .success(profiles: profileCount, subscriptions: subCount, routings: routingCount)

        } catch {
            logger.error("Legacy migration: Failed with error: \(error)")
            return .error(error.localizedDescription)
        }
    }

    // MARK: - 数据解析

    /// 将旧版服务器配置解析为新版 ProfileEntity
    ///
    /// 解析优先级：
    /// 1. 如果有分享链接 URI，优先使用 URI 解析（支持更多格式）
    /// 2. 如果有 JSON 配置，尝试解析 JSON
    /// 3. 两者都没有则返回 nil
    ///
    /// - Parameters:
    ///   - legacyServer: 旧版服务器配置
    ///   - profileUuid: 已计算好的 profile uuid（从 serverName 解析）
    ///   - subidMapping: 订阅 ID 映射表
    /// - Returns: 解析后的 ProfileEntity，失败返回 nil
    private func parseToProfile(legacyServer: LegacyV2rayItem, profileUuid: String, subidMapping: [String: String]) async -> ProfileEntity? {
        var profile = ProfileEntity()

        // 使用传入的 profileUuid
        profile.uuid = profileUuid

        // 设置基本信息
        profile.remark = legacyServer.remark
        profile.shareUri = legacyServer.url

        // 调试：打印所有字段
        logger.debug("LegacyMigration: remark='\(legacyServer.remark)', url='\(legacyServer.url)', json.count=\(legacyServer.json.count), subscribe='\(legacyServer.subscribe)', speed='\(legacyServer.speed)', isValid=\(legacyServer.isValid), name='\(legacyServer.name)'")

        // 解析延迟速度（格式如 "123ms"）
        if let speedStr = Int(legacyServer.speed.replacingOccurrences(of: "ms", with: "")) {
            profile.speed = speedStr > 0 ? speedStr : -1
        }

        // 关联订阅
        let legacySubId = legacyServer.subscribe.hasPrefix("subscribe.") ? String(legacyServer.subscribe.dropFirst("subscribe.".count)) : ""
        if !legacySubId.isEmpty, let newSubId = subidMapping[legacySubId] {
            profile.subid = newSubId
            logger.debug("LegacyMigration: Mapped subscription '\(legacySubId)' -> '\(newSubId)'")
        }

        // 如果有 name 字段，尝试从 name 中提取 JSON（某些 v4 版本可能将 JSON 存储在 name 中）
        if legacyServer.json.isEmpty && !legacyServer.name.isEmpty && legacyServer.name.hasPrefix("config.") {
            // 尝试从 name 对应的 key 读取原始 JSON
            logger.debug("LegacyMigration: json is empty, trying to find JSON from alternative storage")
        }

        // 优先使用分享链接 URI 解析
        if !legacyServer.url.isEmpty {
            logger.debug("LegacyMigration: Attempting to parse from URI, url.prefix(50)=\(legacyServer.url.prefix(50))")
            if let importedProfile = importFromUri(uri: legacyServer.url) {
                // 覆盖基本信息，保留从 legacyServer 获取的 uuid、subid 和 speed
                var profile = importedProfile
                profile.uuid = profileUuid  // 使用传入的 profileUuid
                profile.remark = legacyServer.remark
                profile.shareUri = legacyServer.url
                // subid 从 legacyServer.subscribe 解析
                let legacySubId = legacyServer.subscribe.hasPrefix("subscribe.") ? String(legacyServer.subscribe.dropFirst("subscribe.".count)) : ""
                if !legacySubId.isEmpty, let newSubId = subidMapping[legacySubId] {
                    profile.subid = newSubId
                }
                logger.debug("LegacyMigration: URI parsed successfully for '\(legacyServer.remark)'")
                return profile
            } else {
                logger.debug("LegacyMigration: URI parsing failed")
            }
        }

        // 尝试从 JSON 配置解析
        if !legacyServer.json.isEmpty {
            logger.debug("LegacyMigration: Attempting to parse from JSON, length=\(legacyServer.json.count)")
            if let parsedProfile = parseFromJson(json: legacyServer.json) {
                // 覆盖基本信息，保留从 legacyServer 获取的 uuid、subid 和 speed
                var profile = parsedProfile
                profile.uuid = profileUuid  // 使用传入的 profileUuid
                profile.remark = legacyServer.remark
                profile.shareUri = legacyServer.url
                // subid 从 legacyServer.subscribe 解析
                let legacySubId = legacyServer.subscribe.hasPrefix("subscribe.") ? String(legacyServer.subscribe.dropFirst("subscribe.".count)) : ""
                if !legacySubId.isEmpty, let newSubId = subidMapping[legacySubId] {
                    profile.subid = newSubId
                }
                logger.debug("LegacyMigration: JSON parsed successfully for '\(legacyServer.remark)'")
                return profile
            } else {
                logger.debug("LegacyMigration: JSON parsing failed")
            }
        }

        // 尝试直接解析 remark 字段（某些 v4 版本可能将 URI 存储在 remark 中）
        if !legacyServer.remark.isEmpty {
            if legacyServer.remark.hasPrefix("vmess://") || legacyServer.remark.hasPrefix("vless://") ||
               legacyServer.remark.hasPrefix("trojan://") || legacyServer.remark.hasPrefix("ss://") ||
               legacyServer.remark.hasPrefix("ssr://") {
                logger.debug("LegacyMigration: Trying to parse from remark (URI format)")
                if let importedProfile = importFromUri(uri: legacyServer.remark) {
                    // 覆盖基本信息，保留从 legacyServer 获取的 uuid、subid 和 speed
                    var profile = importedProfile
                    profile.uuid = profileUuid  // 使用传入的 profileUuid
                    profile.remark = legacyServer.remark
                    profile.shareUri = legacyServer.remark
                // subid 从 legacyServer.subscribe 解析
                let legacySubId = legacyServer.subscribe.hasPrefix("subscribe.") ? String(legacyServer.subscribe.dropFirst("subscribe.".count)) : ""
                if !legacySubId.isEmpty, let newSubId = subidMapping[legacySubId] {
                        profile.subid = newSubId
                    }
                    // speed 从 legacyServer.speed 解析
                    if let speedStr = Int(legacyServer.speed.replacingOccurrences(of: "ms", with: "")) {
                        profile.speed = speedStr > 0 ? speedStr : -1
                    }
                    logger.debug("LegacyMigration: Parsed from remark successfully")
                    return profile
                }
            }
        }

        logger.warning("LegacyMigration: No valid data found for server '\(legacyServer.remark)'")
        return nil
    }

    /// 从分享链接 URI 解析服务器配置
    ///
    /// 支持的格式：vmess://, vless://, trojan://, ss://, ssr://
    ///
    /// - Parameter uri: 分享链接 URI
    /// - Returns: 解析后的 ProfileEntity，失败返回 nil
    private func importFromUri(uri: String) -> ProfileEntity? {
        let trimmed = uri.trimmingCharacters(in: .whitespacesAndNewlines)
        logger.debug("LegacyMigration: Parsing URI: \(trimmed.prefix(50))...")

        let importUri = ImportUri(share_uri: trimmed)

        if var profile = importUri.doImport() {
            profile.shareUri = uri
            logger.debug("LegacyMigration: URI parsed successfully")
            return profile
        }

        logger.debug("LegacyMigration: URI parsing returned nil, error: \(importUri.error)")
        return nil
    }

    /// 从 V2ray JSON 配置解析服务器配置
    ///
    /// 复用 ImportHandler.swift 中的 importFromJson 函数
    ///
    /// - Parameter json: V2ray JSON 配置字符串
    /// - Returns: 解析后的 ProfileEntity，失败返回 nil
    private func parseFromJson(json: String) -> ProfileEntity? {
        return importFromJson(json: json)
    }

    // MARK: - 数据库操作

    /// 检查指定 uuid 的 profile 是否已存在
    /// - Parameter uuid: profile uuid
    /// - Returns: 是否存在
    private func profileExists(uuid: String) async -> Bool {
        logger.debug("LegacyMigration: profileExists checking uuid '\(uuid)'")
        return await withCheckedContinuation { continuation in
            do {
                try AppDatabase.shared.dbWriter.read { db in
                    let count = try ProfileEntity.filter(Column("uuid") == uuid).fetchCount(db)
                    logger.debug("LegacyMigration: profileExists found \(count) records for uuid '\(uuid)'")
                    continuation.resume(returning: count > 0)
                }
            } catch {
                logger.error("LegacyMigration: profileExists error: \(error)")
                continuation.resume(returning: false)
            }
        }
    }

    /// 迁移 v4 路由: 只插入 v5 中不存在的, 不修改 v5 已有路由; v4 选中的路由迁移过来时恢复为当前路由
    /// - Returns: 新迁移的路由数
    private func migrateRoutings(names: [String], defaults: UserDefaults) async -> Int {
        guard !names.isEmpty else { return 0 }
        let defaultRules = await MainActor.run { () -> [String: RoutingEntity] in
            let manager = RoutingManager()
            // 先确保 v5 内置路由已生成(路由表为空时才会生成, 先插入旧路由会导致内置路由缺失)
            _ = manager.getRunningEntity()
            return manager.defaultRules
        }
        let existing = RoutingStore.shared.fetchAll()
        var sort = (existing.map(\.sort).max() ?? 0) + 1
        var migrated: [String: String] = [:] // v4 名称 -> v5 uuid

        for name in names {
            guard let legacy = LegacyRoutingItem.load(name: name, defaults: defaults) else {
                logger.warning("Legacy migration: Failed to load routing '\(name)'")
                continue
            }
            if legacy.name.isEmpty { legacy.name = name }
            let uuid = LegacyRoutingItem.migratedUuid(for: name)
            if RoutingStore.shared.fetchOne(uuid: uuid) != nil {
                logger.info("Legacy migration: Routing '\(name)' already migrated, skipping")
                continue
            }
            guard let converted = legacy.toEntity(uuid: uuid, defaultRules: defaultRules) else {
                logger.info("Legacy migration: Routing '\(name)' has nothing to migrate, skipping")
                continue
            }
            if converted.skippedRules > 0 {
                logger.warning("Legacy migration: Routing '\(name)' skipped \(converted.skippedRules) rules that v5 cannot represent")
            }
            var item = converted.entity
            item.sort = sort
            if RoutingStore.shared.insert(item) {
                migrated[name] = uuid
                sort += 1
                logger.info("Legacy migration: Migrated routing '\(item.remark)'")
            }
        }

        // 恢复 v4 选中的路由(仅当它是这次新迁移过来的)
        if let selected = defaults.string(forKey: "routingSelectedRule"), let uuid = migrated[selected] {
            await MainActor.run {
                AppState.shared.runningRouting = uuid
                AppMenuManager.shared.refreshRoutingItems()
            }
            // 代理正在运行时重载核心使路由生效; 未运行则下次启动生效(不主动开启代理)
            if await V2rayLaunch.shared.isRunning {
                await V2rayLaunch.shared.reloadCore()
            }
        }
        return migrated.count
    }

    /// 检查指定 uuid 的订阅是否已存在
    /// - Parameter uuid: 订阅 uuid
    /// - Returns: 是否存在
    private func subscriptionExists(uuid: String) async -> Bool {
        return await withCheckedContinuation { continuation in
            do {
                try AppDatabase.shared.dbWriter.read { db in
                    let count = try SubscriptionEntity.filter(Column("uuid") == uuid).fetchCount(db)
                    continuation.resume(returning: count > 0)
                }
            } catch {
                logger.error("LegacyMigration: subscriptionExists error: \(error)")
                continuation.resume(returning: false)
            }
        }
    }

    /// 插入 ProfileEntity 到数据库
    /// - Parameter profile: 要插入的配置
    private func insertProfile(_ profile: ProfileEntity) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            do {
                try AppDatabase.shared.dbWriter.write { db in
                    try profile.insert(db)
                }
                continuation.resume()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    /// 插入 SubscriptionEntity 到数据库
    /// - Parameter subscription: 要插入的订阅
    private func insertSubscription(_ subscription: SubscriptionEntity) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            do {
                try AppDatabase.shared.dbWriter.write { db in
                    try subscription.insert(db)
                }
                continuation.resume()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
