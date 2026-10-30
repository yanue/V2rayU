import Foundation
import Testing
@testable import V2rayU

/// 订阅响应头 subscription-userinfo 解析
struct SubscriptionUserInfoTests {
    @Test func parsesStandardHeader() {
        let info = SubscriptionUserInfo.parse(header: "upload=1024; download=2048; total=10737418240; expire=1700000000")
        #expect(info == SubscriptionUserInfo(upload: 1024, download: 2048, total: 10737418240, expire: 1700000000))
        #expect(info?.used == 3072)
        #expect(info?.usedRatio != nil)
    }

    @Test func toleratesSpacingCaseAndMissingFields() {
        let info = SubscriptionUserInfo.parse(header: "Upload = 5;download=7;TOTAL=100")
        #expect(info == SubscriptionUserInfo(upload: 5, download: 7, total: 100, expire: 0))
        #expect(info?.hasExpire == false)
        #expect(info?.expireText == "-")
    }

    @Test func parsesDecimalAndScientificNumbers() {
        let info = SubscriptionUserInfo.parse(header: "upload=0; download=1.5e9; total=2147483648.0; expire=1700000000")
        #expect(info?.download == 1_500_000_000)
        #expect(info?.total == 2_147_483_648)
    }

    @Test func negativeValuesClampToZero() {
        let info = SubscriptionUserInfo.parse(header: "upload=-5; download=10; total=-1")
        #expect(info == SubscriptionUserInfo(upload: 0, download: 10, total: 0, expire: 0))
        #expect(info?.usedRatio == nil)
        #expect(info?.trafficText == SubscriptionUserInfo.formatBytes(10))
    }

    @Test func garbageHeaderReturnsNil() {
        #expect(SubscriptionUserInfo.parse(header: "") == nil)
        #expect(SubscriptionUserInfo.parse(header: "foo=bar; baz") == nil)
        #expect(SubscriptionUserInfo.parse(header: "upload=abc") == nil)
    }

    @Test func parsesFromHttpResponseCaseInsensitively() {
        let url = URL(string: "https://example.com/sub")!
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil,
                                       headerFields: ["Subscription-Userinfo": "upload=1; download=2; total=3; expire=4"])
        #expect(SubscriptionUserInfo.parse(response: response) == SubscriptionUserInfo(upload: 1, download: 2, total: 3, expire: 4))
        let plain = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: [:])
        #expect(SubscriptionUserInfo.parse(response: plain) == nil)
        #expect(SubscriptionUserInfo.parse(response: nil) == nil)
    }

    @Test func usedRatioIsClampedToOne() {
        let info = SubscriptionUserInfo(upload: 0, download: 200, total: 100, expire: 0)
        #expect(info.usedRatio == 1)
        #expect(info.trafficText == "\(SubscriptionUserInfo.formatBytes(200)) / \(SubscriptionUserInfo.formatBytes(100))")
    }

    @Test func expiryStatus() {
        let now = Int(Date().timeIntervalSince1970)
        #expect(SubscriptionUserInfo(expire: now - 86400 * 2).isExpired)
        #expect(SubscriptionUserInfo(expire: now - 86400 * 2).daysLeft == -2)
        #expect(SubscriptionUserInfo(expire: now + 86400 * 10).daysLeft == 10)
        #expect(SubscriptionUserInfo(expire: now + 3600).daysLeft == 1)
        #expect(SubscriptionUserInfo(expire: now - 3600).isExpired)
        #expect(SubscriptionUserInfo(expire: now + 86400 * 10).isExpired == false)
        #expect(SubscriptionUserInfo().daysLeft == nil)
    }

    @Test func entityRoundTrip() {
        let sub = SubscriptionEntity(upload: 1, download: 2, total: 3, expire: 4)
        #expect(sub.userInfo == SubscriptionUserInfo(upload: 1, download: 2, total: 3, expire: 4))
        #expect(SubscriptionEntity().userInfo.isEmpty)
    }
}
