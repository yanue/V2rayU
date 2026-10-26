import Foundation
import Testing
@testable import V2rayU

/// 订阅更新周期校正: 负数或过大的周期传给 DispatchSource.schedule 会直接崩溃
struct SubscriptionSchedulerTests {
    @Test(arguments: [(-5, 3600), (0, 3600), (60, 60), (86400, 86400), (Int.max, SubscriptionScheduler.maxUpdateInterval)])
    func normalizedInterval(input: Int, expected: Int) {
        #expect(SubscriptionScheduler.normalizedInterval(input) == expected)
    }

    @Test func schedulingAbnormalIntervalsDoesNotCrash() async {
        for interval in [-5, 0, Int.max] {
            let sub = SubscriptionEntity(remark: "test", url: "https://example.invalid/sub", enable: false, updateInterval: interval)
            await SubscriptionScheduler.shared.startOrUpdate(for: sub)
            await SubscriptionScheduler.shared.stop(for: sub.uuid)
        }
    }
}
