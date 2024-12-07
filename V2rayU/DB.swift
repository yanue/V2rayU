//
//  DB.swift
//  V2rayU
//
//  Created by yanue on 2024/12/4.
//

import Foundation
@preconcurrency import SQLite

nonisolated(unsafe) let dbManager = DatabaseManager()

let init_sql = """

"""

enum DatabaseError: Error {
    case databaseUnavailable
}

protocol DatabaseModel {
    static var tableName: String { get }
    static func initSql() -> String
    static func fromRow(_ row: Row) throws -> Self
    func toInsertValues() -> [String: SQLite.Setter]
    // 新增方法：提供主键条件
    func primaryKeyCondition() -> SQLite.Expression<Bool>
}

class DatabaseManager {
    private var db: Connection?

    func initDB () {
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

    func getConntion() -> Connection {
        return self.db!
    }
    
    func executeSQL(_ sql: String) async throws {
        guard let db = db else { throw DatabaseError.databaseUnavailable }
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global().async {
                do {
                    try db.execute(sql)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func delete<T: DatabaseModel>(modelType: T.Type, matching condition: SQLite.Expression<Bool>) async throws {
        guard let db = db else { throw DatabaseError.databaseUnavailable }
        let table = Table(T.tableName)
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global().async {
                do {
                    let deleteQuery = table.filter(condition).delete()
                    try db.run(deleteQuery)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func insert<T: DatabaseModel>(_ model: T) async throws {
        guard let db = db else { throw DatabaseError.databaseUnavailable }
        let table = Table(T.tableName)
        let values = model.toInsertValues()
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global().async {
                do {
                    // 使用 SQLite.Setter 构建插入语句
                    let insert = table.insert(values.map { _, value in
                        value // 直接使用 Setter
                    })

                    try db.run(insert)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func update<T: DatabaseModel>(_ model: T, matching condition: SQLite.Expression<Bool>) async throws {
        guard let db = db else { throw DatabaseError.databaseUnavailable }
        let table = Table(T.tableName)
        let setters = model.toInsertValues().map { _, value in
            value // 直接使用 Setter
        }
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global().async {
                do {
                    // 构造更新查询，使用 Setter 进行更新
                    let updateQuery = table.filter(condition).update(setters)
                    try db.run(updateQuery)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func fetchOne<T: DatabaseModel>(model: T.Type, matching condition: SQLite.Expression<Bool>) async throws -> T? {
        guard let db = db else { throw DatabaseError.databaseUnavailable }
        let table = Table(T.tableName)
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global().async {
                do {
                    if let row = try db.pluck(table.filter(condition)) {
                        let object = try T.fromRow(row)
                        continuation.resume(returning: object)
                    } else {
                        continuation.resume(returning: nil)
                    }
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func fetchAll(table: String, conditions: [SQLite.Expression<Bool>] = [],order: [Expressible] = []) async throws -> [Row] {
        guard let db = db else { throw DatabaseError.databaseUnavailable }
        let table = Table(table)
        
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global().async {
                do {
                    var query = table
                    
                    // 应用所有条件
                    for condition in conditions {
                        query = query.filter(condition)
                    }
                    
                    // 应用排序
                    if !order.isEmpty {
                        query = query.order(order)
                    }
                    
                    var results: [Row] = []
                    for row in try db.prepare(query) {
                        results.append(row)
                    }
                    
                    continuation.resume(returning: results)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
