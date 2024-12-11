//
//  DB.swift
//  V2rayU
//
//  Created by yanue on 2024/12/4.
//

import Foundation
@preconcurrency import SQLite

// 修复 Missing argument label 'value:' in call
typealias Expression = SQLite.Expression

enum DatabaseError: Error {
    case databaseUnavailable
    case recordNotFound
}

protocol DatabaseModel {
    static var tableName: String { get }
    static func initSql() -> String
    static func fromRow(_ row: Row) throws -> Self
    func toInsertValues() -> [Setter]
    // 新增方法：提供主键条件
    func primaryKeyCondition() -> SQLite.Expression<Bool>
}

class DatabaseManager {
    private var db: Connection?

    // 全局写锁
    private static let dbLock = NSLock()

    required init() {
        initDB()
    }

    /// 初始化数据库连接
    /// 此方法尝试建立数据库连接，并设置表格。
    func initDB() {
        do {
            db = try Connection(databasePath)
            print("DatabaseManager", databasePath, db as Any)
        } catch {
            print("数据库初始化失败: \(error)")
            // todo
        }
        do {
            guard let db = db else { throw DatabaseError.databaseUnavailable }
            // 配置 trace 方法
             db.trace { sql in
                 print("Executing SQL: \(sql)")
             }
            // 初始化表格
            try db.execute(ProxyModel.initSql())
        } catch {
            print("数据库初始化失败: \(error)")
        }
    }

    /// 根据条件查询单条记录
    /// - Parameters:
    ///   - model: 一个符合 `DatabaseModel` 协议的模型类型
    ///   - conditions: 过滤查询的条件数组，示例：[Expression<Int64>("id") == id]
    ///   - sort: 一个可选的排序表达式，指定查询结果的排序方式，示例：`Expression<String>("name").desc`
    /// - Returns: 返回类型为 `T` 的单个模型实例
    /// - Throws: 如果没有找到记录，抛出 `DatabaseError.recordNotFound` 错误
    func fetchOne<T: DatabaseModel>(model: T.Type, conditions: [SQLite.Expression<Bool>] = [], sort: Expressible? = nil) throws -> T {
        guard let db = db else { throw DatabaseError.databaseUnavailable }
        var query = Table(T.tableName)
        do {
            // 应用所有过滤条件
            for condition in conditions {
                query = query.filter(condition)
            }
            // 如果提供了排序表达式，应用排序
            if sort != nil {
                query = query.order([sort!])
            }
            if let row = try db.pluck(query) {
                return try T.fromRow(row) // 将查询到的行数据转换为模型类型
            } else {
                throw DatabaseError.recordNotFound // 没有找到记录
            }
        } catch {
            throw error
        }
    }

    /// 根据条件查询所有记录
    /// - Parameters:
    ///   - model: 一个符合 `DatabaseModel` 协议的模型类型
    ///   - conditions: 过滤查询的条件数组，示例：[Expression<Int64>("id") == id]
    ///   - sort: 一个可选的排序表达式，指定查询结果的排序方式，示例：`Expression<String>("name").desc`
    /// - Returns: 返回类型为 `T` 的模型数组
    /// - Throws: 查询过程中可能抛出的任何错误
    func fetchAll<T: DatabaseModel>(model: T.Type, conditions: [SQLite.Expression<Bool>] = [], sort: Expressible? = nil) throws -> [T] {
        guard let db = db else { throw DatabaseError.databaseUnavailable }
        var query = Table(model.tableName)
        do {
            // 应用所有过滤条件
            for condition in conditions {
                query = query.filter(condition)
            }

            // 如果提供了排序表达式，应用排序
            if sort != nil {
                query = query.order([sort!])
            }

            var results: [T] = []
            for row in try db.prepare(query) {
                results.append(try T.fromRow(row)) // 将每一行数据转换为模型类型并添加到结果数组
            }
            return results

        } catch {
            throw error
        }
    }

    /// 插入一条记录
    /// - Parameters:
    ///   - model: 一个符合 `DatabaseModel` 协议的模型类型
    ///   - values: 一个包含 `Setter` 的数组，表示插入的字段值
    /// - Throws: 插入过程中可能抛出的任何错误
    // 插入数据，等待操作完成并抛出错误
    func insert<T: DatabaseModel>(model: T.Type, values: [Setter]) throws {
        guard let db = db else { throw DatabaseError.databaseUnavailable }
        let table = Table(T.tableName)

        DatabaseManager.dbLock.lock() // 加锁
        defer { DatabaseManager.dbLock.unlock() } // 确保锁在操作结束后释放

        do {
            // 使用事务，保证原子性
            try db.transaction {
                let insertQuery = table.insert(values)
                try db.run(insertQuery)
            }
        } catch {
            throw error
        }
    }

    /// 更新一条记录
    /// - Parameters:
    ///   - model: 一个符合 `DatabaseModel` 协议的模型类型
    ///   - conditions: 过滤更新的条件数组，示例：[Expression<Int64>("id") == id]
    ///   - values: 一个包含 `Setter` 的数组，表示更新的字段值
    /// - Throws: 更新过程中可能抛出的任何错误
    func update<T: DatabaseModel>(model: T.Type, conditions: [SQLite.Expression<Bool>] = [], values: [Setter]) throws {
        guard let db = db else { throw DatabaseError.databaseUnavailable }

        DatabaseManager.dbLock.lock() // 加锁
        defer { DatabaseManager.dbLock.unlock() } // 确保锁在操作结束后释放

        do {
            var query = Table(T.tableName)
            // 应用所有条件
            for condition in conditions {
                query = query.filter(condition)
            }
            // 使用事务，保证原子性
            try db.transaction {
                let updateQuery = query.update(values)
                try db.run(updateQuery)
            }
        } catch {
            throw error
        }
    }

    /// 插入或更新一条记录
    /// - Parameters:
    ///   - model: 一个符合 `DatabaseModel` 协议的模型类型
    ///   - onConflict: 用于处理冲突的字段表达式，示例：`Expression<String>("uuid")`
    ///   - insertValues: 用于插入的字段值，包含 `Setter`
    ///   - setValues: 用于更新的字段值，包含 `Setter`
    /// - Throws: 执行过程中可能抛出的任何错误
    func upsert<T: DatabaseModel>(model: T.Type, onConflict: Expressible, values: [Setter]) throws {
        guard let db = db else { throw DatabaseError.databaseUnavailable }

        DatabaseManager.dbLock.lock() // 加锁
        defer { DatabaseManager.dbLock.unlock() } // 确保锁在操作结束后释放

        do {
            let query = Table(T.tableName)
            // 使用事务，保证原子性
            try db.transaction {
                let upsertQuery = query.upsert(values, onConflictOf: onConflict)
                try db.run(upsertQuery)
            }
        } catch {
            throw error
        }
    }

    /// 删除记录
    /// - Parameters:
    ///   - model: 一个符合 `DatabaseModel` 协议的模型类型
    ///   - conditions: 过滤删除的条件数组，示例：[Expression<Int64>("id") == id]
    /// - Throws: 删除过程中可能抛出的任何错误
    func delete<T: DatabaseModel>(model: T.Type, conditions: [SQLite.Expression<Bool>] = []) throws {
        guard let db = db else { throw DatabaseError.databaseUnavailable }

        DatabaseManager.dbLock.lock() // 加锁
        defer { DatabaseManager.dbLock.unlock() } // 确保锁在操作结束后释放

        do {
            var query = Table(T.tableName)
            // 应用所有条件
            for condition in conditions {
                query = query.filter(condition)
            }
            // 使用事务，保证原子性
            try db.transaction {
                let deleteQuery = query.delete()
                try db.run(deleteQuery)
            }
        } catch {
            throw error
        }
    }
}
