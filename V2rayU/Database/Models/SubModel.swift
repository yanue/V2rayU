//
//  SubModel.swift
//  V2rayU
//
//  Created by yanue on 2024/12/2.
//

import SwiftUI
import UniformTypeIdentifiers
import GRDB

class SubModel: @unchecked Sendable, ObservableObject, Identifiable, Codable, Hashable {
    var index: Int = 0
    @Published var uuid: String
    @Published var remark: String
    @Published var url: String
    @Published var enable: Bool
    @Published var sort: Int
    @Published var updateInterval: Int // 分钟
    @Published var updateTime: Int
    
    var id:String {
        return uuid;
    }
    // 对应编码的 `CodingKeys` 枚举
    enum CodingKeys: String, CodingKey {
        case uuid, remark, url, enable, sort, updateInterval, updateTime
    }
    
    // 如果要作为字典的 key，需要实现 Hashable
    static func == (lhs: SubModel, rhs: SubModel) -> Bool {
        lhs.id == rhs.id
    }
   
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    // 提供默认值的初始化器
    init(uuid: String = UUID().uuidString,remark: String, url: String, enable: Bool = true, sort: Int = 0, updateInterval: Int = 60, updateTime: Int = 0) {
        self.uuid = uuid
        self.remark = remark
        self.url = url
        self.enable = enable
        self.sort = sort
        self.updateInterval = updateInterval
        self.updateTime = updateTime
    }

    // 需要手动实现 `init(from:)` 和 `encode(to:)`，如果你使用自定义类型时
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        uuid = try container.decode(String.self, forKey: .uuid)
        remark = try container.decode(String.self, forKey: .remark)
        url = try container.decode(String.self, forKey: .url)
        enable = try container.decode(Bool.self, forKey: .enable)
        sort = try container.decode(Int.self, forKey: .sort)
        updateInterval = try container.decode(Int.self, forKey: .updateInterval)
        updateTime = try container.decode(Int.self, forKey: .updateTime)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(uuid, forKey: .uuid)
        try container.encode(remark, forKey: .remark)
        try container.encode(url, forKey: .url)
        try container.encode(sort, forKey: .sort)
        try container.encode(enable, forKey: .enable)
        try container.encode(updateInterval, forKey: .updateInterval)
        try container.encode(updateTime, forKey: .updateTime)
    }
}

// 拖动排序
extension SubModel: Transferable {
    static let draggableType = UTType(exportedAs: "net.yanue.V2rayU")

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: SubModel.draggableType)
    }
}

// 实现GRDB
extension SubModel: TableRecord, FetchableRecord, PersistableRecord  {
    // 自定义表名
    static var databaseTableName: String {
        return "sub" // 设置你的表名
    }
    
    // 定义数据库列
    enum Columns {
        static let uuid = Column(CodingKeys.uuid)
        static let remark = Column(CodingKeys.remark)
        static let url = Column(CodingKeys.url)
        static let sort = Column(CodingKeys.sort)
        static let enable = Column(CodingKeys.enable)
        static let updateInterval = Column(CodingKeys.updateInterval)
        static let updateTime = Column(CodingKeys.updateTime)
    }
    
    // 定义迁移
    static func registerMigrations(in migrator: inout DatabaseMigrator) {
        // 创建表
        migrator.registerMigration("createSubTable") { db in
            try db.create(table: SubModel.databaseTableName) { t in
                t.column(SubModel.Columns.uuid.name, .text).notNull().primaryKey()
                t.column(SubModel.Columns.url.name, .text).notNull().defaults(to: "")
                t.column(SubModel.Columns.remark.name, .text).defaults(to: "")
                t.column(SubModel.Columns.sort.name, .integer).notNull().defaults(to: 0)
                t.column(SubModel.Columns.enable.name, .integer).notNull().defaults(to: 1)
                t.column(SubModel.Columns.updateInterval.name, .integer).notNull().defaults(to: 0)
                t.column(SubModel.Columns.updateTime.name, .integer).notNull().defaults(to: 0)

            }
        }
    }
}
