//
//  ProxyView.swift
//  V2rayU
//
//  Created by yanue on 2024/12/5.
//

import Combine
import Foundation
import GRDB

class ProxyViewModel: ObservableObject {
    @Published var list: [ProxyModel] = []
    @Published var groups: [GroupModel] = []

    /// Fetches all `ProxyModel` records and updates the `list` property.
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

    /// Fetches a single `ProxyModel` by UUID.
    /// - Parameter uuid: The UUID of the `ProxyModel` to fetch.
    /// - Returns: The fetched `ProxyModel`.
    /// - Throws: An error if the record is not found or the database operation fails.
    func fetchOne(uuid: String) throws -> ProxyModel {
        let dbReader = AppDatabase.shared.reader
        return try dbReader.read { db in
            guard let model = try ProxyModel.filter(Column("uuid") == uuid).fetchOne(db) else {
                throw NSError(domain: "ProxyViewModel", code: 404, userInfo: [NSLocalizedDescriptionKey: "ProxyModel not found for UUID: \(uuid)"])
            }
            return model
        }
    }

    /// Deletes a `ProxyModel` by UUID.
    /// - Parameter uuid: The UUID of the `ProxyModel` to delete.
    func delete(uuid: String) {
        do {
            let dbWriter = AppDatabase.shared.dbWriter
            try dbWriter.write { db in
                try ProxyModel.filter(Column("uuid") == uuid).deleteAll(db)
            }
            getList()
        } catch {
            print("delete error: \(error)")
        }
    }

    /// Inserts or updates a `ProxyModel` in the database.
    /// - Parameter item: The `ProxyModel` to upsert.
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
