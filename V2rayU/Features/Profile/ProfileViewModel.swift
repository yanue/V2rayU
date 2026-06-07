//
//  ProxyList.swift
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

    private let store = ProfileStore.shared
    private let subscriptionStore = SubscriptionStore.shared

    init() {
        getList()
    }

    @MainActor
    func getList() {
        list = store.fetchAll()
        computeGroups()
    }

    @MainActor
    private func computeGroups() {
        let subscriptions = subscriptionStore.fetchAll()
        var groupNames: [String: String] = [:]

        for sub in subscriptions {
            groupNames[sub.uuid] = sub.remark.isEmpty ? sub.url : sub.remark
        }

        var uniqueGroups: Set<String> = []
        for profile in list {
            if profile.subid.isEmpty {
                uniqueGroups.insert(String(localized: .DefaultGroup))
            } else if let name = groupNames[profile.subid], !name.isEmpty {
                uniqueGroups.insert(name)
            }
        }

        groups = Array(uniqueGroups).sorted()
    }

    func delete(uuid: String) {
        store.delete(uuid: uuid)
        removeProfileFromCombinedConfigs(uuid: uuid)
        getList()
    }

    private func removeProfileFromCombinedConfigs(uuid: String) {
        CombinedConfigStore.removeProfile(uuid: uuid)
    }

    func upsert(item: ProfileEntity) {
        store.upsert(item)
        getList()
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
        }

        getList()
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
