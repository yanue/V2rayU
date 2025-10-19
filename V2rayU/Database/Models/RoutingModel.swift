//
//  V2rayRouting.swift
//  V2rayU
//
//  Created by yanue on 2024/6/27.
//  Copyright © 2024 yanue. All rights reserved.
//

import SwiftUI
import UniformTypeIdentifiers
import GRDB

// 实现GRDB
struct RoutingDTO: Codable, TableRecord, FetchableRecord, PersistableRecord, Identifiable,  Equatable, Hashable {
    var uuid: String
    var name: String
    var remark: String
    var domainStrategy: String
    var domainMatcher: String
    var block: String
    var proxy: String
    var direct: String
    var sort: Int
    
    var id:String {
        return uuid;
    }
    
    init(uuid:String = UUID().uuidString, name: String, remark: String, domainStrategy: String = "AsIs", domainMatcher: String = "hybrid", block: String = "", proxy: String = "", direct: String = "",sort: Int = 0) {
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

// ----- routing routing item -----
final class RoutingModel: ObservableObject, Identifiable, Codable {
    var index: Int = 0
    @Published var uuid: String
    @Published var name: String
    @Published var remark: String
    @Published var domainStrategy: String
    @Published var domainMatcher: String
    @Published var block: String
    @Published var proxy: String
    @Published var direct: String
    @Published var sort: Int

    var id:  String  {
        return uuid
    }
    
    init(from dto: RoutingDTO) {
           self.uuid = dto.uuid
           self.name = dto.name
           self.remark = dto.remark
           self.domainStrategy = dto.domainStrategy
           self.domainMatcher = dto.domainMatcher
           self.block = dto.block
           self.proxy = dto.proxy
           self.direct = dto.direct
           self.sort = dto.sort
       }

   func toDTO() -> RoutingDTO {
       return RoutingDTO(
           uuid: self.uuid,
           name: self.name,
           remark: self.remark,
           domainStrategy: self.domainStrategy,
           domainMatcher: self.domainMatcher,
           block: self.block,
           proxy: self.proxy,
           direct: self.direct,
           sort: self.sort
       )
   }
    
    // 对应编码的 `CodingKeys` 枚举
    enum CodingKeys: String, CodingKey {
        case uuid, name, remark, domainStrategy, domainMatcher, block, proxy, direct, sort
    }

    // Initializer
    init(uuid:String = UUID().uuidString, name: String, remark: String, domainStrategy: String = "AsIs", domainMatcher: String = "hybrid", block: String = "", proxy: String = "", direct: String = "") {
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

    // 需要手动实现 `init(from:)` 和 `encode(to:)`，如果你使用自定义类型时
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        uuid = try container.decode(String.self, forKey: .uuid)
        name = try container.decode(String.self, forKey: .name)
        remark = try container.decode(String.self, forKey: .remark)
        domainStrategy = try container.decode(String.self, forKey: .domainStrategy)
        domainMatcher = try container.decodeIfPresent(String.self, forKey: .domainMatcher) ?? "AsIs"
        block = try container.decode(String.self, forKey: .block)
        proxy = try container.decode(String.self, forKey: .proxy)
        direct = try container.decode(String.self, forKey: .direct)
        sort = try container.decodeIfPresent(Int.self, forKey: .sort) ?? 0
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(uuid, forKey: .uuid)
        try container.encode(name, forKey: .name)
        try container.encode(remark, forKey: .remark)
        try container.encode(domainStrategy, forKey: .domainStrategy)
        try container.encode(domainMatcher, forKey: .domainMatcher)
        try container.encode(block, forKey: .block)
        try container.encode(proxy, forKey: .proxy)
        try container.encode(direct, forKey: .direct)
        try container.encode(sort, forKey: .sort)
    }
}

// 拖动排序
extension RoutingDTO: Transferable {
    static let draggableType = UTType(exportedAs: "net.yanue.V2rayU")

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: draggableType)
    }
}
