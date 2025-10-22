//
//  V2rayRouting.swift
//  V2rayU
//
//  Created by yanue on 2024/6/27.
//  Copyright © 2024 yanue. All rights reserved.
//

import GRDB
import SwiftUI
import UniformTypeIdentifiers

// 实现GRDB
struct RoutingDTO: Codable, Identifiable, Equatable, Hashable, Transferable, TableRecord, FetchableRecord, PersistableRecord {
    var uuid: String
    var name: String
    var remark: String
    var domainStrategy: String
    var domainMatcher: String
    var block: String
    var proxy: String
    var direct: String
    var sort: Int

    var id: String {
        return uuid
    }

    // 拖动排序
    static let draggableType = UTType(exportedAs: "net.yanue.V2rayU")
    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: draggableType)
    }

    // 对应编码的 `CodingKeys` 枚举
    enum CodingKeys: String, CodingKey {
        case uuid, name, remark, domainStrategy, domainMatcher, block, proxy, direct, sort
    }

    init(uuid: String = UUID().uuidString, name: String, remark: String, domainStrategy: String = "AsIs", domainMatcher: String = "hybrid", block: String = "", proxy: String = "", direct: String = "", sort: Int = 0) {
        self.uuid = uuid
        self.name = name
        self.remark = remark
        self.domainStrategy = domainStrategy
        self.domainMatcher = domainMatcher
        self.block = block
        self.proxy = proxy
        self.direct = direct
        self.sort = 0
    }

    // 自定义表名
    static var databaseTableName: String {
        return "routing" // 设置你的表名
    }

    // 定义数据库列
    enum Columns {
        static let uuid = Column(CodingKeys.uuid)
        static let name = Column(CodingKeys.name)
        static let remark = Column(CodingKeys.remark)
        static let domainStrategy = Column(CodingKeys.domainStrategy)
        static let domainMatcher = Column(CodingKeys.domainMatcher)
        static let block = Column(CodingKeys.block)
        static let proxy = Column(CodingKeys.proxy)
        static let direct = Column(CodingKeys.direct)
        static let sort = Column(CodingKeys.sort)
    }

    // 定义迁移
    static func registerMigrations(in migrator: inout DatabaseMigrator) {
        // 创建表
        migrator.registerMigration("createRoutingTable") { db in
            try db.create(table: databaseTableName) { t in
                t.column(Columns.uuid.name, .text).notNull().primaryKey()
                t.column(Columns.name.name, .text).notNull()
                t.column(Columns.remark.name, .text).notNull()
                t.column(Columns.domainStrategy.name, .text).notNull()
                t.column(Columns.block.name, .text).notNull()
                t.column(Columns.proxy.name, .text).notNull()
                t.column(Columns.direct.name, .text).notNull()
            }
        }
        // 创建domainMatcher字段
        migrator.registerMigration("addDomainMatcherToRouting") { db in
            try db.alter(table: databaseTableName) { t in
                t.add(column: Columns.domainMatcher.name, .text).notNull().defaults(to: "hybrid")
            }
        }
        // 创建sort字段
        migrator.registerMigration("addSortToRouting") { db in
            try db.alter(table: databaseTableName) { t in
                t.add(column: "sort", .integer).notNull().defaults(to: 0)
            }
        }
    }
}

// MARK: - UI Model (SwiftUI 绑定)

@dynamicMemberLookup
final class RoutingModel: ObservableObject, Identifiable {
    @Published var dto: RoutingDTO
    var id: String { dto.uuid }

    init(from dto: RoutingDTO) {
        self.dto = dto
    }

    // 动态代理属性访问
    subscript<T>(dynamicMember keyPath: KeyPath<RoutingDTO, T>) -> T {
        dto[keyPath: keyPath]
    }

    subscript<T>(dynamicMember keyPath: WritableKeyPath<RoutingDTO, T>) -> T {
        get { dto[keyPath: keyPath] }
        set { dto[keyPath: keyPath] = newValue }
    }

    // 转换回 DTO
    func toDTO() -> RoutingDTO { dto }
}
