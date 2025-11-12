//
//  SubList.swift
//  V2rayU
//
//  Created by yanue on 2024/12/14.
//

import Combine
import Foundation
import GRDB

class SubscriptionViewModel: ObservableObject {
    @Published var list: [SubscriptionEntity] = []
    private let store = SubscriptionStore()

    func getList() {
        list = store.fetchAll()
    }

    func delete(uuid: String) {
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
