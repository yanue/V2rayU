//
//  ProxyList.swift
//  V2rayU
//
//  Created by yanue on 2024/12/14.
//

import Combine
import Foundation
import GRDB

class ProfileViewModel: ObservableObject {
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

    func delete(uuid: String) {
        Self.delete(uuid: uuid)
        getList()
    }

    func upsert(item: ProfileModel) {
        Self.upsert(item: item)
        getList()
    }

    // MARK: - Static

    // 获取当前正在运行配置
    static func getRunning() -> ProfileModel? {
        var item: ProfileModel?
        // 获取当前运行配置
        let runningProfile = UserDefaults.get(forKey: .runningProfile) ?? ""
        if !runningProfile.isEmpty {
            // 根据uuid获取配置
            item = ProfileViewModel.fetchOne(uuid: runningProfile)
        }
        if item == nil {
            // 没有配置，获取速度最快的配置
            item = ProfileViewModel.getFastOne()
        }
        return item
    }

    static func all() -> [ProfileModel] {
        do {
            let dbReader = AppDatabase.shared.reader
            return try dbReader.read { db in
                try ProfileModel.fetchAll(db)
            }
        } catch {
            print("getList error: \(error)")
            return []
        }
    }

    // filter: ["id": 1,"conlmn":"value"]
    static func count(filter: [String: (any DatabaseValueConvertible)?]?) -> Int {
        do {
            let dbReader = AppDatabase.shared.reader
            return try dbReader.read { db in
                try ProfileModel.filter(key: filter).fetchCount(db)
            }
        } catch {
            print("count error: \(error)")
            return 0
        }
    }

    static func getFastOne() -> ProfileModel? {
        do {
            let dbReader = AppDatabase.shared.reader
            return try dbReader.read { db in
                try ProfileModel.order(ProfileModel.Columns.speed.desc).fetchOne(db)
            }
        } catch {
            print("getFastOne error: \(error)")
            return nil
        }
    }

    static func fetchOne(uuid: String) -> ProfileModel? {
        do {
            let dbReader = AppDatabase.shared.reader
            return try dbReader.read { db in
                try ProfileModel.filter(ProfileModel.Columns.uuid == uuid).fetchOne(db)
            }
        } catch {
            print("fetchOne error: \(error)")
            return nil
        }
    }

    static func delete(uuid: String) {
        do {
            let dbWriter = AppDatabase.shared.dbWriter
            try dbWriter.write { db in
                try ProfileModel.filter(ProfileModel.Columns.uuid == uuid).deleteAll(db)
            }
        } catch {
            print("delete error: \(error)")
        }
    }

    // filter: ["id": 1,"conlmn":"value"]
    static func delete(filter: [String: (any DatabaseValueConvertible)?]?) {
        do {
            let dbWriter = AppDatabase.shared.dbWriter
            try dbWriter.write { db in
                try ProfileModel.filter(key: filter).deleteAll(db)
            }
        } catch {
            print("delete error: \(error)")
        }
    }

    static func update_speed(uuid: String, speed: Int) {
        do {
            let dbWriter = AppDatabase.shared.dbWriter
            try dbWriter.write { db in
                try ProfileModel.filter(ProfileModel.Columns.uuid == uuid).updateAll(db, [ProfileModel.Columns.speed.set(to: 0)])
            }
        } catch {
            print("delete error: \(error)")
        }
    }
    
    static func upsert(item: ProfileModel) {
        do {
            let dbWriter = AppDatabase.shared.dbWriter
            try dbWriter.write { db in
                try item.save(db)
            }
        } catch {
            print("upsert error: \(error)")
        }
    }

    static func insert_many(items: [ProfileModel]) {
        do {
            let dbWriter = AppDatabase.shared.dbWriter
            try dbWriter.write { db in
                try items.forEach { item in
                    try item.save(db)
                }
            }
        } catch {
            print("insert_many error: \(error)")
        }
    }
}
