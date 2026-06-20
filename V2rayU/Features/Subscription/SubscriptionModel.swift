//
//  SubscriptionModel.swift
//  V2rayU
//
//  Created by yanue on 2025/11/11.
//

import SwiftUI

// MARK: - UI Model (SwiftUI 绑定)

@MainActor @dynamicMemberLookup
final class SubscriptionModel: ObservableObject, Identifiable {
    @Published var entity: SubscriptionEntity
    let id: String

    init(from entity: SubscriptionEntity) {
        self.id = entity.uuid
        self.entity = entity
    }

    // 动态代理属性访问
    subscript<T>(dynamicMember keyPath: KeyPath<SubscriptionEntity, T>) -> T {
        entity[keyPath: keyPath]
    }

    subscript<T>(dynamicMember keyPath: WritableKeyPath<SubscriptionEntity, T>) -> T {
        get { entity[keyPath: keyPath] }
        set { entity[keyPath: keyPath] = newValue }
    }

    // 转换回 entity
    func toEntity() -> SubscriptionEntity { entity }
}
