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

    func fetchOne(uuid: String) throws -> SubModel {
        let dbReader = AppDatabase.shared.reader
        return try dbReader.read { db in
            guard let model = try SubModel.filter(SubModel.Columns.uuid == uuid).fetchOne(db) else {
                throw NSError(domain: "SubModel", code: 404, userInfo: [NSLocalizedDescriptionKey: "ProxyModel not found for uuid: \(uuid)"])
            }
            return model
        }
    }

    func delete(uuid: String) {
        do {
            let dbWriter = AppDatabase.shared.dbWriter
            try dbWriter.write { db in
                try SubModel.filter(SubModel.Columns.uuid == uuid).deleteAll(db)
            }
            getList()
        } catch {
            print("delete error: \(error)")
        }
    }

    func upsert(item: SubModel) {
        do {
            let dbWriter = AppDatabase.shared.dbWriter
            try dbWriter.write { db in
                try item.save(db)
            }
            getList()
        } catch {
            print("upsert error: \(error)")
        }
    }
}
