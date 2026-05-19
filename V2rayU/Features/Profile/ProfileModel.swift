//
//  ProfileModel.swift
//  V2rayU
//
//  Created by yanue on 2025/11/11.
//

import SwiftUI

@dynamicMemberLookup
final class ProfileModel: ObservableObject, Identifiable {
    @Published var entity: ProfileEntity
    @Published var selectedProtocol: V2rayProtocolOutbound
    var id: String { entity.uuid }

    init(from entity: ProfileEntity) {
        self.entity = entity
        self.selectedProtocol = entity.protocol
    }

    subscript<T>(dynamicMember keyPath: KeyPath<ProfileEntity, T>) -> T {
        entity[keyPath: keyPath]
    }

    subscript<T>(dynamicMember keyPath: WritableKeyPath<ProfileEntity, T>) -> T {
        get { entity[keyPath: keyPath] }
        set {
            entity[keyPath: keyPath] = newValue
            if keyPath == \ProfileEntity.protocol {
                selectedProtocol = entity.protocol
            }
            objectWillChange.send()
        }
    }

    func toEntity() -> ProfileEntity { entity }

    func clone() -> ProfileModel {
        ProfileModel(from: self.toEntity())
    }
}
