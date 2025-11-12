//
//  SubscriptionModel.swift
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

    var id: String {
        return uuid
    }
    static var idColumn: Column { RoutingEntity.Columns.uuid }

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
        updateTime: Int = Int(Date().timeIntervalSince1970)
    ) {
        self.uuid = uuid
        self.remark = remark
        self.url = url
        self.enable = enable
        self.sort = sort
        self.updateInterval = updateInterval
        self.updateTime = updateTime
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
    }
}

extension SubscriptionEntity {
    func upsert() {
        do {
            var toSave = self
            // 如果 updateInterval 为 0，默认设置为 3600
            if toSave.updateInterval == 0 {
                toSave.updateInterval = 3600
            }
            
            let dbWriter = AppDatabase.shared.dbWriter
            try dbWriter.write { db in
                try toSave.save(db)
            }
        } catch {
            logger.info("upsert error: \(error)")
        }
        
        // 更新后，触发订阅更新任务调度
        Task {
            await SubscriptionScheduler.shared.startOrUpdate(for: self)
        }
    }
}
