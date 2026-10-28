//
//  SubscriptionEntity.swift
//  V2rayU
//
//  Created by yanue on 2024/12/2.
//

import GRDB
import SwiftUI
import UniformTypeIdentifiers

// MARK: - entity (数据库层)

struct SubscriptionEntity: Codable, Identifiable, Equatable, Hashable, Transferable, TableRecord, FetchableRecord, PersistableRecord, IdColumnProtocol {
    var uuid: String
    var remark: String
    var url: String
    var enable: Bool
    var sort: Int
    var updateInterval: Int
    var updateTime: Int
    var notes: String
    var configType: String

    var id: String {
        return uuid
    }
    static var idColumn: Column { SubscriptionEntity.Columns.uuid }

    // 拖动排序
    static let draggableType = UTType(exportedAs: "net.yanue.V2rayU")
    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: draggableType)
    }

    init(
        uuid: String = UUID().uuidString,
        remark: String = "",
        url: String = "",
        enable: Bool = true,
        sort: Int = 0,
        updateInterval: Int = 3600,
        updateTime: Int = Int(Date().timeIntervalSince1970),
        notes: String = "",
        configType: String = ""
    ) {
        self.uuid = uuid
        self.remark = remark
        self.url = url
        self.enable = enable
        self.sort = sort
        self.updateInterval = updateInterval
        self.updateTime = updateTime
        self.notes = notes
        self.configType = configType
    }

    // 自定义表名
    static var databaseTableName: String { "sub" }

    enum Columns {
        static let uuid = Column(CodingKeys.uuid)
        static let remark = Column(CodingKeys.remark)
        static let url = Column(CodingKeys.url)
        static let enable = Column(CodingKeys.enable)
        static let sort = Column(CodingKeys.sort)
        static let updateInterval = Column(CodingKeys.updateInterval)
        static let updateTime = Column(CodingKeys.updateTime)
        static let notes = Column(CodingKeys.notes)
        static let configType = Column(CodingKeys.configType)
    }

    // 定义迁移
    static func registerMigrations(in migrator: inout DatabaseMigrator) {
        // 创建表
        migrator.registerMigration("createSubTable") { db in
            try db.create(table: databaseTableName) { t in
                t.column(Columns.uuid.name, .text).notNull().primaryKey()
                t.column(Columns.url.name, .text).notNull().defaults(to: "")
                t.column(Columns.remark.name, .text).defaults(to: "")
                t.column(Columns.sort.name, .integer).notNull().defaults(to: 0)
                t.column(Columns.enable.name, .integer).notNull().defaults(to: 1)
                t.column(Columns.updateInterval.name, .integer).notNull().defaults(to: 0)
                t.column(Columns.updateTime.name, .integer).notNull().defaults(to: 0)
            }
        }

        // 添加 notes 和 configType 列
        migrator.registerMigration("addNotesAndConfigTypeToSub") { db in
            try db.alter(table: databaseTableName) { t in
                t.add(column: Columns.notes.name, .text).notNull().defaults(to: "")
                t.add(column: Columns.configType.name, .text).notNull().defaults(to: "")
            }
        }
    }
}

extension SubscriptionEntity {
    func upsert() {
        var toSave = self
        toSave.remark = toSave.remark.trimmingCharacters(in: .whitespacesAndNewlines)
        toSave.url = toSave.url.trimmingCharacters(in: .whitespacesAndNewlines)
        toSave.notes = toSave.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        // 更新周期: <=0 用默认 1 小时, 过大截到上限
        toSave.updateInterval = SubscriptionScheduler.normalizedInterval(toSave.updateInterval)
        do {
            
            let dbWriter = AppDatabase.shared.dbWriter
            try dbWriter.write { db in
                try toSave.save(db)
            }
        } catch {
            logger.error("upsert error: \(error)")
        }
        
        // 更新后，触发订阅更新任务调度(用校正后的值)
        Task { [toSave] in
            await SubscriptionScheduler.shared.startOrUpdate(for: toSave)
        }
    }

    /// 同步成功后只更新 updateTime / configType；订阅已被删除时不做任何事 (#1668)
    static func markSynced(uuid: String, configType: String) {
        do {
            _ = try AppDatabase.shared.dbWriter.write { db in
                try SubscriptionEntity
                    .filter(Columns.uuid == uuid)
                    .updateAll(db,
                               Columns.updateTime.set(to: Int(Date().timeIntervalSince1970)),
                               Columns.configType.set(to: configType))
            }
        } catch {
            logger.error("markSynced error: \(error)")
        }
    }
}
