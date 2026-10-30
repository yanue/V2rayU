import Foundation
import GRDB
import Testing
@testable import V2rayU

/// 按天记录的流量历史: 写入累加、按周期汇总、补 0
struct TrafficHistoryTests {
    private func makeDB() throws -> DatabaseQueue {
        let db = try DatabaseQueue()
        try AppDatabase.shared.migrator.migrate(db)
        return db
    }

    @Test func addAccumulatesPerProfilePerDay() throws {
        let db = try makeDB()
        let d1 = Date(timeIntervalSince1970: 1_800_000_000)
        try db.write { db in
            try TrafficHistoryStore.add(db: db, profileUuid: "a", up: 10, down: 100, at: d1)
            try TrafficHistoryStore.add(db: db, profileUuid: "a", up: 5, down: 50, at: d1)
            try TrafficHistoryStore.add(db: db, profileUuid: "b", up: 1, down: 2, at: d1)
            try TrafficHistoryStore.add(db: db, profileUuid: "a", up: 0, down: 0, at: d1)
        }
        let rows = try db.read { try TrafficDaily.order(Column("profileUuid")).fetchAll($0) }
        #expect(rows.count == 2)
        #expect(rows[0].up == 15 && rows[0].down == 150)
        #expect(Set(TrafficHistoryStore.shared.profileUuids(reader: db)) == ["a", "b"])
    }

    @Test func aggregateDaysMonthsAll() {
        let cal = Calendar.current
        let now = cal.date(from: DateComponents(year: 2026, month: 10, day: 30, hour: 12))!
        let rows = [
            TrafficDaily(profileUuid: "a", day: "2026-10-30", up: 1, down: 10),
            TrafficDaily(profileUuid: "b", day: "2026-10-30", up: 2, down: 20),
            TrafficDaily(profileUuid: "a", day: "2026-10-01", up: 3, down: 30),
            TrafficDaily(profileUuid: "a", day: "2026-03-15", up: 4, down: 40),
            TrafficDaily(profileUuid: "a", day: "2024-06-01", up: 5, down: 50),
        ]
        let days = TrafficHistoryStore.aggregate(rows, period: .days30, now: now)
        #expect(days.count == 30)
        #expect(days.last?.key == "2026-10-30")
        #expect(days.last?.up == 3 && days.last?.down == 30)
        #expect(days.first?.key == "2026-10-01")
        #expect(days.first?.up == 3)

        let months = TrafficHistoryStore.aggregate(rows, period: .months12, now: now)
        #expect(months.count == 12)
        #expect(months.last?.key == "2026-10" && months.last?.down == 60)
        #expect(months.first(where: { $0.key == "2026-03" })?.up == 4)

        let all = TrafficHistoryStore.aggregate(rows, period: .all, now: now)
        #expect(all.map(\.key) == ["2024", "2025", "2026"])
        #expect(all[1].up == 0)
        #expect(all[2].up == 10)

        #expect(TrafficHistoryStore.aggregate(rows, period: .live, now: now).isEmpty)
    }
}

/// 概览页 IP 信息的显示整理
struct OverviewIpInfoTests {
    @Test @MainActor func regionAndAsn() {
        let hk = OverviewViewModel.IpInfo(ip: "1.2.3.4", country: "Hong Kong", countryCode: "HK", city: "Hong Kong", isp: "x", asn: "AS45102 Alibaba Co., Ltd.")
        #expect(hk.regionText == "\(countryCodeToEmoji("HK")) Hong Kong")
        #expect(hk.asnNumber == "AS45102")
        let us = OverviewViewModel.IpInfo(country: "United States", countryCode: "US", city: "Los Angeles")
        #expect(us.regionText == "\(countryCodeToEmoji("US")) United States · Los Angeles")
        #expect(OverviewViewModel.IpInfo().regionText == "")
    }

    @Test @MainActor func shortVersion() {
        #expect(OverviewViewModel.shortVersion("sing-box version 1.13.12") == "1.13.12")
        #expect(OverviewViewModel.shortVersion("Xray 26.1.18 (Xray, Penetrates Everything.)") == "26.1.18")
        #expect(OverviewViewModel.shortVersion("") == "-")
    }
}
