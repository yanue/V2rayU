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
    @Published var list: [ProfileDTO] = []
    @Published var groups: [String] = []

    func getList() {
        do {
            let dbReader = AppDatabase.shared.reader
            try dbReader.read { db in
                // 按 sort 排序
                list = try ProfileDTO.fetchAll(db).sorted(by: { $0.sort < $1.sort })
            }
        } catch {
            logger.info("getList error: \(error)")
        }
    }

    func delete(uuid: String) {
        Self.delete(uuid: uuid)
        getList()
    }

    func upsert(item: ProfileDTO) {
        Self.upsert(item: item)
        getList()
    }

    // MARK: - Static

    // 获取当前正在运行配置
    static func getRunning() -> ProfileDTO? {
        var item: ProfileDTO?
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

    static func all() -> [ProfileDTO] {
        do {
            let dbReader = AppDatabase.shared.reader
            return try dbReader.read { db in
                // 先取出结果（fetch）成数组，才能在 for-in 里使用。
                try ProfileDTO.all().fetchAll(db)
            }
        } catch {
            logger.info("getList error: \(error)")
            return []
        }
    }

    // 改成返回有序数组
    static func getGroupedProfiles() -> [(String, [ProfileDTO])] {
        let profiles = all()

        let groups = SubViewModel().all().reduce(into: [String: SubDTO]()) {
            dict, sub in dict[sub.uuid] = sub
        }
        var result: [String: [ProfileDTO]] = [:]

        // 按 subid 分组
        for profile in profiles {
            if !profile.subid.isEmpty, let sub = groups[profile.subid] {
                result[sub.remark, default: []].append(profile)
            } else {
                result["", default: []].append(profile)
            }
        }

        // 排序：空字符串组（本地配置）放最前，其余按订阅名称排序
        let sortedResult = result.sorted { first, second -> Bool in
            if first.key.isEmpty { return true }
            if second.key.isEmpty { return false }
            return first.key < second.key
        }

        return sortedResult
    }
    
    // MARK: - 根据 subid 获取配置列表
    static func getGroupProfiles(subid: String) -> [ProfileDTO] {
        do {
            let dbReader = AppDatabase.shared.reader
            return try dbReader.read { db in
                // 先取出结果（fetch）成数组，才能在 for-in 里使用。
                var query = ProfileDTO.all()
                query = query.filter(ProfileDTO.Columns.subid == subid)
                return try query.fetchAll(db)
            }
        } catch {
            logger.info("getList error: \(error)")
            return []
        }
    }
    
    // 更新除 uuid 和 统计字段外的所有字段
    static func update_profile(oldDto: ProfileDTO, newDto: ProfileDTO) {
        do {
            let dbWriter = AppDatabase.shared.dbWriter
            try dbWriter.write { db in
                // 除了 uuid,speed 和 统计字段外，全部更新
                var updatedDto = newDto
                updatedDto.uuid = oldDto.uuid
                updatedDto.speed = oldDto.speed
                updatedDto.totalUp = oldDto.totalUp
                updatedDto.totalDown = oldDto.totalDown
                updatedDto.todayUp = oldDto.todayUp
                updatedDto.todayDown = oldDto.todayDown
                updatedDto.lastUpdate = oldDto.lastUpdate
                try updatedDto.update(db)
            }
        } catch {
            logger.info("save error: \(error)")
        }
    }
    
    // filter: ["id": 1,"conlmn":"value"]
    static func count(filter: [String: (any DatabaseValueConvertible)?]?) -> Int {
        guard let filter = filter else { return 0 }
        do {
            let dbReader = AppDatabase.shared.reader
            return try dbReader.read { db in
                var query = ProfileDTO.all()
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

    static func getFastOne() -> ProfileDTO? {
        do {
            let dbReader = AppDatabase.shared.reader
            return try dbReader.read { db in
                try ProfileDTO.order(ProfileDTO.Columns.speed.desc).fetchOne(db)
            }
        } catch {
            logger.info("getFastOne error: \(error)")
            return nil
        }
    }

    static func fetchOne(uuid: String) -> ProfileDTO? {
        do {
            let dbReader = AppDatabase.shared.reader
            return try dbReader.read { db in
                try ProfileDTO.filter(ProfileDTO.Columns.uuid == uuid).fetchOne(db)
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
                try _ = ProfileDTO.filter(ProfileDTO.Columns.uuid == uuid).deleteAll(db)
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
                var query = ProfileDTO.all()
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
                try _ = ProfileDTO.filter(ProfileDTO.Columns.uuid == uuid).updateAll(db, [ProfileDTO.Columns.speed.set(to: speed)])
            }
        } catch {
            logger.info("delete error: \(error)")
        }
    }

    func updateSortOrderInDBAsync() {
        do {
            let dbWriter = AppDatabase.shared.dbWriter
            try dbWriter.write { db in
                for var (index, item) in list.enumerated() {
                    item.sort = index // Update the sort order in memory
                    try item.update(db, columns: [ProfileDTO.Columns.sort]) // Update the database
                }
            }
        } catch {
            logger.info("updateSortOrderInDBAsync error: \(error)")
        }
    }

    static func upsert(item: ProfileDTO) {
        do {
            let dbWriter = AppDatabase.shared.dbWriter
            try dbWriter.write { db in
                try item.save(db)
            }
        } catch {
            logger.info("upsert error: \(error)")
        }
    }

    static func insert_many(items: [ProfileDTO]) {
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
