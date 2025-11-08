//
//  JsonAny.swift
//  V2rayU
//
//  Created by yanue on 2025/7/21.
//

// JSONAny 用于支持任意 JSON 类型的编码
struct JSONAny: Codable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let v = try? container.decode(Bool.self) { value = v; return }
        if let v = try? container.decode(Int.self) { value = v; return }
        if let v = try? container.decode(Double.self) { value = v; return }
        if let v = try? container.decode(String.self) { value = v; return }
        if let v = try? container.decode([JSONAny].self) { value = v.map { $0.value }; return }
        if let v = try? container.decode([String: JSONAny].self) { value = v.mapValues { $0.value }; return }
        throw DecodingError.dataCorruptedError(in: container, debugDescription: "无法解码 JSONAny")
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let v as Bool: try container.encode(v)
        case let v as Int: try container.encode(v)
        case let v as Double: try container.encode(v)
        case let v as String: try container.encode(v)
        case let v as [Any]: try container.encode(v.map { JSONAny($0) })
        case let v as [String: Any]: try container.encode(v.mapValues { JSONAny($0) })
        default: throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: encoder.codingPath, debugDescription: "无法编码 JSONAny"))
        }
    }
}
