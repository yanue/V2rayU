//
//  ProfileStore.swift
//  V2rayU
//
//  Created by yanue on 2025/11/11.
//

import Foundation
import GRDB

/// 封装 ProfileEntity 的数据库操作
struct ProfileStore: StoreProtocol {
    typealias Entity = ProfileEntity

    static let shared = ProfileStore()

    let dbReader: DatabaseReader = AppDatabase.shared.reader
    let dbWriter: DatabaseWriter = AppDatabase.shared.dbWriter
    
    @discardableResult
    func insertMany(_ items: [ProfileEntity]) -> Bool {
        do {
            try dbWriter.write { db in
                for item in items {
                    try item.save(db)
                }
            }
            return true
        } catch {
            logger.info("ProfileStore.insertMany error: \(error)")
            return false
        }
    }

    // MARK: - Query
    
    // 获取当前正在运行配置
    func getRunning() -> ProfileEntity? {
        var item: ProfileEntity?
        // 获取当前运行配置
        let runningProfile = UserDefaults.get(forKey: .runningProfile)
        if !runningProfile.isEmpty {
            // 根据uuid获取配置
            item = fetchOne(uuid: runningProfile)
        }
        if item == nil {
            // 没有配置，获取速度最快的配置
            item = getFastOne()
        }
        return item
    }

    func getFastOne() -> ProfileEntity? {
        do {
            return try dbReader.read { db in
                try ProfileEntity.order(ProfileEntity.Columns.speed.desc).fetchOne(db)
            }
        } catch {
            logger.info("ProfileStore.getFastOne error: \(error)")
            return nil
        }
    }

    func getGroupProfiles(subid: String) -> [ProfileEntity] {
        do {
            return try dbReader.read { db in
                var query = ProfileEntity.all()
                query = query.filter(ProfileEntity.Columns.subid == subid)
                return try query.fetchAll(db)
            }
        } catch {
            logger.info("ProfileStore.getGroupProfiles error: \(error)")
            return []
        }
    }

    // MARK: - Update

    @discardableResult
    func updateProfile(oldDto: ProfileEntity, newDto: ProfileEntity) -> Bool {
        do {
            try dbWriter.write { db in
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
            return true
        } catch {
            logger.info("ProfileStore.updateProfile error: \(error)")
            return false
        }
    }

    @discardableResult
    func updateSpeed(uuid: String, speed: Int) -> Bool {
        do {
            _ = try dbWriter.write { db in
                try ProfileEntity
                    .filter(ProfileEntity.Columns.uuid == uuid)
                    .updateAll(db, [ProfileEntity.Columns.speed.set(to: speed)])
            }
            return true
        } catch {
            logger.info("ProfileStore.updateSpeed error: \(error)")
            return false
        }
    }

    @discardableResult
    func updateSortOrder(_ entities: [ProfileEntity]) -> Bool {
        do {
            try dbWriter.write { db in
                for (index, var entity) in entities.enumerated() {
                    entity.sort = index
                    try entity.update(db, columns: [ProfileEntity.Columns.sort])
                }
            }
            return true
        } catch {
            logger.info("ProfileStore.updateSortOrder error: \(error)")
            return false
        }
    }
    
    func update_speed(uuid: String, speed: Int) {
        do {
            let dbWriter = AppDatabase.shared.dbWriter
            try dbWriter.write { db in
                try _ = ProfileEntity.filter(ProfileEntity.Columns.uuid == uuid).updateAll(db, [ProfileEntity.Columns.speed.set(to: speed)])
            }
        } catch {
            logger.info("delete error: \(error)")
        }
    }
    
    /// 更新 `profile_stat` 表中指定 `uuid` 的统计数据
    func update_stat(uuid: String, up: Int, down: Int, lastUpdate: Date) throws {
        let sql = """
        UPDATE profile
        SET
            todayUp   = todayUp + ?,
            todayDown = todayDown + ?,
            totalUp   = totalUp + ?,
            totalDown = totalDown + ?,
            lastUpdate = ?
        WHERE uuid = ?
        """
        do {
            let dbWriter = AppDatabase.shared.dbWriter
            try dbWriter.write { db in
                try db.execute(
                    sql: sql,
                    arguments: [up, down, up, down, lastUpdate, uuid]
                )
            }
        } catch {
            logger.info("update_stat error: \(error)")
        }
    }

    /// 清空 `profile_stat` 表中指定 `uuid` 的今日数据
    /// 如果 `lastUpdate` 日期非今天，则将 `todayUp` 和 `todayDown` 清零，并更新 `lastUpdate` 为当前时间
    /// - Parameters:
    ///   - uuid: 唯一标识符
    func clearTodayData(uuid: String) throws {
        // 获取当前日期的开始时间（00:00:00）
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        do {
            let dbReader = AppDatabase.shared.reader
            return try dbReader.read { db in
                let sql = "SELECT lastUpdate FROM profile WHERE uuid = ?"
                // 查询指定 `uuid` 的 `lastUpdate`
                guard let lastUpdate: Date = try Date.fetchOne(db, sql: sql, arguments: [uuid]) else {
                    // 如果未查询到记录，直接返回
                    return
                }
                // 如果 `lastUpdate` 小于今日开始时间，表示非今天，需要清空今日数据
                if lastUpdate < todayStart {
                    do {
                        let dbWriter = AppDatabase.shared.dbWriter
                        return try dbWriter.write { db in
                            try db.execute(
                                sql: """
                                UPDATE profile
                                SET todayUp = 0, todayDown = 0, lastUpdate = ?
                                WHERE uuid = ?
                                """,
                                arguments: [Date(), uuid]
                            )
                        }
                    } catch {
                        logger.info("getFastOne error: \(error)")
                    }
                }
            }
        } catch {
            logger.info("clearTodayData error: \(error)")
            return
        }
    }

    func getGroupedProfiles() -> [(String, [ProfileEntity])] {
        let profiles = ProfileStore.shared.fetchAll()
        let groups = SubscriptionStore.shared.fetchAll().reduce(into: [String: SubscriptionEntity]()) {
            dict, sub in dict[sub.uuid] = sub
        }
        var result: [String: [ProfileEntity]] = [:]

        for profile in profiles {
            if !profile.subid.isEmpty, let sub = groups[profile.subid] {
                result[sub.remark, default: []].append(profile)
            } else {
                result["", default: []].append(profile)
            }
        }

        return result.sorted { first, second -> Bool in
            if first.key.isEmpty { return true }
            if second.key.isEmpty { return false }
            return first.key < second.key
        }
    }
}
