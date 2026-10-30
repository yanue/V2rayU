import Foundation
import Testing
@testable import V2rayU

/// sing-box clash_api /connections 响应解析
struct ClashConnectionsTests {
    static let sample = """
    {"downloadTotal":123456,"uploadTotal":7890,"connections":[
      {"id":"a1","metadata":{"network":"tcp","type":"Mixed","sourceIP":"127.0.0.1","destinationIP":"142.250.1.1","sourcePort":"50123","destinationPort":"443","host":"www.google.com","dnsMode":"normal","processPath":"/Applications/Safari.app/Contents/MacOS/Safari"},
       "upload":100,"download":2000,"start":"2026-10-28T10:00:00.123456789+08:00","chains":["proxy","Mixed"],"rule":"rule_set=geosite-geolocation-!cn","rulePayload":""},
      {"id":"b2","metadata":{"network":"udp","type":"TUN","sourceIP":"198.18.0.1","destinationIP":"223.5.5.5","sourcePort":"5000","destinationPort":"53","host":""},
       "upload":1,"download":2,"start":"2026-10-28T10:00:00Z","chains":["direct"],"rule":"final","rulePayload":"direct"}
    ]}
    """.data(using: .utf8)!

    @Test func parsesSnapshot() throws {
        let snapshot = try ClashConnectionsSnapshot.parse(Self.sample)
        #expect(snapshot.uploadTotal == 7890)
        #expect(snapshot.downloadTotal == 123456)
        #expect(snapshot.list.count == 2)

        let a = snapshot.list[0]
        #expect(a.target == "www.google.com:443")
        #expect(a.source == "127.0.0.1:50123")
        #expect(a.outbound == "proxy")
        #expect(a.chainText == "Mixed → proxy")
        #expect(a.processName == "Safari")
        #expect(a.ruleText == "rule_set=geosite-geolocation-!cn")
        #expect(a.startDate != nil)

        let b = snapshot.list[1]
        #expect(b.target == "223.5.5.5:53")
        #expect(b.processName == "")
        #expect(b.ruleText == "final (direct)")
        #expect(b.metadata.processPath == nil)
    }

    @Test func parsesGoTimestamps() {
        let withNanos = ClashConnection.parseStart("2026-10-28T10:00:00.123456789+08:00")
        let plain = ClashConnection.parseStart("2026-10-28T02:00:00Z")
        #expect(withNanos != nil)
        #expect(withNanos == plain)
        #expect(ClashConnection.parseStart("") == nil)
        #expect(ClashConnection.parseStart("garbage") == nil)
    }

    @Test func emptyAndNullConnectionsListIsTolerated() throws {
        let empty = try ClashConnectionsSnapshot.parse("{\"downloadTotal\":0,\"uploadTotal\":0,\"connections\":null}".data(using: .utf8)!)
        #expect(empty.list.isEmpty)
        let missing = try ClashConnectionsSnapshot.parse("{\"downloadTotal\":0,\"uploadTotal\":0}".data(using: .utf8)!)
        #expect(missing.list.isEmpty)
    }

    @Test func searchMatchesAnyColumn() throws {
        let list = try ClashConnectionsSnapshot.parse(Self.sample).list
        #expect(list.filter { $0.matches("google") }.map(\.id) == ["a1"])
        #expect(list.filter { $0.matches("safari") }.map(\.id) == ["a1"])
        #expect(list.filter { $0.matches("direct") }.map(\.id) == ["b2"])
        #expect(list.filter { $0.matches("UDP") }.map(\.id) == ["b2"])
        #expect(list.filter { $0.matches("nothing") }.isEmpty)
    }

    @Test func durationFormat() {
        #expect(formatConnectionDuration(5) == "5s")
        #expect(formatConnectionDuration(65) == "1m05s")
        #expect(formatConnectionDuration(3720) == "1h02m")
        #expect(formatConnectionDuration(-3) == "0s")
    }

    @Test func singboxRouteEnablesFindProcess() {
        #expect(RouteConfig().find_process == nil)
    }
}
