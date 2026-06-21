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
        if deleteServers {
            let profiles = ProfileStore.shared.getGroupProfiles(subid: uuid)
            for profile in profiles {
                ProfileStore.shared.delete(uuid: profile.uuid)
            }
            if !profiles.isEmpty {
                let uuids = profiles.map(\.uuid)
                Task { @MainActor in
                    uuids.forEach { CombinedConfigStore.removeProfile(uuid: $0) }
                }
            }
        }
        store.delete(uuid: uuid)
        getList()
    }

    func upsert(item: SubscriptionEntity) {
        store.upsert(item)
        getList()
    }

    func updateSortOrderInDBAsync() {
        store.updateSortOrder(list)
        getList()
    }
}
