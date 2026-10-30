//
//  SubscriptionUserInfo.swift
//  V2rayU
//
//  机场在订阅响应头 subscription-userinfo 里返回流量用量和到期时间:
//  subscription-userinfo: upload=1234; download=5678; total=10737418240; expire=1700000000
//

import Foundation

struct SubscriptionUserInfo: Equatable {
    static let headerField = "subscription-userinfo"

    /// 已上传字节
    var upload: Int = 0
    /// 已下载字节
    var download: Int = 0
    /// 总流量字节, 0 表示未知 / 不限
    var total: Int = 0
    /// 到期时间 (unix 秒), 0 表示未知 / 永久
    var expire: Int = 0

    var used: Int { upload + download }
    var hasTraffic: Bool { total > 0 || used > 0 }
    var hasExpire: Bool { expire > 0 }
    var isEmpty: Bool { !hasTraffic && !hasExpire }

    /// 已用比例 0~1, 总量未知时为 nil
    var usedRatio: Double? {
        guard total > 0 else { return nil }
        return min(1, max(0, Double(used) / Double(total)))
    }

    var isExpired: Bool {
        expire > 0 && TimeInterval(expire) < Date().timeIntervalSince1970
    }

    /// 解析响应头, 没有该头或一个字段都解析不出时返回 nil
    static func parse(response: URLResponse?) -> SubscriptionUserInfo? {
        guard let http = response as? HTTPURLResponse,
              let value = http.value(forHTTPHeaderField: headerField) else { return nil }
        return parse(header: value)
    }

    static func parse(header: String) -> SubscriptionUserInfo? {
        var info = SubscriptionUserInfo()
        var found = false
        for part in header.split(separator: ";") {
            let pair = part.split(separator: "=", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            guard pair.count == 2, let number = parseNumber(pair[1]) else { continue }
            switch pair[0].lowercased() {
            case "upload": info.upload = number
            case "download": info.download = number
            case "total": info.total = number
            case "expire": info.expire = number
            default: continue
            }
            found = true
        }
        return found ? info : nil
    }

    /// 有的面板返回小数或科学计数法 (如 1.5e10), 都按整数字节处理; 负数当 0
    private static func parseNumber(_ text: String) -> Int? {
        if let int = Int(text) { return max(0, int) }
        guard let double = Double(text), double.isFinite else { return nil }
        return Int(min(max(0, double), Double(Int.max / 2)))
    }

    // MARK: - 显示

    /// 机场面板按 1024 进制算 GB, 这里保持一致
    static func formatBytes(_ bytes: Int) -> String {
        formatBytesFixed(Double(bytes), base: 1024)
    }

    /// "已用 / 总量", 总量未知时只显示已用
    var trafficText: String {
        guard hasTraffic else { return "-" }
        if total > 0 {
            return "\(Self.formatBytes(used)) / \(Self.formatBytes(total))"
        }
        return Self.formatBytes(used)
    }

    var expireText: String {
        guard hasExpire else { return "-" }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date(timeIntervalSince1970: TimeInterval(expire)))
    }

    /// 距到期天数 (向上取整, 不足一天算一天), 已过期为负或 0; 没有到期时间为 nil
    var daysLeft: Int? {
        guard hasExpire else { return nil }
        return Int(((TimeInterval(expire) - Date().timeIntervalSince1970) / 86400).rounded(.up))
    }
}
