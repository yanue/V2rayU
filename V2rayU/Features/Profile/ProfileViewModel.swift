//
//  ProfileViewModel.swift
//  V2rayU
//
//  Created by yanue on 2024/12/14.
//

import Combine
import Foundation
import GRDB

/// 服务器列表数据有变化(导入、订阅同步、测速、切换服务器等)。
/// 由 AppMenuManager.refreshServerItems() 统一发出, 菜单栏和服务器窗口列表据此保持一致
let NOTIFY_PROFILES_CHANGED = Notification.Name(rawValue: "NOTIFY_PROFILES_CHANGED")

@MainActor
final class ProfileViewModel: ObservableObject {
    @Published var list: [ProfileEntity] = []
    @Published var groups: [String] = []
    /// 预计算的分组名称映射：profile.uuid → 分组显示名。
    /// 在 getList() 中一次性构建，后续过滤/排序无需逐条查询数据库。
    @Published var groupNameMap: [String: String] = [:]

    private let store = ProfileStore.shared
    private let subscriptionStore = SubscriptionStore.shared
    private var cancellables = Set<AnyCancellable>()

    init() {
        getList()
        // 主窗口会复用, 列表不会重新创建; 导入/订阅同步后跟着菜单一起刷新 (#1684)
        // receive(on:) 让刷新放到下一轮主循环, 不在菜单/弹窗回调过程中替换表格数据
        NotificationCenter.default.publisher(for: NOTIFY_PROFILES_CHANGED)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.getList() }
            .store(in: &cancellables)
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
        delete(uuids: [uuid])
    }

    /// 批量删除: 一个事务删完, 列表只重新加载一次, 菜单只刷新一次。
    /// 逐条删除时每条都会 getList() 让表格反复重载, 菜单也不刷新, 点到已删除的服务器会出错 (#1674)
    func delete(uuids: [String]) {
        guard !uuids.isEmpty else { return }
        store.delete(uuids: uuids)
        if uuids.contains(AppState.shared.runningProfile) {
            AppState.shared.runningProfile = ""
            AppState.shared.runningServer = nil
        }
        // 从组合配置中移除, 内部会刷新菜单栏服务器列表
        CombinedConfigStore.removeProfiles(uuids: Set(uuids))
        getList()
    }

    func upsert(item: ProfileEntity) {
        store.upsert(item)
        getList()
        AppMenuManager.shared.refreshServerItems()
    }

    func updateSortOrderInDBAsync() {
        store.updateSortOrder(list)
        getList()
        AppMenuManager.shared.refreshServerItems()
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

        delete(uuids: toDelete)
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
