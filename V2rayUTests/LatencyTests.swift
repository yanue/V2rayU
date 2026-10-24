import Foundation
import Network
import Testing
@testable import V2rayU

/// 延迟测量: 取样逻辑、配置里的 latency-in 入站、实际请求的连接复用
@Suite struct LatencyTests {

    // MARK: - LatencySampler

    @Test("Display is the lower median of the last samples")
    func samplerDisplaysLowerMedian() {
        var sampler = LatencySampler()
        #expect(sampler.recordSuccess(20).display == 20)
        // 两个样本时取较小的, 启动时碰到差连接不会先显示高值
        #expect(sampler.recordSuccess(120).display == 20)
        #expect(sampler.recordSuccess(30).display == 30)
        // 窗口只保留最近 3 个: [120, 30, 25] -> 30
        #expect(sampler.recordSuccess(25).display == 30)
        // [30, 25, 400] -> 30, 单次尖刺不显示
        #expect(sampler.recordSuccess(400).display == 30)
    }

    @Test("Startup switches connections, then quick retry ends")
    func samplerStartupReconnects() {
        var sampler = LatencySampler()
        #expect(sampler.needsQuickRetry)
        for _ in 0 ..< LatencySampler.startupExtraConnections {
            #expect(sampler.recordSuccess(20).reconnect == .startup)
        }
        #expect(!sampler.needsQuickRetry)
        #expect(sampler.recordSuccess(20).reconnect == nil)
    }

    @Test("Keep the normal interval while probes keep failing")
    func samplerNoQuickRetryWhileFailing() {
        var fresh = LatencySampler()
        _ = fresh.recordFailure()
        #expect(!fresh.needsQuickRetry)
        var sampler = warmedSampler()
        _ = sampler.recordFailure()
        _ = sampler.recordFailure()
        #expect(!sampler.needsQuickRetry)
        #expect(sampler.recordSuccess(20).reconnect == nil)
    }

    @Test("Failures show -1 only after consecutive failures")
    func samplerFailures() {
        var sampler = warmedSampler()
        let first = sampler.recordFailure()
        #expect(first.display == nil)
        #expect(first.reconnect == .failure)
        #expect(sampler.recordFailure().display == -1)
        // 成功一次即恢复显示, 失败计数清零
        #expect(sampler.recordSuccess(22).display == 22)
        #expect(sampler.recordFailure().display == nil)
    }

    @Test("Switch connection when consistently slower than baseline")
    func samplerSwitchesSlowConnection() {
        var sampler = warmedSampler()
        let now = Date()
        // 单次偏高不换
        #expect(sampler.recordSuccess(130, now: now).reconnect == nil)
        // 连续两次明显高于基线(>2 倍且 >+50ms)才换
        #expect(sampler.recordSuccess(130, now: now).reconnect == .slow)
        // 冷却期内即使仍偏高也不再换
        #expect(sampler.recordSuccess(130, now: now.addingTimeInterval(10)).reconnect == nil)
        #expect(sampler.recordSuccess(130, now: now.addingTimeInterval(20)).reconnect == nil)
        // 冷却期过后可以再换
        #expect(sampler.recordSuccess(130, now: now.addingTimeInterval(61)).reconnect == .slow)
    }

    @Test("Small increases do not trigger a switch")
    func samplerIgnoresSmallIncrease() {
        var sampler = warmedSampler()
        // 2 倍但不足 +50ms: 20 -> 45
        #expect(sampler.recordSuccess(45).reconnect == nil)
        #expect(sampler.recordSuccess(45).reconnect == nil)
        // 偏高之间夹一次正常值, 计数重置
        #expect(sampler.recordSuccess(130).reconnect == nil)
        #expect(sampler.recordSuccess(20).reconnect == nil)
        #expect(sampler.recordSuccess(130).reconnect == nil)
    }

    @Test("Baseline follows the network after the window rolls over")
    func samplerBaselineAdapts() {
        var sampler = warmedSampler()
        var now = Date()
        // 网络整体变慢: 每分钟最多换一次, 窗口滚动后基线升上来就不再换
        var switches = 0
        for _ in 0 ..< LatencySampler.baselineWindowSize + 5 {
            now = now.addingTimeInterval(61)
            if sampler.recordSuccess(200, now: now).reconnect == .slow {
                switches += 1
            }
        }
        #expect(switches > 0)
        now = now.addingTimeInterval(61)
        #expect(sampler.recordSuccess(200, now: now).reconnect == nil)
        #expect(sampler.recordSuccess(200, now: now.addingTimeInterval(61)).reconnect == nil)
    }

    /// 已过启动阶段、基线约 20ms 的取样器
    private func warmedSampler() -> LatencySampler {
        var sampler = LatencySampler()
        for _ in 0 ... LatencySampler.startupExtraConnections {
            _ = sampler.recordSuccess(20)
        }
        return sampler
    }

    // MARK: - 设置

    @Test("Check interval falls back to default for unsupported values")
    func normalizesCheckInterval() {
        for value in latencyCheckIntervals {
            #expect(normalizedLatencyCheckInterval(value) == value)
        }
        // 旧设置项的 1/2/3 秒、未设置时的 0
        for value in [0, 1, 2, 3, -1, 7] {
            #expect(normalizedLatencyCheckInterval(value) == defaultLatencyCheckInterval)
        }
    }

    // MARK: - 端口解析

    @Test("Reads latency-in port from xray and sing-box configs")
    func parsesInboundPort() {
        let xray = #"{"inbounds":[{"tag":"mixed-in","port":"1080"},{"tag":"latency-in","protocol":"socks","port":"52001"}]}"#
        let singbox = #"{"inbounds":[{"tag":"mixed-in","listen_port":1080},{"tag":"latency-in","type":"socks","listen_port":52002}]}"#
        let none = #"{"inbounds":[{"tag":"mixed-in","listen_port":1080}]}"#
        #expect(LatencyTester.inboundPort(inConfig: Data(xray.utf8)) == 52001)
        #expect(LatencyTester.inboundPort(inConfig: Data(singbox.utf8)) == 52002)
        #expect(LatencyTester.inboundPort(inConfig: Data(none.utf8)) == nil)
        #expect(LatencyTester.inboundPort(inConfig: Data("not json".utf8)) == nil)
        #expect(LatencyTester.inboundPort(inConfig: Data(#"{"inbounds":[{"tag":"latency-in","port":"99999"}]}"#.utf8)) == nil)
    }

    // MARK: - 配置生成

    private let profile = ProfileEntity(uuid: "latency-test-uuid", protocol: .vless, address: "example.com", port: 443, password: "uuid", network: .tcp, security: .tls)

    private func parse(_ json: String) throws -> [String: Any] {
        try #require(try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])
    }

    private func latencyInbound(_ config: [String: Any]) -> [String: Any]? {
        (config["inbounds"] as? [[String: Any]])?.first { $0["tag"] as? String == latencyInboundTag }
    }

    @Test("Xray running config routes latency-in to proxy first, without observatory")
    func xrayRunningConfig() throws {
        let json = V2rayConfigHandler().toJSON(item: profile)
        let config = try parse(json)
        let inbound = try #require(latencyInbound(config))
        #expect(inbound["protocol"] as? String == "socks")
        #expect(inbound["listen"] as? String == "127.0.0.1")
        let port = try #require(LatencyTester.inboundPort(inConfig: Data(json.utf8)))
        #expect(port > 0)
        let rules = try #require((config["routing"] as? [String: Any])?["rules"] as? [[String: Any]])
        #expect(rules.first?["inboundTag"] as? [String] == [latencyInboundTag])
        #expect(rules.first?["outboundTag"] as? String == "proxy")
        // 实时延迟改由长连接测速, 单节点配置不再每 2 秒新建连接探测
        #expect(config["observatory"] == nil)
    }

    @Test("Sing-box running config routes latency-in to proxy first")
    func singboxRunningConfig() throws {
        let json = SingboxConfigHandler().toJSON(item: profile)
        let config = try parse(json)
        let inbound = try #require(latencyInbound(config))
        #expect(inbound["type"] as? String == "socks")
        #expect(inbound["listen"] as? String == "127.0.0.1")
        #expect((inbound["listen_port"] as? Int ?? 0) > 0)
        let rules = try #require((config["route"] as? [String: Any])?["rules"] as? [[String: Any]])
        #expect(rules.first?["inbound"] as? [String] == [latencyInboundTag])
        #expect(rules.first?["outbound"] as? String == "proxy")
    }

    @Test("Ping configs add latency-in only when a port is given")
    func pingConfigs() throws {
        let xray = try parse(V2rayConfigHandler().toJSON(item: profile, httpPort: "30010", latencyPort: "30011"))
        #expect(latencyInbound(xray)?["port"] as? String == "30011")
        #expect(((xray["routing"] as? [String: Any])?["rules"] as? [[String: Any]])?.first?["outboundTag"] as? String == "proxy")
        #expect(xray["observatory"] == nil)

        let singbox = try parse(SingboxConfigHandler().toJSON(item: profile, httpPort: "30015", latencyPort: "30016"))
        #expect(latencyInbound(singbox)?["listen_port"] as? Int == 30016)
        // 不再依赖 clash API 测速
        #expect(singbox["experimental"] == nil)

        // 兼容性测试只用 HTTP 入站
        #expect(latencyInbound(try parse(V2rayConfigHandler().toJSON(item: profile, httpPort: "30020"))) == nil)
        #expect(latencyInbound(try parse(SingboxConfigHandler().toJSON(item: profile, httpPort: "30025"))) == nil)
    }

    @Test("Combined configs have no latency-in", arguments: [CoreType.XrayCore, CoreType.SingBox])
    func combinedConfigsHaveNoLatencyInbound(coreType: CoreType) throws {
        let group = CombinedInboundOutboundGroup(id: "g1", inboundType: .mixed, port: 18080, outboundProfileUUIDs: [profile.uuid])
        let resolved = CombinedConfigResolved(
            combination: CombinedConfigEntity(uuid: "combo", groups: [group], outboundMode: .balance),
            groups: [CombinedConfigResolvedGroup(group: group, profiles: [profile])],
            coreType: coreType,
            warningMessage: nil,
            canLaunch: true
        )
        let json = coreType == .XrayCore
            ? V2rayConfigHandler().toJSON(combination: resolved)
            : SingboxConfigHandler().toJSON(combination: resolved)
        #expect(latencyInbound(try parse(json)) == nil)
        #expect(LatencyTester.inboundPort(inConfig: Data(json.utf8)) == nil)
    }

    @Test("Xray TUN chain config keeps latency-in routed to proxy")
    func xrayTunChainConfig() throws {
        let config = try parse(V2rayConfigHandler(enableTun: false, tunChainMode: true).toJSON(item: profile))
        #expect(latencyInbound(config) != nil)
        let rules = try #require((config["routing"] as? [String: Any])?["rules"] as? [[String: Any]])
        #expect(rules.first?["inboundTag"] as? [String] == [latencyInboundTag])
        #expect(rules.first?["outboundTag"] as? String == "proxy")
    }

    // MARK: - 组合模式 observatory

    private func observation(_ alive: Bool, _ delay: Double) -> V2rayMetricObservatory {
        V2rayMetricObservatory(alive: alive, delay: delay, outbound_tag: "", last_seen_time: 0)
    }

    @Test("Combined latency skips dead outbounds and marks them -1")
    func comboLatencyFiltersDead() {
        let result = XrayApiStatsHandler.comboLatency([
            "combo-out-0-0-uuid-a": observation(true, 80),
            "combo-out-0-1-uuid-b": observation(false, 99_999_999),
            "combo-out-0-2-uuid-c": observation(true, 40.4),
            "metrics_out": observation(true, 1),
        ])
        #expect(result.display == 40.4)
        #expect(result.speeds == ["uuid-a": 80, "uuid-b": -1, "uuid-c": 40])
    }

    @Test("Chain exit counts for display but is not written back to a profile")
    func comboLatencyChain() {
        let result = XrayApiStatsHandler.comboLatency([
            "combo-chain-0-1-exit-uuid": observation(true, 150),
        ])
        #expect(result.display == 150)
        #expect(result.speeds.isEmpty)
    }

    @Test("All dead shows -1, not probed yet shows 0")
    func comboLatencyAllDeadOrEmpty() {
        let dead = XrayApiStatsHandler.comboLatency([
            "combo-out-0-0-uuid-a": observation(false, 99_999_999),
            "combo-chain-1-1-uuid-b": observation(false, 99_999_999),
        ])
        #expect(dead.display == -1)
        #expect(dead.speeds == ["uuid-a": -1])
        #expect(XrayApiStatsHandler.comboLatency([:]).display == 0)
        #expect(XrayApiStatsHandler.comboLatency(["proxy": observation(true, 20)]).display == 0)
    }

    // MARK: - 诊断

    @Test("Diagnostics curl lets the proxy resolve the hostname")
    func diagnosticsCurlUsesRemoteDNS() {
        let args = DiagnosticsViewModel.proxyCheckCurlArguments(socksPort: 1080, testURL: defaultPingTestURL, timeout: "5")
        #expect(args.contains("--socks5-hostname"))
        #expect(!args.contains("--socks5"))
        #expect(args.last == defaultPingTestURL)
    }

    // MARK: - 实际请求

    @Test("Measure reuses the connection and skips the handshake request")
    func measureReusesConnection() async throws {
        let server = try await LocalHTTPServer.start(status: 204)
        defer { server.stop() }
        let session = URLSession(configuration: .ephemeral, delegate: NoRedirectSessionDelegate(), delegateQueue: nil)
        defer { session.invalidateAndCancel() }

        // 新 session: 第一次新建连接, 再在已建立的连接上测一次
        let first = try await LatencyTester.measure(session: session, url: server.url)
        #expect(first > 0)
        #expect(server.requestCount == 2)
        #expect(server.connectionCount == 1)

        // 连接已建立: 只发一次请求, 不再新建连接
        _ = try await LatencyTester.measure(session: session, url: server.url)
        #expect(server.requestCount == 3)
        #expect(server.connectionCount == 1)
    }

    @Test("Falls back to the first result when the retry fails")
    func measureFallsBackToFirstRequest() async throws {
        let server = try await LocalHTTPServer.start(statuses: [204, 500])
        defer { server.stop() }
        let session = URLSession(configuration: .ephemeral, delegate: NoRedirectSessionDelegate(), delegateQueue: nil)
        defer { session.invalidateAndCancel() }

        let latency = try await LatencyTester.measure(session: session, url: server.url)
        #expect(latency > 0)
        #expect(server.requestCount == 2)
    }

    @Test("Only 204 counts as success", arguments: [(204, true), (200, false), (302, false), (500, false)])
    func measureValidatesStatus(status: Int, success: Bool) async throws {
        let server = try await LocalHTTPServer.start(status: status)
        defer { server.stop() }
        let session = URLSession(configuration: .ephemeral, delegate: NoRedirectSessionDelegate(), delegateQueue: nil)
        defer { session.invalidateAndCancel() }

        let result = try? await LatencyTester.measure(session: session, url: server.url)
        #expect((result != nil) == success)
    }
}
