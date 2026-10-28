//
//  SubscriptionViewModel.swift
//  V2rayU
//
//  Created by yanue on 2024/12/14.
//

import Combine
import Foundation
import GRDB

@MainActor
class SubscriptionViewModel: ObservableObject {
    @Published var list: [SubscriptionEntity] = []
    private let store = SubscriptionStore()

    func getList() {
        list = store.fetchAll()
    }

    func delete(uuid: String, deleteServers: Bool = false) {
        delete(uuids: [uuid], deleteServers: deleteServers)
    }

    /// 批量删除: 订阅和其下服务器各用一个事务删完, 列表只重新加载一次, 菜单只刷新一次
    func delete(uuids: [String], deleteServers: Bool = false) {
        guard !uuids.isEmpty else { return }
        // 先停止这些订阅的自动同步定时器，防止 timer 回调用 upsert 重新插入已删除的订阅
        Task {
            for uuid in uuids {
                await SubscriptionScheduler.shared.stop(for: uuid)
            }
        }

        if deleteServers {
            let profileUUIDs = uuids.flatMap { ProfileStore.shared.getGroupProfiles(subid: $0) }.map(\.uuid)
            if !profileUUIDs.isEmpty {
                ProfileStore.shared.delete(uuids: profileUUIDs)
                if profileUUIDs.contains(AppState.shared.runningProfile) {
                    AppState.shared.runningProfile = ""
                    AppState.shared.runningServer = nil
                }
                CombinedConfigStore.removeProfiles(uuids: Set(profileUUIDs))
            }
        }
        store.delete(uuids: uuids)
        getList()
        // 同时会通知服务器窗口列表刷新
        AppMenuManager.shared.refreshServerItems()
    }

    func upsert(item: SubscriptionEntity) {
        store.upsert(item)
        getList()
        AppMenuManager.shared.refreshServerItems()
    }

    func updateSortOrderInDBAsync() {
        store.updateSortOrder(list)
        getList()
    }
}
