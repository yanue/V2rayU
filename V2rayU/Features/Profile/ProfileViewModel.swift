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
        getList()
    }

    func upsert(item: ProfileEntity) {
        store.upsert(item)
        getList()
    }

    func updateSortOrderInDBAsync() {
        store.updateSortOrder(list)
        getList()
    }
}
