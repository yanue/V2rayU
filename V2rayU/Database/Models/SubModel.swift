//
//  SubModel.swift
//  V2rayU
//
//  Created by yanue on 2024/12/2.
//

import SwiftUI
import UniformTypeIdentifiers
import GRDB

// MARK: - DTO (数据库层)
struct SubDTO: Codable, TableRecord, FetchableRecord, PersistableRecord, Identifiable,  Equatable, Hashable {
    var uuid: String
    var remark: String
    var url: String
    var enable: Bool
    var sort: Int
    var updateInterval: Int
    var updateTime: Int

    var id:String {
        return uuid;
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

// 拖动排序
extension SubDTO: Transferable {
    static let draggableType = UTType(exportedAs: "net.yanue.V2rayU")

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: draggableType)
    }
}

// MARK: - UI Model (SwiftUI 绑定)
final class SubModel: ObservableObject, Identifiable {
    @Published var uuid: String
    @Published var remark: String
    @Published var url: String
    @Published var enable: Bool
    @Published var sort: Int
    @Published var updateInterval: Int
    @Published var updateTime: Int

    var id:String {
        return uuid;
    }
    
    init(from dto: SubDTO) {
        self.uuid = dto.uuid
        self.remark = dto.remark
        self.url = dto.url
        self.enable = dto.enable
        self.sort = dto.sort
        self.updateInterval = dto.updateInterval
        self.updateTime = dto.updateTime
    }

    func toDTO() -> SubDTO {
        SubDTO (
            uuid: uuid,
            remark: remark,
            url: url,
            enable: enable,
            sort: sort,
            updateInterval: updateInterval,
            updateTime: updateTime
        )
    }
}
