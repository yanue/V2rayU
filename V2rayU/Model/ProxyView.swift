//
//  ProxyView.swift
//  V2rayU
//
//  Created by yanue on 2024/12/5.
//

@preconcurrency import SQLite
import SwiftUI
import UniformTypeIdentifiers

class ProxyViewModel {
    var list: [ProxyModel] = []
    var groups: [GroupModel] = []

    func getList(selectGroup: String) async {
        var conditions: [SQLite.Expression<Bool>] = []
        if selectGroup != "" {
            conditions.append(Expression<String>(value: "subid") == selectGroup)
        }
        do {
            let fetchedData = try await dbManager.fetchAll(table: "proxy", conditions: conditions)
            // Ensure thread-safe access to _list
            var _list: [ProxyModel] = []
            for row in fetchedData {
                do {
                    let object = try ProxyModel.fromRow(row)
                    _list.append(object)
                } catch {
                    print("Error parsing row: \(error)")
                }
            }
            list = _list
        } catch {
            print("Error fetching data: \(error)")
        }
    }

    func fetchOne(uuid: UUID) async throws -> ProxyModel {
        let conditions: [SQLite.Expression<Bool>] = []
        do {
            let fetchedData = try await dbManager.fetchOne(table: "proxy", conditions: conditions)
            // Ensure thread-safe access to _list
            let object = try ProxyModel.fromRow(fetchedData)
            return object
        }
    }

    func delete(uuid: UUID) async throws {
        let conditions: [SQLite.Expression<Bool>] = []
        do {
            try await dbManager.delete(table: "proxy", conditions: conditions)
        }
    }
    
    actor ValuesHandler {
        private var values: [SQLite.Setter] = []

        // 添加新的值到 values 中
        func appendValue(_ value: SQLite.Setter) {
            values.append(value)
        }

        // 获取所有 values
        func getValues() -> [SQLite.Setter] {
            return values
        }
    }

    func insert(item: ProxyModel) async throws {
        let valuesHandler = ValuesHandler() // 创建 actor 实例

        // 获取要插入的值
        let tmp = item.toInsertValues()

        // 确保 values 在 actor 中进行修改
        for value in tmp {
            await valuesHandler.appendValue(value) // 异步安全地修改 values
        }

        // 获取修改后的值
        let values = await valuesHandler.getValues()

        // 执行数据库插入操作
//        try await dbManager.insert(table: "proxy", values: values)
    }

    func update(item: ProxyModel) async throws {
        let conditions: [SQLite.Expression<Bool>] = []
        var values: [SQLite.Setter] = []
//        let tmp = item.toInsertValues()
//        for item in tmp {
//            values.append(item)
//        }
        do {
            try await dbManager.update(table: "proxy", conditions: conditions, values: values)
        }
    }
}
