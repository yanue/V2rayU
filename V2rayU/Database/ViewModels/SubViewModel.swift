//
//  SubList.swift
//  V2rayU
//
//  Created by yanue on 2024/12/14.
//

import Combine
import Foundation
import GRDB

class SubViewModel: ObservableObject {
    @Published var list: [SubDTO] = []

    func getList() {
        do {
            let dbReader = AppDatabase.shared.reader
            try dbReader.read { db in
                let items = try SubDTO.fetchAll(db)
                self.list = items
            }
        } catch {
            logger.info("getList error: \(error)")
        }
    }

    func delete(uuid: String) {
        Self.delete(uuid: uuid)
        getList()
    }

    func upsert(item: SubDTO) {
        Self.upsert(item: item)
        getList()
    }

    // MARK: - Static

    func all() -> [SubDTO] {
        do {
            let dbReader = AppDatabase.shared.reader
            return try dbReader.read { db in
                // 先取出结果（fetch）成数组，才能在 for-in 里使用。
                try SubDTO.all().fetchAll(db)
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
            return SubModel(from: model)
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

    static func upsert(item: SubDTO) {
        do {
            let dbWriter = AppDatabase.shared.dbWriter
            try dbWriter.write { db in
                try item.save(db)
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
