//
//  ProxyList.swift
//  V2rayU
//
//  Created by yanue on 2024/12/14.
//

import Combine
import Foundation
import GRDB

class ProfileViewModel: ObservableObject {
    @Published var list: [ProfileModel] = []
    @Published var groups: [String] = []

    func getList() {
        do {
            let dbReader = AppDatabase.shared.reader
            try dbReader.read { db in
                // 按 sort 排序
                list = try ProfileModel.fetchAll(db).sorted(by: { $0.sort < $1.sort })
            }
        } catch {
            logger.info("getList error: \(error)")
        }
    }

    func delete(uuid: String) {
        Self.delete(uuid: uuid)
        getList()
    }

    func upsert(item: ProfileModel) {
        Self.upsert(item: item)
        getList()
    }

    // MARK: - Static

    // 获取当前正在运行配置
    static func getRunning() -> ProfileModel? {
        var item: ProfileModel?
        // 获取当前运行配置
        let runningProfile = UserDefaults.get(forKey: .runningProfile)
        if !runningProfile.isEmpty {
            // 根据uuid获取配置
            item = ProfileViewModel.fetchOne(uuid: runningProfile)
        }
        if item == nil {
            // 没有配置，获取速度最快的配置
            item = ProfileViewModel.getFastOne()
        }
        return item
    }

    static func all() -> [ProfileModel] {
        do {
            let dbReader = AppDatabase.shared.reader
            return try dbReader.read { db in
                try ProfileModel.fetchAll(db)
            }
        } catch {
            logger.info("getList error: \(error)")
            return []
        }
    }
    
    static func getGroupedProfiles() -> [String: [ProfileModel]] {
        let profiles = ProfileViewModel.all()
        let groups = SubViewModel.all().reduce(into: [String: SubModel]()) { dict, sub in
            dict[sub.uuid] = sub
        }
        var result: [String: [ProfileModel]] = [:]
        
        // 按 subid 分组
        for profile in profiles {
            if !profile.subid.isEmpty, groups[profile.subid] != nil {
                // 有订阅的按订阅ID分组
                result[groups[profile.subid]?.remark ?? "", default: []].append(profile)
            } else {
                // 没有订阅的放在空字符串组
                result["", default: []].append(profile)
            }
        }
        
        // 重新排序，让空字符串的组（本地配置）放在最前面
        let sortedResult = result.sorted { (first, second) -> Bool in
            if first.key.isEmpty {
                return true  // 空key放前面
            } else if second.key.isEmpty {
                return false
            } else {
                // 其他按订阅名称排序
                let firstName = groups[first.key]?.remark ?? first.key
                let secondName = groups[second.key]?.remark ?? second.key
                return firstName < secondName
            }
        }
        
        return Dictionary(uniqueKeysWithValues: sortedResult)
    }
    
    // filter: ["id": 1,"conlmn":"value"]
    static func count(filter: [String: (any DatabaseValueConvertible)?]?) -> Int {
        guard let filter = filter else { return 0 }
        do {
            let dbReader = AppDatabase.shared.reader
            return try dbReader.read { db in
                var query = ProfileModel.all()
                for (column, value) in filter {
                    if let value = value {
                        query = query.filter(Column(column) == value)
                    }
                }
                return try query.fetchCount(db)
            }
        } catch {
            logger.info("count error: \(error)")
            return 0
        }
    }

    static func getFastOne() -> ProfileModel? {
        do {
            let dbReader = AppDatabase.shared.reader
            return try dbReader.read { db in
                try ProfileModel.order(ProfileModel.Columns.speed.desc).fetchOne(db)
            }
        } catch {
            logger.info("getFastOne error: \(error)")
            return nil
        }
    }

    static func fetchOne(uuid: String) -> ProfileModel? {
        do {
            let dbReader = AppDatabase.shared.reader
            return try dbReader.read { db in
                try ProfileModel.filter(ProfileModel.Columns.uuid == uuid).fetchOne(db)
            }
        } catch {
            logger.info("fetchOne error: \(error)")
            return nil
        }
    }

    static func delete(uuid: String) {
        do {
            let dbWriter = AppDatabase.shared.dbWriter
            try dbWriter.write { db in
                try _ = ProfileModel.filter(ProfileModel.Columns.uuid == uuid).deleteAll(db)
            }
        } catch {
            logger.info("delete error: \(error)")
        }
    }

    // filter: ["id": 1,"conlmn":"value"]
    static func delete(filter: [String: (any DatabaseValueConvertible)?]?) {
        guard let filter = filter else { return }
        do {
            let dbWriter = AppDatabase.shared.dbWriter
            try dbWriter.write { db in
                var query = ProfileModel.all()
                for (column, value) in filter {
                    if let value = value {
                        query = query.filter(Column(column) == value)
                    }
                }
                try query.deleteAll(db)
            }
        } catch {
            logger.info("delete error: \(error)")
        }
    }

    static func update_speed(uuid: String, speed: Int) {
        do {
            let dbWriter = AppDatabase.shared.dbWriter
            try dbWriter.write { db in
                try _ = ProfileModel.filter(ProfileModel.Columns.uuid == uuid).updateAll(db, [ProfileModel.Columns.speed.set(to: speed)])
            }
        } catch {
            logger.info("delete error: \(error)")
        }
    }

    func updateSortOrderInDBAsync() {
        do {
            let dbWriter = AppDatabase.shared.dbWriter
            try dbWriter.write { db in
                for (index, item) in list.enumerated() {
                    item.sort = index // Update the sort order in memory
                    try item.update(db, columns: [ProfileModel.Columns.sort]) // Update the database
                }
            }
        } catch {
            logger.info("updateSortOrderInDBAsync error: \(error)")
        }
    }

    static func upsert(item: ProfileModel) {
        do {
            let dbWriter = AppDatabase.shared.dbWriter
            try dbWriter.write { db in
                try item.save(db)
            }
        } catch {
            logger.info("upsert error: \(error)")
        }
    }

    static func insert_many(items: [ProfileModel]) {
        do {
            let dbWriter = AppDatabase.shared.dbWriter
            try dbWriter.write { db in
                try items.forEach { item in
                    try item.save(db)
                }
            }
        } catch {
            logger.info("insert_many error: \(error)")
        }
    }
}
