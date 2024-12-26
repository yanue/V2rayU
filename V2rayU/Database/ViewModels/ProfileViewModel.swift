//
//  ProxyList.swift
//  V2rayU
//
//  Created by yanue on 2024/12/14.
//

import Combine
import GRDB
import Foundation

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

    static func all() -> [ProfileModel] {
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

    // 获取当前正在运行配置
    static func getRunning() -> RoutingModel? {
        var item: RoutingModel?
        // 获取当前运行配置
        let runningProfile = UserDefaults.get(forKey: .runningProfile) ?? ""
        if !runningProfile.isEmpty {
            // 根据uuid获取配置
            item = ProfileViewModel().fetchOne(uuid: runningProfile)
        }
        if item == nil {
            // 没有配置，获取速度最快的配置
            item = ProfileViewModel.getFastOne()
        }
        return item
    }

    static func getFastOne() -> RoutingModel? {
        do {
            let dbReader = AppDatabase.shared.reader
            return try dbReader.read { db in
                return try RoutingModel.filter().orderBy(RoutingModel.Columns.speed, .desc).fetchOne(db)
            }
        } catch {
            print("getOne error: \(error)")
            return nil
        }
    }

    func fetchOne(uuid: String) throws -> ProfileModel {
        let dbReader = AppDatabase.shared.reader
        return try dbReader.read { db in
            guard let model = try ProfileModel.filter(ProfileModel.Columns.uuid == uuid).fetchOne(db) else {
                throw NSError(domain: "ProfileViewModel", code: 404, userInfo: [NSLocalizedDescriptionKey: "ProfileModel not found for uuid: \(uuid)"])
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
