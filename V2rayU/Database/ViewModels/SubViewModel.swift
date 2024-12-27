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
    @Published var list: [SubModel] = []

    func getList() {
        do {
            let dbReader = AppDatabase.shared.reader
            try dbReader.read { db in
                list = try SubModel.fetchAll(db)
            }
        } catch {
            print("getList error: \(error)")
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

    static func all() -> [SubModel] {
        do {
            let dbReader = AppDatabase.shared.reader
            return try dbReader.read { db in
                return try SubModel.fetchAll(db)
            }
        } catch {
            print("getList error: \(error)")
            return []
        }
    }
    
    static func fetchOne(uuid: String) throws -> SubModel {
        let dbReader = AppDatabase.shared.reader
        return try dbReader.read { db in
            guard let model = try SubModel.filter(SubModel.Columns.uuid == uuid).fetchOne(db) else {
                throw NSError(domain: "SubModel", code: 404, userInfo: [NSLocalizedDescriptionKey: "ProfileModel not found for uuid: \(uuid)"])
            }
            return model
        }
    }

    static func delete(uuid: String) {
        do {
            let dbWriter = AppDatabase.shared.dbWriter
            try dbWriter.write { db in
                try SubModel.filter(SubModel.Columns.uuid == uuid).deleteAll(db)
            }
        } catch {
            print("delete error: \(error)")
        }
    }

    static func upsert(item: SubModel) {
        do {
            let dbWriter = AppDatabase.shared.dbWriter
            try dbWriter.write { db in
                try item.save(db)
            }
        } catch {
            print("upsert error: \(error)")
        }
    }
}
