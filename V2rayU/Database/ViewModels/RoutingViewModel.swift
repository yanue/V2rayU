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
            print("getList error: \(error)")
        }
    }

    func fetchOne(uuid: String) throws -> RoutingModel {
        let dbReader = AppDatabase.shared.reader
        return try dbReader.read { db in
            guard let model = try RoutingModel.filter(RoutingModel.Columns.uuid == uuid).fetchOne(db) else {
                throw NSError(domain: "RoutingModel", code: 404, userInfo: [NSLocalizedDescriptionKey: "RoutingModel not found for uuid: \(uuid)"])
            }
            return model
        }
    }

    func delete(uuid: String) {
        do {
            let dbWriter = AppDatabase.shared.dbWriter
            try dbWriter.write { db in
                try RoutingModel.filter(RoutingModel.Columns.uuid == uuid).deleteAll(db)
            }
            getList()
        } catch {
            print("delete error: \(error)")
        }
    }

    func upsert(item: RoutingModel) {
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
