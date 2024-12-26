//
//  Routing.swift
//  V2rayU
//
//  Created by yanue on 2024/12/14.
//


import Combine
import GRDB
import Foundation

let RoutingRuleGlobal = "routing.global"
let RoutingRuleLAN = "routing.lan"
let RoutingRuleCn = "routing.cn"
let RoutingRuleLANAndCn = "routing.lanAndCn"

let defaultRuleCn = Dictionary(uniqueKeysWithValues: [
    (RoutingRuleGlobal, "🌏 全局"),
    (RoutingRuleLAN, "🌏 绕过局域网"),
    (RoutingRuleCn, "🌏 绕过中国大陆"),
    (RoutingRuleLANAndCn, "🌏 绕过局域网和中国大陆"),
])

let defaultRuleEn = Dictionary(uniqueKeysWithValues: [
    (RoutingRuleGlobal, "🌏 Global"),
    (RoutingRuleLAN, "🌏 Bypassing the LAN Address"),
    (RoutingRuleCn, "🌏 Bypassing mainland address"),
    (RoutingRuleLANAndCn, "🌏 Bypassing LAN and mainland address"),
])

let defaultRules = Dictionary(uniqueKeysWithValues: [
   (RoutingRuleGlobal, RoutingModel(name: RoutingRuleGlobal, remark: "")),
   (RoutingRuleLAN, RoutingModel(name: RoutingRuleLAN, remark: "")),
   (RoutingRuleCn, RoutingModel(name: RoutingRuleCn, remark: "")),
   (RoutingRuleLANAndCn, RoutingModel(name: RoutingRuleLANAndCn, remark: "")),
])

class RoutingViewModel: ObservableObject {
    @Published var list: [RoutingModel] = []

    func getList() {
        do {
            let dbReader = AppDatabase.shared.reader
            try dbReader.read { db in
                list = try RoutingModel.fetchAll(db)
            }
        } catch {
            print("getList error: \(error)")
        }
    }

    static func all() -> [RoutingModel] {
        do {
            let dbReader = AppDatabase.shared.reader
            return try dbReader.read { db in
                return try RoutingModel.fetchAll(db)
            }
        } catch {
            print("getList error: \(error)")
            return []
        }
    }

    // 获取正在运行路由规则, 优先级: 用户选择 > 默认规则
    static func getRunning() -> V2rayRouting {
        // 查询当前使用的规则
        let runningRouting = UserDefaults.get(forKey: .runningRouting)
        // 查询所有规则
        let all = RoutingViewModel.all()
        // 如果没有规则，则创建默认规则
        if all.count == 0 {
            for (_, item) in defaultRules {
                RoutingViewModel.upsert(item)
                // 添加到 all
                all.append(item)
            }
        }
        for item in all {
            // 如果匹配到选中的规则，则返回
            if item.uuid == runningRouting {
                let handler = RoutingHandler(from: item)
                return handler.getRouting()
            }
        }
        let defaultRouting = defaultRules[RoutingRuleLANAndCn]!
        // 如果没有匹配到选中的规则，则返回默认规则
        let handler = RoutingHandler(from: defaultRouting)
        // 设置默认规则
        UserDefaults.set(forKey: .runningRouting, value: defaultRouting.uuid)
        return handler.getRouting()
    }

    func fetchOne(uuid: String) throws -> RoutingModel {
        let dbReader = AppDatabase.shared.reader
        return try dbReader.read { db in
            guard let model = try RoutingModel.filter(RoutingModel.Columns.uuid == uuid).fetchOne(db) else {
                throw NSError(domain: "RoutingModel", code: 404, userInfo: [NSLocalizedDescriptionKey: "RoutingModel not found for uuid: \(uuid)"])
            }
            return model
        }
    }

    func delete(uuid: String) {
        do {
            let dbWriter = AppDatabase.shared.dbWriter
            try dbWriter.write { db in
                try RoutingModel.filter(RoutingModel.Columns.uuid == uuid).deleteAll(db)
            }
            getList()
        } catch {
            print("delete error: \(error)")
        }
    }

    func upsert(item: RoutingModel) {
        do {
            let dbWriter = AppDatabase.shared.dbWriter
            try dbWriter.write { db in
                try item.save(db)
            }
            getList()
        } catch {
            print("upsert error: \(error)")
        }
    }
}
