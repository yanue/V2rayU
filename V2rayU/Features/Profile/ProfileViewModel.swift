//
//  ProfileViewModel.swift
//  V2rayU
//
//  Created by yanue on 2024/12/14.
//

import Combine
import Foundation
import GRDB

@MainActor
final class ProfileViewModel: ObservableObject {
    @Published var list: [ProfileEntity] = []
    @Published var groups: [String] = []
    /// 预计算的分组名称映射：profile.uuid → 分组显示名。
    /// 在 getList() 中一次性构建，后续过滤/排序无需逐条查询数据库。
    @Published var groupNameMap: [String: String] = [:]

    private let store = ProfileStore.shared
    private let subscriptionStore = SubscriptionStore.shared

    init() {
        getList()
    }

    @MainActor
    func getList() {
        // 批量查询订阅和服务器列表，后续不再逐条查询数据库
        let subscriptions = subscriptionStore.fetchAll()
        let subNameLookup: [String: String] = Dictionary(
            subscriptions.map { ($0.uuid, $0.remark.isEmpty ? $0.url : $0.remark) },
            uniquingKeysWith: { first, _ in first }
        )

        list = store.fetchAll()

        // 构建 groupNameMap，替代旧的逐条 SubscriptionStore.fetchOne 查询
        var map: [String: String] = [:]
        var uniqueGroups: Set<String> = []
        let defaultGroup = String(localized: .DefaultGroup)
        for profile in list {
            if profile.subid.isEmpty {
                map[profile.uuid] = defaultGroup
                uniqueGroups.insert(defaultGroup)
            } else if let name = subNameLookup[profile.subid], !name.isEmpty {
                map[profile.uuid] = name
                uniqueGroups.insert(name)
            } else {
                map[profile.uuid] = profile.subid
                uniqueGroups.insert(profile.subid)
            }
        }
        groupNameMap = map
        groups = Array(uniqueGroups).sorted()
    }

    func delete(uuid: String) {
        store.delete(uuid: uuid)
        if uuid == AppState.shared.runningProfile {
            AppState.shared.runningProfile = ""
            AppState.shared.runningServer = nil
        }
        removeProfileFromCombinedConfigs(uuid: uuid)
        getList()
    }

    private func removeProfileFromCombinedConfigs(uuid: String) {
        CombinedConfigStore.removeProfile(uuid: uuid)
    }

    func upsert(item: ProfileEntity) {
        store.upsert(item)
        getList()
        AppMenuManager.shared.refreshServerItems()
    }

    func updateSortOrderInDBAsync() {
        store.updateSortOrder(list)
        getList()
    }

    func removeDuplicates() -> Int {
        var seen = Set<String>()
        var toDelete: [String] = []

        for item in list {
            let key = "\(item.protocol):\(item.address):\(item.password):\(item.port):\(item.network):\(item.host):\(item.path)"
            if seen.contains(key) {
                toDelete.append(item.uuid)
            } else {
                seen.insert(key)
            }
        }

        for uuid in toDelete {
            store.delete(uuid: uuid)
            if uuid == AppState.shared.runningProfile {
                AppState.shared.runningProfile = ""
                AppState.shared.runningServer = nil
            }
            CombinedConfigStore.removeProfile(uuid: uuid)
        }

        getList()
        AppMenuManager.shared.refreshServerItems()
        return toDelete.count
    }
}

@MainActor
final class CombinedConfigViewModel: ObservableObject {
    @Published var list: [CombinedConfigEntity] = []
    @Published var profiles: [ProfileEntity] = []

    private let store = CombinedConfigStore.shared

    init() {
        getList()
    }

    func getList() {
        list = store.fetchAll()
        profiles = ProfileStore.shared.fetchAll()
    }

    func upsert(item: CombinedConfigEntity) {
        var item = item
        item.lastUpdate = Date()
        store.upsert(item)
        getList()
        AppMenuManager.shared.refreshCombinedConfigItems()
    }

    func delete(uuid: String) {
        store.delete(uuid: uuid)
        if AppState.shared.runningCombination == uuid {
            AppState.shared.runningCombination = ""
        }
        getList()
        AppMenuManager.shared.refreshCombinedConfigItems()
    }

    func updateSortOrderInDB() {
        store.updateSortOrder(list)
        getList()
        AppMenuManager.shared.refreshCombinedConfigItems()
    }
}
