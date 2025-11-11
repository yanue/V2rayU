//
//  SubscriptionModel.swift
//  V2rayU
//
//  Created by yanue on 2025/11/11.
//

import SwiftUI

// MARK: - UI Model (SwiftUI 绑定)

@dynamicMemberLookup
final class SubscriptionModel: ObservableObject, Identifiable {
    @Published var entity: SubscriptionEntity

    var id: String { entity.uuid }

    init(from entity: SubscriptionEntity) { self.entity = entity }

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
