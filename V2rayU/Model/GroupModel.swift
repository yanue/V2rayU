//
//  GroupModel.swift
//  V2rayU
//
//  Created by yanue on 2024/12/2.
//
import SwiftUI

class GroupModel: ObservableObject, Identifiable, Hashable {
    static func == (lhs: GroupModel, rhs: GroupModel) -> Bool {
        return lhs.group == rhs.group
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(group) // 使用 group 来计算哈希值
    }

    @Published var name: String = "全部"
    @Published var group: String = ""

    enum CodingKeys: String, CodingKey {
        case name, group
    }

    init(name: String, group: String) {
        self.name = name
        self.group = group
    }

    var id: String { // 提供唯一的标识符
        return group
    }
}

@MainActor let defaultGroup = GroupModel(name: "全部", group: "")
