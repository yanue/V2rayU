//
//  ProxyList.swift
//  V2rayU
//
//  Created by yanue on 2024/12/14.
//

import Combine
import Foundation
import GRDB

final class ProfileViewModel: ObservableObject {
    @Published var list: [ProfileEntity] = []
    @Published var groups: [String] = []

    private let store = ProfileStore.shared
    
    init() {
        getList()
    }

    func getList() {
        list = store.fetchAll()
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
