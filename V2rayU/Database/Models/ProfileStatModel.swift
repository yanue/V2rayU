//
//  ProfileModel.swift
//  V2rayU
//
//  Created by yanue on 2024/12/2.
//

import GRDB
import SwiftUI
import UniformTypeIdentifiers

class ProfileStatModel: ObservableObject, Identifiable, Codable {
    var index: Int = 0
    // 公共属性
    @Published var uuid: String // 唯一标识
    @Published var totalUp: Int = 0 // 总上传
    @Published var totalDown: Int = 0 // 总下载
    @Published var todayUp: Int = 0 // 今日上传
    @Published var todayDown: Int = 0 // 今日下载
    @Published var lastUpdate: Date = Date() // 最后更新时间

    // Identifiable 协议的要求
    var id: String {
        return uuid
    }

    // 对应编码的 `CodingKeys` 枚举
    enum CodingKeys: String, CodingKey {
        case uuid, totalUp, totalDown, todayUp, todayDown, lastUpdate
    }

    // 需要手动实现 `init(from:)` 和 `encode(to:)`，如果你使用自定义类型时
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        uuid = try container.decode(String.self, forKey: .uuid)
        totalUp = try container.decode(Int.self, forKey: .totalUp)
        totalDown = try container.decode(Int.self, forKey: .totalDown)
        todayUp = try container.decode(Int.self, forKey: .todayUp)
        todayDown = try container.decode(Int.self, forKey: .todayDown)
        lastUpdate = try container.decode(Date.self, forKey: .lastUpdate)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(uuid, forKey: .uuid)
        try container.encode(totalUp, forKey: .totalUp)
        try container.encode(totalDown, forKey: .totalDown)
        try container.encode(todayUp, forKey: .todayUp)
        try container.encode(todayDown, forKey: .todayDown)
        try container.encode(lastUpdate, forKey: .lastUpdate)
    }

    // 提供默认值的初始化器
    init(
        uuid: String = UUID().uuidString,
        totalUp: Int = 0,
        totalDown: Int = 0,
        todayUp: Int = 0,
        todayDown: Int = 0,
        lastUpdate: Date = Date()
    ) {
        self.uuid = uuid
        self.totalUp = totalUp
        self.totalDown = totalDown
        self.todayUp = todayUp
        self.todayDown = todayDown
        self.lastUpdate = lastUpdate
    }
}

// 实现GRDB
extension ProfileStatModel: TableRecord, FetchableRecord, PersistableRecord {
    // 自定义表名
    static var databaseTableName: String {
        return "profile_stat" // 设置你的表名
    }

    // 定义数据库列
    enum Columns {
        static let uuid = Column(CodingKeys.uuid)
        static let totalUp = Column(CodingKeys.totalUp)
        static let totalDown = Column(CodingKeys.totalDown)
        static let todayUp = Column(CodingKeys.todayUp)
        static let todayDown = Column(CodingKeys.todayDown)
        static let lastUpdate = Column(CodingKeys.lastUpdate)
    }

    // 定义迁移
    static func registerMigrations(in migrator: inout DatabaseMigrator) {
        // 创建表
        migrator.registerMigration("createProfileStatTable") { db in
            try db.create(table: ProfileStatModel.databaseTableName) { t in
                t.column(ProfileStatModel.Columns.uuid.name, .text).notNull().primaryKey()
                t.column(ProfileStatModel.Columns.totalUp.name, .integer).notNull()
                t.column(ProfileStatModel.Columns.totalDown.name, .integer).notNull()
                t.column(ProfileStatModel.Columns.todayUp.name, .integer).notNull()
                t.column(ProfileStatModel.Columns.todayDown.name, .integer).notNull()
                t.column(ProfileStatModel.Columns.lastUpdate.name, .datetime).notNull()
            }
        }
    }

    /// 更新 `profile_stat` 表中指定 `uuid` 的统计数据
    static func update_stat(uuid: String, up: Int, down: Int, lastUpdate: Date) throws {
        // 构建插入或更新的 SQL 语句
        let sql = """
        INSERT INTO profile_stat (uuid, todayUp, todayDown, totalUp, totalDown, lastUpdate)
        VALUES (?, ?, ?, ?, ?, ?)
        ON CONFLICT(uuid) DO UPDATE SET
            todayUp = todayUp + excluded.todayUp,
            todayDown = todayDown + excluded.todayDown,
            totalUp = totalUp + excluded.totalUp,
            totalDown = totalDown + excluded.totalDown,
            lastUpdate = excluded.lastUpdate
        """
        do {
            let dbWriter = AppDatabase.shared.dbWriter
            try dbWriter.write { db in
                // 执行 SQL 语句
                try db.execute(sql: sql, arguments: [uuid, up, down, up, down, lastUpdate])
            }
        } catch {
            print("update_stat error: \(error)")
        }
    }

    /// 清空 `profile_stat` 表中指定 `uuid` 的今日数据
    /// 如果 `lastUpdate` 日期非今天，则将 `todayUp` 和 `todayDown` 清零，并更新 `lastUpdate` 为当前时间
    /// - Parameters:
    ///   - uuid: 唯一标识符
    static func clearTodayData(uuid: String) throws {
        // 获取当前日期的开始时间（00:00:00）
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        do {
            let dbReader = AppDatabase.shared.reader
            return try dbReader.read { db in
                let sql = "SELECT lastUpdate FROM profile_stat WHERE uuid = ?"
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
                                UPDATE profile_stat
                                SET todayUp = 0, todayDown = 0, lastUpdate = ?
                                WHERE uuid = ?
                                """,
                                arguments: [Date(), uuid]
                            )
                        }
                    } catch {
                        print("getFastOne error: \(error)")
                    }
                }
            }
        } catch {
            print("clearTodayData error: \(error)")
            return
        }
    }

    // 清空 `profile_stat` 表中指定 `uuid` 的统计数据
    static func clearAllData(uuid: String) throws {
        do {
            let sql = "UPDATE profile_stat SET todayUp = 0, todayDown = 0, totalUp = 0, totalDown = 0, lastUpdate = ? WHERE uuid = ?"
            let dbWriter = AppDatabase.shared.dbWriter
            return try dbWriter.write { db in
                try db.execute(sql: sql, arguments: [Date(), uuid])
            }
        } catch {
            print("clearAllData error: \(error)")
            return
        }
    }

    func save() {
        do {
            let dbWriter = AppDatabase.shared.dbWriter
            try dbWriter.write { db in
                try self.save(db)
            }
        } catch {
            print("save error: \(error)")
        }
    }
}
