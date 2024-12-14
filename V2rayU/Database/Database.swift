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
            // MARK: TODO

            fatalError("Unresolved error \(error)")
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
