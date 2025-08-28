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
    
    @Published var list: [RoutingModel] = []
    
    func getList() {
        do {
            let dbReader = AppDatabase.shared.reader
            try dbReader.read { db in
                list = try RoutingModel.fetchAll(db)
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
    
    static func all() -> [RoutingModel] {
        do {
            let dbReader = AppDatabase.shared.reader
            return try dbReader.read { db in
                return try RoutingModel.fetchAll(db)
            }
        } catch {
            logger.info("getList error: \(error)")
            return []
        }
    }
    
    static func fetchOne(uuid: String) throws -> RoutingModel {
        let dbReader = AppDatabase.shared.reader
        return try dbReader.read { db in
            guard let model = try RoutingModel.filter(RoutingModel.Columns.uuid == uuid).fetchOne(db) else {
                throw NSError(domain: "RoutingModel", code: 404, userInfo: [NSLocalizedDescriptionKey: "RoutingModel not found for uuid: \(uuid)"])
            }
            return model
        }
    }
 
    static func delete(uuid: String) {
        do {
            let dbWriter = AppDatabase.shared.dbWriter
            try dbWriter.write { db in
                try _ = RoutingModel.filter(RoutingModel.Columns.uuid == uuid).deleteAll(db)
            }
        } catch {
            logger.info("delete error: \(error)")
        }
    }
    
    static func upsert(item: RoutingModel) {
        do {
            let dbWriter = AppDatabase.shared.dbWriter
            try dbWriter.write { db in
                try item.save(db)
            }
        } catch {
            logger.info("upsert error: \(error)")
        }
    }
}
