//
//  V2rayRouting.swift
//  V2rayU
//
//  Created by yanue on 2024/6/27.
//  Copyright © 2024 yanue. All rights reserved.
//

import SwiftUI
import UniformTypeIdentifiers


// ----- routing routing item -----
class RoutingModel: ObservableObject, Identifiable, Codable {
    var index: Int = 0
    @Published var uuid: UUID
    @Published var name: String
    @Published var remark: String
    @Published var json: String
    @Published var domainStrategy: String
    @Published var block: String
    @Published var proxy: String
    @Published var direct: String

    // 对应编码的 `CodingKeys` 枚举
    enum CodingKeys: String, CodingKey {
        case uuid, name, remark, json, domainStrategy, block, proxy, direct
    }

    // Initializer
    init(name: String, remark: String, json: String = "", domainStrategy: String = "AsIs", block: String = "", proxy: String = "", direct: String = "") {
        uuid = UUID()
        self.name = name
        self.remark = remark
        self.json = json
        self.domainStrategy = domainStrategy
        self.block = block
        self.proxy = proxy
        self.direct = direct
    }

    // 需要手动实现 `init(from:)` 和 `encode(to:)`，如果你使用自定义类型时
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        uuid = try container.decode(UUID.self, forKey: .uuid)
        name = try container.decode(String.self, forKey: .name)
        remark = try container.decode(String.self, forKey: .remark)
        json = try container.decode(String.self, forKey: .json)
        domainStrategy = try container.decode(String.self, forKey: .domainStrategy)
        block = try container.decode(String.self, forKey: .block)
        proxy = try container.decode(String.self, forKey: .proxy)
        direct = try container.decode(String.self, forKey: .direct)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(uuid, forKey: .uuid)
        try container.encode(name, forKey: .name)
        try container.encode(remark, forKey: .remark)
        try container.encode(json, forKey: .json)
        try container.encode(domainStrategy, forKey: .domainStrategy)
        try container.encode(block, forKey: .block)
        try container.encode(proxy, forKey: .proxy)
        try container.encode(direct, forKey: .direct)
    }
}

extension RoutingModel: Transferable {
    static let draggableType = UTType(exportedAs: "net.yanue.V2rayU")

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: RoutingModel.draggableType)
    }
}
