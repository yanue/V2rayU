//
//  SubModel.swift
//  V2rayU
//
//  Created by yanue on 2024/12/2.
//

import SwiftUI
import UniformTypeIdentifiers

class SubModel: ObservableObject, Identifiable, Codable {
    var index: Int = 0
    @Published var uuid: UUID
    @Published var remark: String
    @Published var url: String
    @Published var enable: Bool
    @Published var sort: Int
    @Published var updateInterval: Int // 分钟
    @Published var updateTime: Int

    // 对应编码的 `CodingKeys` 枚举
    enum CodingKeys: String, CodingKey {
        case uuid, remark, url, enable, sort, updateInterval, updateTime
    }

    // 提供默认值的初始化器
    init(remark: String, url: String, enable: Bool = true, sort: Int = 0, updateInterval: Int = 60, updateTime: Int = 0) {
        uuid = UUID()
        self.remark = remark
        self.url = url
        self.enable = enable
        self.sort = sort
        self.updateInterval = updateInterval
        self.updateTime = updateTime
    }

    // 需要手动实现 `init(from:)` 和 `encode(to:)`，如果你使用自定义类型时
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        uuid = try container.decode(UUID.self, forKey: .uuid)
        remark = try container.decode(String.self, forKey: .remark)
        url = try container.decode(String.self, forKey: .url)
        enable = try container.decode(Bool.self, forKey: .enable)
        sort = try container.decode(Int.self, forKey: .sort)
        updateInterval = try container.decode(Int.self, forKey: .updateInterval)
        updateTime = try container.decode(Int.self, forKey: .updateTime)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(uuid, forKey: .uuid)
        try container.encode(remark, forKey: .remark)
        try container.encode(url, forKey: .url)
        try container.encode(sort, forKey: .sort)
        try container.encode(enable, forKey: .enable)
        try container.encode(updateInterval, forKey: .updateInterval)
        try container.encode(updateTime, forKey: .updateTime)
    }
}

extension SubModel: Transferable {
    static let draggableType = UTType(exportedAs: "net.yanue.V2rayU")

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: SubModel.draggableType)
    }
}
