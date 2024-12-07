//
//  ProxyView.swift
//  V2rayU
//
//  Created by yanue on 2024/12/5.
//

@preconcurrency import SQLite
import SwiftUI
import UniformTypeIdentifiers

class ProxyViewModel {
    var list: [ProxyModel] = []
    var groups: [GroupModel] = []

    func getList(selectGroup: String) async {
        var conditions: [SQLite.Expression<Bool>] = []
        if selectGroup != "" {
            conditions.append(Expression<String>("subid") == selectGroup)
        }
        do {
            let fetchedData = try await dbManager.fetchAll(table: "proxy", conditions: conditions)
            // Ensure thread-safe access to _list
            var _list: [ProxyModel] = []
            for row in fetchedData {
                do {
                    let object = try ProxyModel.fromRow(row)
                    _list.append(object)
                } catch {
                    print("Error parsing row: \(error)")
                }
            }
            self.list = _list
        } catch {
            print("Error fetching data: \(error)")
        }
    }
}
