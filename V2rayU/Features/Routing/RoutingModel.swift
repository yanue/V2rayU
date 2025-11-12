//
//  RoutingModel.swift
//  V2rayU
//
//  Created by yanue on 2025/11/11.
//

import SwiftUI

// MARK: - UI Model (SwiftUI 绑定)

@dynamicMemberLookup
final class RoutingModel: ObservableObject, Identifiable {
    @Published var entity: RoutingEntity
    var id: String { entity.uuid }

    init(from entity: RoutingEntity) {
        self.entity = entity
    }

    subscript<T>(dynamicMember keyPath: KeyPath<RoutingEntity, T>) -> T {
        entity[keyPath: keyPath]
    }

    subscript<T>(dynamicMember keyPath: WritableKeyPath<RoutingEntity, T>) -> T {
        get { entity[keyPath: keyPath] }
        set { entity[keyPath: keyPath] = newValue }
    }

    func toEntity() -> RoutingEntity { entity }
}
