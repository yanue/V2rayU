//
//  ProxyList.swift
//  V2rayU
//
//  Created by yanue on 2024/12/14.
//

import Combine
import GRDB
import Foundation

class ProxyViewModel: ObservableObject {
    @Published var list: [ProxyModel] = []
    @Published var groups: [GroupModel] = []

    func getList() {
        do {
            let dbReader = AppDatabase.shared.reader
            try dbReader.read { db in
                list = try ProxyModel.fetchAll(db)
            }
        } catch {
            print("getList error: \(error)")
        }
    }

    func fetchOne(uuid: String) throws -> ProxyModel {
        let dbReader = AppDatabase.shared.reader
        return try dbReader.read { db in
            guard let model = try ProxyModel.filter(ProxyModel.Columns.uuid == uuid).fetchOne(db) else {
                throw NSError(domain: "ProxyViewModel", code: 404, userInfo: [NSLocalizedDescriptionKey: "ProxyModel not found for uuid: \(uuid)"])
            }
            return model
        }
    }

    func delete(uuid: String) {
        do {
            let dbWriter = AppDatabase.shared.dbWriter
            try dbWriter.write { db in
                try ProxyModel.filter(ProxyModel.Columns.uuid == uuid).deleteAll(db)
            }
            getList()
        } catch {
            print("delete error: \(error)")
        }
    }

    func upsert(item: ProxyModel) {
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
