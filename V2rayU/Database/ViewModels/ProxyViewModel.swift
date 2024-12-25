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
    @Published var list: [ProfileModel] = []
    @Published var groups: [String] = []

    func getList() {
        do {
            let dbReader = AppDatabase.shared.reader
            try dbReader.read { db in
                list = try ProfileModel.fetchAll(db)
            }
        } catch {
            print("getList error: \(error)")
        }
    }

    func all() -> [ProfileModel] {
        do {
            let dbReader = AppDatabase.shared.reader
            return try dbReader.read { db in
                return try ProfileModel.fetchAll(db)
            }
        } catch {
            print("getList error: \(error)")
            return []
        }
    }

    func fetchOne(uuid: String) throws -> ProfileModel {
        let dbReader = AppDatabase.shared.reader
        return try dbReader.read { db in
            guard let model = try ProfileModel.filter(ProfileModel.Columns.uuid == uuid).fetchOne(db) else {
                throw NSError(domain: "ProxyViewModel", code: 404, userInfo: [NSLocalizedDescriptionKey: "ProfileModel not found for uuid: \(uuid)"])
            }
            return model
        }
    }

    func delete(uuid: String) {
        do {
            let dbWriter = AppDatabase.shared.dbWriter
            try dbWriter.write { db in
                try ProfileModel.filter(ProfileModel.Columns.uuid == uuid).deleteAll(db)
            }
            getList()
        } catch {
            print("delete error: \(error)")
        }
    }

    func upsert(item: ProfileModel) {
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
