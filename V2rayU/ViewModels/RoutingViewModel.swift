//
//  Routing.swift
//  V2rayU
//
//  Created by yanue on 2024/12/14.
//

import Foundation
import Combine

/// 管理 RoutingEntity 列表的 UI 状态


/// 管理 RoutingEntity 列表的 UI 状态
final class RoutingViewModel: ObservableObject {
    @Published var list: [RoutingEntity] = []

    private let store = RoutingStore()

    init() {
        getList()
    }

    // MARK: - Public API

    func getList() {
        list =  store.fetchAll()
    }

    func delete(uuid: String) {
        store.delete(uuid: uuid)
        getList()
    }

    func upsert(item: RoutingModel) {
        store.upsert(item.toEntity())
        getList()
    }

    func updateSortOrderInDBAsync() {
        store.updateSortOrder(list)
        getList()
    }
}
