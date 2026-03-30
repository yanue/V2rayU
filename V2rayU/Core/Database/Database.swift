//
//  DB.swift
//  V2rayU
//
//  Created by yanue on 2024/12/4.
//

import Foundation
import GRDB
import os.log

// db 实例 
final class AppDatabase: Sendable {
    /// Access to the database.
    ///
    /// See <https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/databaseconnections>
    let dbWriter: any DatabaseWriter

    /// Creates a `AppDatabase`, and makes sure the database schema
    /// is ready.
    ///
    /// - important: Create the `DatabaseWriter` with a configuration
    ///   returned by ``makeConfiguration(_:)``.
    init(_ dbWriter: any GRDB.DatabaseWriter) throws {
        self.dbWriter = dbWriter
        try migrator.migrate(dbWriter)
    }
}

extension AppDatabase {
    /// The database for the application
    static let shared = makeShared()

    private static func makeShared() -> AppDatabase {
        do {
            // Apply recommendations from
            // <https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/databaseconnections>

            let config = AppDatabase.makeConfiguration()

            let db = try DatabaseQueue(path: databasePath, configuration: config)

            // Create the AppDatabase
            let appDatabase = try AppDatabase(db)

            return appDatabase
        } catch {
            // 尝试删除损坏的数据库文件并重建
            logger.error("Database init failed: \(error). Attempting to recreate database.")
            do {
                let fm = FileManager.default
                if fm.fileExists(atPath: databasePath) {
                    // 备份旧数据库
                    let backupPath = databasePath + ".bak"
                    try? fm.removeItem(atPath: backupPath)
                    try? fm.moveItem(atPath: databasePath, toPath: backupPath)
                }
                // 重新创建
                let config = AppDatabase.makeConfiguration()
                let db = try DatabaseQueue(path: databasePath, configuration: config)
                let appDatabase = try AppDatabase(db)
                logger.info("Database recreated successfully after corruption.")
                return appDatabase
            } catch {
                fatalError("Failed to recreate database after corruption: \(error)")
            }
        }
    }
}

// MARK: - Database Configuration

extension AppDatabase {
    // Uncomment for enabling SQL logging
    private static let sqlLogger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "SQL")

    /// Returns a database configuration suited for `AppDatabase`.
    ///
    /// - parameter config: A base configuration.
    static func makeConfiguration(_ config: Configuration = Configuration()) -> Configuration {
        var config = config

        // Uncomment for enabling SQL logging if the `SQL_TRACE` environment variable is set.
        // See <https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/database/trace(options:_:)>
        if ProcessInfo.processInfo.environment["SQL_TRACE"] != nil {
            config.prepareDatabase { db in
                let dbName = db.description
                db.trace { event in
                    // Sensitive information (statement arguments) is not
                    // logged unless config.publicStatementArguments is set
                    // (see below).
                    sqlLogger.debug("\(dbName): \(event)")
                }
            }
        }

        #if DEBUG
            config.publicStatementArguments = true
        #endif

        return config
    }
}

// MARK: - Database Access: Reads

extension AppDatabase {
    /// Provides a read-only access to the database.
    var reader: any GRDB.DatabaseReader {
        dbWriter
    }
}
