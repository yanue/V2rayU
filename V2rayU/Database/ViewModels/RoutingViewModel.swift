//
//  Routing.swift
//  V2rayU
//
//  Created by yanue on 2024/12/14.
//


import Combine
import GRDB
import Foundation

class RoutingViewModel: ObservableObject {
    
    @Published var list: [RoutingDTO] = []
    
    func getList() {
        do {
            let dbReader = AppDatabase.shared.reader
            try dbReader.read { db in
                list = try RoutingDTO.fetchAll(db)
            }
        } catch {
            logger.info("getList error: \(error)")
        }
    }
    
    func delete(uuid: String) {
        Self.delete(uuid: uuid)
        self.getList()
    }
    
    func upsert(item: RoutingModel) {
        Self.upsert(item: item)
        self.getList()
    }
    
    /// Mark: - Static
    
    static func all() -> [RoutingDTO] {
        do {
            let dbReader = AppDatabase.shared.reader
            return try dbReader.read { db in
                return try RoutingDTO.fetchAll(db)
            }
        } catch {
            logger.info("getList error: \(error)")
            return []
        }
    }
    
    static func fetchOne(uuid: String) throws -> RoutingDTO {
        let dbReader = AppDatabase.shared.reader
        return try dbReader.read { db in
            guard let model = try RoutingDTO.filter(RoutingDTO.Columns.uuid == uuid).fetchOne(db) else {
                throw NSError(domain: "RoutingModel", code: 404, userInfo: [NSLocalizedDescriptionKey: "RoutingModel not found for uuid: \(uuid)"])
            }
            return model
        }
    }
 
    static func delete(uuid: String) {
        do {
            let dbWriter = AppDatabase.shared.dbWriter
            try dbWriter.write { db in
                try _ = RoutingDTO.filter(RoutingDTO.Columns.uuid == uuid).deleteAll(db)
            }
        } catch {
            logger.info("delete error: \(error)")
        }
    }
    
    static func upsert(item: RoutingModel) {
        do {
            let dbWriter = AppDatabase.shared.dbWriter
            try dbWriter.write { db in
                try item.toDTO().save(db)
            }
        } catch {
            logger.info("upsert error: \(error)")
        }
    }
    
    func updateSortOrderInDBAsync() {
        do {
            let dbWriter = AppDatabase.shared.dbWriter
            try dbWriter.write { db in
                for var (index, item) in list.enumerated() {
                    item.sort = index // Update the sort order in memory
                    try item.update(db, columns: [RoutingDTO.Columns.sort]) // Update the database
                }
            }
        } catch {
            logger.info("updateSortOrderInDBAsync error: \(error)")
        }
    }
}
