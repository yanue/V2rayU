//
//  TrafficHistoryStore.swift
//  V2rayU
//
//  每个节点每天的上传 / 下载流量, 给概览页的历史流量图用
//

import Foundation
import GRDB

struct TrafficDaily: Codable, FetchableRecord, PersistableRecord, Equatable {
    var profileUuid: String
    /// yyyy-MM-dd (本地时区)
    var day: String
    var up: Int64
    var down: Int64

    static var databaseTableName: String { "traffic_daily" }

    static func registerMigrations(in migrator: inout DatabaseMigrator) {
        migrator.registerMigration("createTrafficDaily") { db in
            try db.create(table: databaseTableName, ifNotExists: true) { t in
                t.column("profileUuid", .text).notNull()
                t.column("day", .text).notNull()
                t.column("up", .integer).notNull().defaults(to: 0)
                t.column("down", .integer).notNull().defaults(to: 0)
                t.primaryKey(["profileUuid", "day"])
            }
            try db.create(index: "traffic_daily_day", on: databaseTableName, columns: ["day"], ifNotExists: true)
        }
    }
}

/// 一个时间桶的合计
struct TrafficBucket: Identifiable, Equatable {
    var id: String { key }
    /// 桶的 key: 天 yyyy-MM-dd / 月 yyyy-MM / 年 yyyy
    let key: String
    let start: Date
    let up: Int64
    let down: Int64
}

enum TrafficPeriod: String, CaseIterable, Identifiable {
    case live, days30, months12, all
    var id: String { rawValue }
}

struct TrafficHistoryStore {
    static let shared = TrafficHistoryStore()

    static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func dayKey(_ date: Date) -> String { dayFormatter.string(from: date) }

    /// 在已有的写事务里累加, 和 profile 表的累计一起提交
    static func add(db: Database, profileUuid: String, up: Int, down: Int, at date: Date) throws {
        guard up > 0 || down > 0 else { return }
        try db.execute(sql: """
            INSERT INTO traffic_daily (profileUuid, day, up, down) VALUES (?, ?, ?, ?)
            ON CONFLICT(profileUuid, day) DO UPDATE SET up = up + excluded.up, down = down + excluded.down
            """, arguments: [profileUuid, dayKey(date), max(0, up), max(0, down)])
    }

    /// 有历史记录的节点 uuid
    func profileUuids(reader: any DatabaseReader = AppDatabase.shared.reader) -> [String] {
        (try? reader.read { db in
            try String.fetchAll(db, sql: "SELECT DISTINCT profileUuid FROM traffic_daily")
        }) ?? []
    }

    /// 按周期汇总; profileUuid 为 nil 表示全部节点. 没有数据的桶补 0, 图上横轴连续
    func buckets(period: TrafficPeriod, profileUuid: String?, now: Date = Date(),
                 reader: any DatabaseReader = AppDatabase.shared.reader) -> [TrafficBucket] {
        let rows: [TrafficDaily] = (try? reader.read { db in
            if let uuid = profileUuid {
                return try TrafficDaily.filter(Column("profileUuid") == uuid).fetchAll(db)
            }
            return try TrafficDaily.fetchAll(db)
        }) ?? []
        return Self.aggregate(rows, period: period, now: now)
    }

    /// 纯计算部分, 方便测试
    static func aggregate(_ rows: [TrafficDaily], period: TrafficPeriod, now: Date) -> [TrafficBucket] {
        let cal = Calendar.current
        var sums: [String: (Int64, Int64)] = [:]
        func keyFor(_ day: String) -> String {
            switch period {
            case .live, .days30: return day
            case .months12: return String(day.prefix(7))
            case .all: return String(day.prefix(4))
            }
        }
        for r in rows {
            let k = keyFor(r.day)
            let cur = sums[k] ?? (0, 0)
            sums[k] = (cur.0 + r.up, cur.1 + r.down)
        }
        var starts: [Date] = []
        switch period {
        case .live:
            return []
        case .days30:
            let today = cal.startOfDay(for: now)
            starts = (0..<30).reversed().compactMap { cal.date(byAdding: .day, value: -$0, to: today) }
        case .months12:
            let month = cal.date(from: cal.dateComponents([.year, .month], from: now))!
            starts = (0..<12).reversed().compactMap { cal.date(byAdding: .month, value: -$0, to: month) }
        case .all:
            let thisYear = cal.component(.year, from: now)
            let firstYear = sums.keys.compactMap { Int($0) }.min() ?? thisYear
            starts = (firstYear...thisYear).compactMap { cal.date(from: DateComponents(year: $0, month: 1, day: 1)) }
        }
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.dateFormat = period == .days30 ? "yyyy-MM-dd" : (period == .months12 ? "yyyy-MM" : "yyyy")
        return starts.map { d in
            let k = fmt.string(from: d)
            let v = sums[k] ?? (0, 0)
            return TrafficBucket(key: k, start: d, up: v.0, down: v.1)
        }
    }
}
