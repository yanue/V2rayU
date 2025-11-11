//
//  RoutingStore.swift
//  V2rayU
//
//  Created by yanue on 2025/11/11.
//

import Foundation
import GRDB

/// 封装 RoutingEntity 的数据库操作
struct RoutingStore: StoreProtocol {
    typealias Entity = RoutingEntity

    static let shared = RoutingStore()

    // 协议要求的属性
    let dbReader: DatabaseReader = AppDatabase.shared.reader
    let dbWriter: DatabaseWriter = AppDatabase.shared.dbWriter

    // MARK: - Sort
    @discardableResult
    func updateSortOrder(_ entities: [Entity]) -> Bool {
        do {
            try dbWriter.write { db in
                for (index, var entity) in entities.enumerated() {
                    entity.sort = index
                    try entity.update(db, columns: [Entity.Columns.sort])
                }
            }
            return true
        } catch {
            logger.error("RoutingStore.updateSortOrder error: \(error)")
            return false
        }
    }
}
