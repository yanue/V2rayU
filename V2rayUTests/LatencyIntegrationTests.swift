import Foundation
import Testing
@testable import V2rayU

/// 延迟测量的端到端行为: 经 SOCKS 测速、实时延迟 monitor、真实核心的 latency-in。
/// 全部使用本机服务, 不访问外网; 目标用不存在的域名, 只有交给代理解析才能连通。
@Suite(.serialized) struct LatencyIntegrationTests {
    private let host = "latency-test.invalid"

    // MARK: - 经 SOCKS 测速

    @Test("Session goes through SOCKS, lets the proxy resolve the host and reuses the tunnel")
    func socksSessionReusesTunnel() async throws {
        let http = try await LocalHTTPServer.start(status: 204)
        defer { http.stop() }
        let socks = try await LocalSOCKS5Server.start()
        defer { socks.stop() }
        let session = LatencyTester.makeSession(socksPort: socks.port)
        defer { session.invalidateAndCancel() }

        _ = try await LatencyTester.measure(session: session, url: http.url(host: host))
        _ = try await LatencyTester.measure(session: session, url: http.url(host: host))
        // 域名原样交给代理; 三次请求只建了一条隧道
        #expect(socks.requestedHosts == [host])
        #expect(http.connectionCount == 1)
        #expect(http.requestCount == 3)
    }

    @Test("One-shot test returns the latency and fails when the proxy is down")
    func oneShotTest() async throws {
        let http = try await LocalHTTPServer.start(status: 204)
        defer { http.stop() }
        let socks = try await LocalSOCKS5Server.start()
        let latency = try await LatencyTester.test(socksPort: socks.port, url: http.url(host: host))
        #expect(latency > 0)
        #expect(http.requestCount == 2)

        socks.stop()
        await #expect(throws: (any Error).self) {
            try await LatencyTester.test(socksPort: socks.port, url: http.url(host: host))
        }
    }

    // MARK: - 实时延迟 monitor

    private func monitor(url: URL, recorder: PublishRecorder) -> RealtimeLatencyMonitor {
        RealtimeLatencyMonitor(environment: .init(
            url: { url },
            interval: { 0.05 },
            quickRetryInterval: 0.02,
            publish: { await recorder.record($0) }
        ))
    }

    @Test("Monitor keeps one long connection after startup and stops cleanly")
    func monitorKeepsLongConnection() async throws {
        let http = try await LocalHTTPServer.start(status: 204)
        defer { http.stop() }
        let socks = try await LocalSOCKS5Server.start()
        defer { socks.stop() }
        let recorder = PublishRecorder()
        let monitor = monitor(url: http.url(host: host), recorder: recorder)

        await monitor.start(port: socks.port)
        // 启动阶段换 2 次连接, 之后一直复用第 3 条
        let enoughProbes = LatencySampler.startupExtraConnections + 1 + 8
        #expect(await waitUntil { http.requestCount >= enoughProbes })
        await monitor.stop()

        #expect(http.connectionCount == LatencySampler.startupExtraConnections + 1)
        #expect(socks.requestedHosts.count == LatencySampler.startupExtraConnections + 1)
        #expect(Set(socks.requestedHosts) == [host])
        let values = await recorder.values
        #expect(!values.isEmpty)
        #expect(values.allSatisfy { $0 > 0 })
        // 数值不变时不重复发布
        #expect(zip(values, values.dropFirst()).allSatisfy { $0 != $1 })

        // 停止后不再请求、不再发布
        let requests = http.requestCount
        try await Task.sleep(nanoseconds: 300_000_000)
        #expect(http.requestCount == requests)
        #expect(await recorder.values.count == values.count)
    }

    @Test("Monitor shows -1 after the proxy goes down")
    func monitorReportsFailure() async throws {
        let http = try await LocalHTTPServer.start(status: 204)
        defer { http.stop() }
        let socks = try await LocalSOCKS5Server.start()
        let recorder = PublishRecorder()
        let monitor = monitor(url: http.url(host: host), recorder: recorder)

        await monitor.start(port: socks.port)
        #expect(await waitUntil { await recorder.values.contains { $0 > 0 } })
        // 代理断开: 连续失败后显示 -1
        socks.stop()
        #expect(await waitUntil { await recorder.values.last == -1 })
        await monitor.stop()
    }

    @Test("Monitor treats non-204 responses as failures")
    func monitorRejectsNon204() async throws {
        let http = try await LocalHTTPServer.start(status: 200)
        defer { http.stop() }
        let socks = try await LocalSOCKS5Server.start()
        defer { socks.stop() }
        let recorder = PublishRecorder()
        let monitor = monitor(url: http.url(host: host), recorder: recorder)

        await monitor.start(port: socks.port)
        #expect(await waitUntil { await recorder.values.last == -1 })
        await monitor.stop()
        #expect(await recorder.values == [-1])
    }

    /// 切换节点时 monitor 被反复重启/停止: 重启发生在测速进行中(取测速地址、两次请求之间)时,
    /// 旧的 session 不能被别处作废后再用来发请求(会抛 NSGenericException 直接崩溃)
    @Test("Restarting the monitor mid-probe does not reuse an invalidated session")
    func monitorRestartMidProbe() async throws {
        let http = try await LocalHTTPServer.start(status: 204)
        defer { http.stop() }
        let socks = try await LocalSOCKS5Server.start()
        defer { socks.stop() }
        let recorder = PublishRecorder()
        let url = http.url(host: host)
        let monitor = RealtimeLatencyMonitor(environment: .init(
            // 取地址时让出执行权, 与正式环境切到主线程取设置一样
            url: { try? await Task.sleep(nanoseconds: 20_000_000); return url },
            interval: { 0.01 },
            quickRetryInterval: 0.01,
            publish: { await recorder.record($0) }
        ))

        for i in 0..<60 {
            await monitor.start(port: socks.port)
            try await Task.sleep(nanoseconds: UInt64(5_000_000 + (i % 6) * 5_000_000))
            if i % 10 == 9 {
                await monitor.stop()
            }
        }
        await monitor.start(port: socks.port)
        #expect(await waitUntil { await recorder.values.contains { $0 > 0 } })
        await monitor.stop()
    }

    // MARK: - 诊断

    @Test("Diagnostics curl reaches the target through SOCKS with remote DNS")
    func diagnosticsCurlThroughSocks() async throws {
        let http = try await LocalHTTPServer.start(status: 204)
        defer { http.stop() }
        let socks = try await LocalSOCKS5Server.start()
        defer { socks.stop() }

        let args = DiagnosticsViewModel.proxyCheckCurlArguments(socksPort: socks.port, testURL: http.url(host: host).absoluteString, timeout: "5")
        #expect(try runCurl(args) == "204")
        #expect(socks.requestedHosts == [host])
    }

    private func runCurl(_ arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/curl")
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        try process.run()
        process.waitUntilExit()
        return String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
    }

    // MARK: - 真实核心

    /// 节点用 socks 协议指向本机 SOCKS 服务, 测速配置经真实核心的 latency-in 转发
    @Test("Ping config works end to end through the real core", .enabled(if: FileManager.default.isExecutableFile(atPath: getCoreFile(mode: .XrayCore)) && FileManager.default.isExecutableFile(atPath: getCoreFile(mode: .SingBox))), arguments: [CoreType.XrayCore, CoreType.SingBox])
    func pingConfigThroughRealCore(coreType: CoreType) async throws {
        let http = try await LocalHTTPServer.start(status: 204)
        defer { http.stop() }
        let socks = try await LocalSOCKS5Server.start()
        defer { socks.stop() }

        let profile = ProfileEntity(protocol: .socks, address: "127.0.0.1", port: Int(socks.port))
        let httpPort = findFreePort()
        var latencyPort = findFreePort()
        while latencyPort == httpPort {
            latencyPort = findFreePort()
        }
        let json = coreType == .XrayCore
            ? V2rayConfigHandler().toJSON(item: profile, httpPort: String(httpPort), latencyPort: String(latencyPort))
            : SingboxConfigHandler().toJSON(item: profile, httpPort: String(httpPort), latencyPort: String(latencyPort))
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("latency-e2e-\(UUID().uuidString).json")
        try json.write(to: file, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: file) }

        let core = Process()
        core.executableURL = URL(fileURLWithPath: getCoreFile(mode: coreType))
        core.arguments = ["run", "-c", file.path]
        core.currentDirectoryURL = URL(fileURLWithPath: AppHomePath)
        core.standardOutput = FileHandle.nullDevice
        core.standardError = FileHandle.nullDevice
        try core.run()
        defer {
            core.terminate()
            core.waitUntilExit()
        }
        #expect(await waitUntil { isPortOpen(latencyPort) })

        let latency = try await LatencyTester.test(socksPort: latencyPort, url: http.url(host: host))
        #expect(latency > 0)
        // 核心把域名原样交给出站, 新连接一次 + 复用一次
        #expect(socks.requestedHosts == [host])
        #expect(http.connectionCount == 1)
        #expect(http.requestCount == 2)
    }
}
