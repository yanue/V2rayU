//
//  RoutingViewModel.swift
//  V2rayU
//
//  Created by yanue on 2024/12/14.
//

import Foundation
import Combine

/// 管理 RoutingEntity 列表的 UI 状态
@MainActor
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
        delete(uuids: [uuid])
    }

    /// 批量删除: 一个事务删完, 列表只重新加载一次, 菜单只刷新一次
    func delete(uuids: [String]) {
        guard !uuids.isEmpty else { return }
        store.delete(uuids: uuids)
        getList()
        AppMenuManager.shared.refreshRoutingItems()
    }

    func upsert(item: RoutingModel) {
        store.upsert(item.toEntity())
        getList()
        AppMenuManager.shared.refreshRoutingItems()
    }

    func updateSortOrderInDBAsync() {
        store.updateSortOrder(list)
        getList()
        AppMenuManager.shared.refreshRoutingItems()
    }
}
