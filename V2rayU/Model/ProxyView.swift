//
//  ProxyView.swift
//  V2rayU
//
//  Created by yanue on 2024/12/5.
//

@preconcurrency import SQLite
import SwiftUI
import UniformTypeIdentifiers

class ProxyViewModel: DatabaseManager, ObservableObject {
    @Published var list: [ProxyModel] = []
    @Published var groups: [GroupModel] = []
  
    func getList() {
        let conditions: [SQLite.Expression<Bool>] = []
        do {
            list = try fetchAll(model: ProxyModel.self, conditions: conditions)
        } catch {
        }
    }

    func fetchOne(uuid: UUID) throws -> ProxyModel {
        let conditions: [SQLite.Expression<Bool>] = [
            Expression<String>("uuid") == uuid.uuidString,
        ]
        return try fetchOne(model: ProxyModel.self, conditions: conditions)
    }

    func delete(uuid: UUID)  {
        let conditions: [SQLite.Expression<Bool>] = [
            Expression<String>("uuid") == uuid.uuidString,
        ]
        do {
            try delete(model: ProxyModel.self, conditions: conditions)
        } catch {
            
        }
        self.getList()
    }
    
    func upsert(item: ProxyModel) {

        let onConflict: Expressible =  Table(ProxyModel.tableName)[Expression<String>("uuid")]
        do {
            try upsert(model: ProxyModel.self, onConflict: onConflict, insertValues: item.toInsertValues(),setValues: item.toInsertValues())
        } catch {
            print("upsert: \(error)")
        }
        self.getList()
    }
}
