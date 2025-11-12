//
//  StoreProtocal.swift
//  V2rayU
//
//  Created by yanue on 2025/11/11.
//

import Foundation
import GRDB

/// 协议：要求 Entity 提供主键列
protocol IdColumnProtocol {
    static var idColumn: Column { get }
}

/// 通用 Store 协议，约束所有 Entity 必须符合 GRDB 的相关协议
protocol StoreProtocol {
    associatedtype Entity: FetchableRecord & PersistableRecord & TableRecord & Identifiable & IdColumnProtocol where Entity.ID: DatabaseValueConvertible
    var dbReader: DatabaseReader { get }
    var dbWriter: DatabaseWriter { get }
}

extension StoreProtocol {
    // MARK: - CRUD

    @discardableResult
    func insert(_ entity: Entity) -> Bool {
        do {
            try dbWriter.write { db in
                try entity.insert(db)
            }
            return true
        } catch {
            logger.error("insert error: \(error)")
            return false
        }
    }

    @discardableResult
    func update(_ entity: Entity) -> Bool {
        do {
            try dbWriter.write { db in
                try entity.update(db)
            }
            return true
        } catch {
            logger.error("update error: \(error)")
            return false
        }
    }

    @discardableResult
    func upsert(_ entity: Entity) -> Bool {
        do {
            try dbWriter.write { db in
                try entity.save(db)
            }
            return true
        } catch {
            logger.error("upsert error: \(error)")
            return false
        }
    }

    @discardableResult
    func delete(uuid: Entity.ID) -> Bool {
        do {
            _ = try dbWriter.write { db in
                try Entity.filter(Entity.idColumn == uuid).deleteAll(db)
            }
            return true
        } catch {
            logger.error("delete error: \(error)")
            return false
        }
    }
    
    // filter: ["id": 1,"conlumn":"value"]
    func delete(filter: [String: (any DatabaseValueConvertible)?]?) {
        guard let filter = filter else { return }
        do {
            _ = try dbWriter.write { db in
                var query = Entity.all()
                for (column, value) in filter {
                    if let value = value {
                        query = query.filter(Column(column) == value)
                    }
                }
                try query.deleteAll(db)
            }
        } catch {
            logger.info("delete error: where=\(filter) error=\(error)")
        }
    }

    // MARK: - Query
    // filter: ["id": 1,"conlumn":"value"]
    func count(filter: [String: (any DatabaseValueConvertible)?]?) -> Int {
        guard let filter = filter else { return 0 }
        do {
            let dbReader = AppDatabase.shared.reader
            return try dbReader.read { db in
                var query = Entity.all()
                for (column, value) in filter {
                    if let value = value {
                        query = query.filter(Column(column) == value)
                    }
                }
                return try query.fetchCount(db)
            }
        } catch {
            logger.info("count error: \(error)")
            return 0
        }
    }
    
    func fetchOne(uuid: Entity.ID) -> Entity? {
        do {
            return try dbReader.read { db in
                try Entity.filter(Entity.idColumn == uuid).fetchOne(db)
            }
        } catch {
            logger.error("fetchOne error: \(error)")
            return nil
        }
    }

    
    func fetchAll() -> [Entity] {
        do {
            return try dbReader.read { db in
                try Entity.fetchAll(db)
            }
        } catch {
            logger.error("fetchAll error: \(error)")
            return []
        }
    }
}
