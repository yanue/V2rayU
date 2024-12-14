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

// ----- routing routing item -----
class RoutingModel: ObservableObject, Identifiable, Codable {
    var index: Int = 0
    @Published var uuid: String
    @Published var name: String
    @Published var remark: String
    @Published var json: String
    @Published var domainStrategy: String
    @Published var block: String
    @Published var proxy: String
    @Published var direct: String
    var id:  String  {
        return uuid
    }
    // 对应编码的 `CodingKeys` 枚举
    enum CodingKeys: String, CodingKey {
        case uuid, name, remark, json, domainStrategy, block, proxy, direct
    }

    // Initializer
    init(uuid:String = UUID().uuidString, name: String, remark: String, json: String = "", domainStrategy: String = "AsIs", block: String = "", proxy: String = "", direct: String = "") {
        self.uuid = uuid
        self.name = name
        self.remark = remark
        self.json = json
        self.domainStrategy = domainStrategy
        self.block = block
        self.proxy = proxy
        self.direct = direct
    }

    // 需要手动实现 `init(from:)` 和 `encode(to:)`，如果你使用自定义类型时
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        uuid = try container.decode(String.self, forKey: .uuid)
        name = try container.decode(String.self, forKey: .name)
        remark = try container.decode(String.self, forKey: .remark)
        json = try container.decode(String.self, forKey: .json)
        domainStrategy = try container.decode(String.self, forKey: .domainStrategy)
        block = try container.decode(String.self, forKey: .block)
        proxy = try container.decode(String.self, forKey: .proxy)
        direct = try container.decode(String.self, forKey: .direct)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(uuid, forKey: .uuid)
        try container.encode(name, forKey: .name)
        try container.encode(remark, forKey: .remark)
        try container.encode(json, forKey: .json)
        try container.encode(domainStrategy, forKey: .domainStrategy)
        try container.encode(block, forKey: .block)
        try container.encode(proxy, forKey: .proxy)
        try container.encode(direct, forKey: .direct)
    }
}

// 拖动排序
extension RoutingModel: Transferable {
    static let draggableType = UTType(exportedAs: "net.yanue.V2rayU")

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: RoutingModel.draggableType)
    }
}

// 实现GRDB
extension RoutingModel: TableRecord, FetchableRecord, PersistableRecord  {
    // 自定义表名
    static var databaseTableName: String {
        return "routing" // 设置你的表名
    }
    
    // 定义数据库列
    enum Columns {
        static let uuid = Column(CodingKeys.uuid)
        static let name = Column(CodingKeys.name)
        static let remark = Column(CodingKeys.remark)
        static let json = Column(CodingKeys.json)
        static let domainStrategy = Column(CodingKeys.domainStrategy)
        static let block = Column(CodingKeys.block)
        static let proxy = Column(CodingKeys.proxy)
        static let direct = Column(CodingKeys.direct)
    }
    
    // 定义迁移
    static func registerMigrations(in migrator: inout DatabaseMigrator) {
        // 创建表
        migrator.registerMigration("createRoutingTable") { db in
            try db.create(table: RoutingModel.databaseTableName) { t in
                t.column(RoutingModel.Columns.uuid.name, .text).notNull().primaryKey()
                t.column(RoutingModel.Columns.name.name, .text).notNull()
                t.column(RoutingModel.Columns.remark.name, .text).notNull()
                t.column(RoutingModel.Columns.json.name, .text).notNull()
                t.column(RoutingModel.Columns.domainStrategy.name, .text).notNull()
                t.column(RoutingModel.Columns.block.name, .text).notNull()
                t.column(RoutingModel.Columns.proxy.name, .text).notNull()
                t.column(RoutingModel.Columns.direct.name, .text).notNull()

            }
        }
    }
}
