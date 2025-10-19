//
//  SubList.swift
//  V2rayU
//
//  Created by yanue on 2024/12/14.
//

import Combine
import GRDB
import Foundation

class SubViewModel: ObservableObject {
    @Published var list: [SubDTO] = []

    func getList() {
        do {
            let dbReader = AppDatabase.shared.reader
            try dbReader.read { db in
                let items = try SubDTO.fetchAll(db)
//                var list: [SubModel] = []
//                for item in items{
//                    list.append(SubModel(from: item))
//                }
                self.list = items
            }
        } catch {
            logger.info("getList error: \(error)")
        }
    }
    
    func delete(uuid: String) {
        Self.delete(uuid: uuid)
        self.getList()
    }
    
    func upsert(item: SubModel) {
        Self.upsert(item: item)
        self.getList()
    }
    
    /// Mark: - Static

    func all() -> [SubDTO] {
        do {
            let dbReader = AppDatabase.shared.reader
            try dbReader.read { db in
                return try SubDTO.fetchAll(db)
            }
        } catch {
            logger.info("getList error: \(error)")
        }
        return []
    }
    
    static func fetchOne(uuid: String) throws -> SubModel {
        let dbReader = AppDatabase.shared.reader
        return try dbReader.read { db in
            guard let model = try SubDTO.filter(SubDTO.Columns.uuid == uuid).fetchOne(db) else {
                throw NSError(domain: "SubModel", code: 404, userInfo: [NSLocalizedDescriptionKey: "ProfileModel not found for uuid: \(uuid)"])
            }
            return SubModel.init(from: model)
        }
    }

    static func delete(uuid: String) {
        do {
            let dbWriter = AppDatabase.shared.dbWriter
            try dbWriter.write { db in
                try _ = SubDTO.filter(SubDTO.Columns.uuid == uuid).deleteAll(db)
            }
        } catch {
            logger.info("delete error: \(error)")
        }
    }

    static func upsert(item: SubModel) {
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
                    try item.update(db, columns: [SubDTO.Columns.sort]) // Update the database
                }
            }
        } catch {
            logger.info("updateSortOrderInDBAsync error: \(error)")
        }
    }
}
