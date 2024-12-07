//
//  DB.swift
//  V2rayU
//
//  Created by yanue on 2024/12/4.
//

import Foundation
@preconcurrency import SQLite

enum DatabaseError: Error {
    case databaseUnavailable
    case recordNotFound
}

protocol DatabaseModel {
    static var tableName: String { get }
    static func initSql() -> String
    static func fromRow(_ row: Row) throws -> Self
    func toInsertValues() -> [SQLite.Setter]
    // 新增方法：提供主键条件
    func primaryKeyCondition() -> SQLite.Expression<Bool>
}

actor DatabaseManager {
    private var db: Connection?

    func initDB() {
        do {
            db = try Connection(databasePath)
            print("DatabaseManager", databasePath, db as Any)
        } catch {
            print("Database initialization failed: \(error)")
            // todo
        }
        do {
            guard let db = db else { throw DatabaseError.databaseUnavailable }
            // 初始化表格
            try db.execute(ProxyModel.initSql())
        } catch {
            print("Database Init failed: \(error)")
        }
    }

    /// fetchOne - 根据条件查询单条数据
    /// conditions:
    ///  [
    ///     Expression<Int64>(value: "id") == id,
    ///     Expression<String>(value: "name") == name
    ///  ]
    /// sort: Expression<String>(value: "xxx").desc
    func fetchOne(table: String, conditions: [SQLite.Expression<Bool>] = [], sort: Expressible? = nil) async throws -> Row {
        guard let db = db else { throw DatabaseError.databaseUnavailable }
        var query = Table(table)
        do {
            // 应用所有条件
            for condition in conditions {
                query = query.filter(condition)
            }
            // 应用排序
            if sort != nil {
                query = query.order([sort!])
            }
            if let row = try db.pluck(query) {
                return row
            } else {
                throw DatabaseError.recordNotFound // record not found
            }
        } catch {
            throw error
        }
    }

    /// fetchAll - 根据条件查询全部数据
    /// conditions:
    ///  [
    ///     Expression<Int64>(value: "id") == id,
    ///     Expression<String>(value: "name") == name
    ///  ]
    /// sort: Expression<String>(value: "xxx").desc
    func fetchAll(table: String, conditions: [SQLite.Expression<Bool>] = [], sort: Expressible? = nil) async throws -> [Row] {
        guard let db = db else { throw DatabaseError.databaseUnavailable }
        var query = Table(table)
        do {
            // 应用所有条件
            for condition in conditions {
                query = query.filter(condition)
            }

            // 应用排序
            if sort != nil {
                query = query.order([sort!])
            }

            var results: [Row] = []
            for row in try db.prepare(query) {
                results.append(row)
            }
            return results

        } catch {
            throw error
        }
    }

    func insert(table: String, values: [Setter]) async throws {
        guard let db = db else { throw DatabaseError.databaseUnavailable }
        let table = Table(table)
        do {
            // 使用 SQLite.Setter 构建插入语句
            let insert = table.insert(values)
            try db.run(insert)
        }
    }

    func update(table: String, conditions: [SQLite.Expression<Bool>] = [], values: [Setter]) async throws {
        guard let db = db else { throw DatabaseError.databaseUnavailable }
        var table = Table(table)
        do {
            // 应用所有条件
            for condition in conditions {
                table = table.filter(condition)
            }
            // 构造更新查询，使用 Setter 进行更新
            let updateQuery = table.update(values)
            try db.run(updateQuery)
        }
    }

    func delete(table: String, conditions: [SQLite.Expression<Bool>] = []) async throws {
        guard let db = db else { throw DatabaseError.databaseUnavailable }
        var query = Table(table)
        do {
            // 应用所有条件
            for condition in conditions {
                query = query.filter(condition)
            }
            let deleteQuery = query.delete()
            try db.run(deleteQuery)
        }
    }
}
