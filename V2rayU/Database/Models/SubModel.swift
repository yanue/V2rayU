//
//  SubModel.swift
//  V2rayU
//
//  Created by yanue on 2024/12/2.
//

import GRDB
import SwiftUI
import UniformTypeIdentifiers

// MARK: - DTO (数据库层)

struct SubDTO: Codable, Identifiable, Equatable, Hashable, Transferable, TableRecord, FetchableRecord, PersistableRecord {
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

// MARK: - UI Model (SwiftUI 绑定)

@dynamicMemberLookup
final class SubModel: ObservableObject, Identifiable {
    @Published var dto: SubDTO

    var id: String { dto.uuid }

    init(from dto: SubDTO) { self.dto = dto }

    // 动态代理属性访问
    subscript<T>(dynamicMember keyPath: KeyPath<SubDTO, T>) -> T {
        dto[keyPath: keyPath]
    }

    subscript<T>(dynamicMember keyPath: WritableKeyPath<SubDTO, T>) -> T {
        get { dto[keyPath: keyPath] }
        set { dto[keyPath: keyPath] = newValue }
    }

    // 转换回 DTO
    func toDTO() -> SubDTO { dto }
}
