//
//  LatencyTester.swift
//  V2rayU
//
//  延迟测量: 列表测速 / 启动检测 / 实时延迟共用同一套测法
//

import Foundation

/// 核心配置里测速专用的 SOCKS 入站 tag, 路由规则强制走 proxy 出站
let latencyInboundTag = "latency-in"

/// 实时延迟检测间隔可选值(秒), 对应设置里菜单栏延迟旁的下拉框
let latencyCheckIntervals = [5, 10, 30, 60]
let defaultLatencyCheckInterval = 5

func normalizedLatencyCheckInterval(_ value: Int) -> Int {
    latencyCheckIntervals.contains(value) ? value : defaultLatencyCheckInterval
}

/// 经核心的 latency-in SOCKS 入站测速, 口径与 v2rayN 一致: 在同一连接上测, 新建连接那次含握手不计。
enum LatencyTester {
    /// 只走 SOCKS: HTTP 代理入站处理明文请求时每次都会新建出站连接, 连接无法复用
    static func makeSession(socksPort: UInt16) -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.connectionProxyDictionary = [
            kCFNetworkProxiesHTTPEnable as AnyHashable: false,
            kCFNetworkProxiesHTTPSEnable as AnyHashable: false,
            kCFNetworkProxiesSOCKSEnable as AnyHashable: true,
            kCFNetworkProxiesSOCKSProxy as AnyHashable: "127.0.0.1",
            kCFNetworkProxiesSOCKSPort as AnyHashable: Int(socksPort),
        ]
        configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        configuration.urlCache = nil
        configuration.httpMaximumConnectionsPerHost = 1
        configuration.timeoutIntervalForRequest = TimeInterval(defaultLatencyTestTimeout)
        configuration.timeoutIntervalForResource = TimeInterval(defaultLatencyTestTimeout)
        return URLSession(configuration: configuration, delegate: NoRedirectSessionDelegate(), delegateQueue: nil)
    }

    /// 在 session 的连接上测一次; 若这次新建了连接(含握手), 立即在已建立的连接上再测一次
    static func measure(session: URLSession, url: URL) async throws -> Double {
        let first = try await measureOnce(session: session, url: url)
        if first.reused {
            return first.ms
        }
        // 第二次失败时用第一次的结果: 偏高(含握手)但节点是通的
        guard let second = try? await measureOnce(session: session, url: url) else {
            return first.ms
        }
        return min(first.ms, second.ms)
    }

    /// 一次性测速(列表测速 / 启动检测): 新建连接测完即释放; url 默认取设置里的测速地址
    static func test(socksPort: UInt16, url: URL? = nil) async throws -> Int {
        let session = makeSession(socksPort: socksPort)
        defer { session.invalidateAndCancel() }
        var target = url
        if target == nil {
            target = await AppSettings.shared.pingURL
        }
        guard let url = target else { throw URLError(.badURL) }
        let latency = Int(try await measure(session: session, url: url).rounded())
        logger.info("LatencyTester: port=\(socksPort) \(latency)ms")
        return latency
    }

    /// 当前运行的核心配置里 latency-in 的端口; 组合模式配置没有该入站
    static func runningInboundPort() -> UInt16? {
        FileManager.default.contents(atPath: "\(AppHomePath)/config.json").flatMap(inboundPort(inConfig:))
    }

    /// 从核心配置 JSON 中读取 latency-in 端口(xray: port, 可能是字符串; sing-box: listen_port)
    static func inboundPort(inConfig data: Data) -> UInt16? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let inbounds = json["inbounds"] as? [[String: Any]],
              let inbound = inbounds.first(where: { $0["tag"] as? String == latencyInboundTag }) else {
            return nil
        }
        let value = inbound["listen_port"] ?? inbound["port"]
        if let port = value as? Int { return UInt16(exactly: port) }
        if let port = value as? String { return UInt16(port) }
        return nil
    }

    /// 单次请求的耗时(请求发出到响应结束)及是否复用了已有连接
    private static func measureOnce(session: URLSession, url: URL) async throws -> (ms: Double, reused: Bool) {
        let collector = MetricsCollector()
        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: TimeInterval(defaultLatencyTestTimeout))
        let (_, response) = try await session.data(for: request, delegate: collector)
        // 必须直接返回 204: 拒绝跟随跳转时会拿到 3xx, 劫持页/认证页通常返回 200, 都视为失败
        guard let http = response as? HTTPURLResponse, http.statusCode == 204 else {
            throw URLError(.badServerResponse)
        }
        guard let metric = collector.metrics?.transactionMetrics.last,
              let start = metric.requestStartDate ?? metric.fetchStartDate,
              let end = metric.responseEndDate else {
            throw URLError(.cannotParseResponse)
        }
        return (max(1, end.timeIntervalSince(start) * 1000), metric.isReusedConnection)
    }

    private final class MetricsCollector: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
        var metrics: URLSessionTaskMetrics?

        func urlSession(_ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
            self.metrics = metrics
        }
    }
}

/// 阻断任何 3xx 跳转，让 generate_204 类目标必须直接返回
final class NoRedirectSessionDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}

// MARK: - 实时延迟

/// 实时延迟的取样与换连接判断(纯逻辑, 不涉及网络, 便于测试)
struct LatencySampler {
    enum ReconnectReason: Equatable {
        /// 启动时多试几条连接以选出基线
        case startup
        /// 当前连接明显高于基线
        case slow
        /// 请求失败
        case failure
    }

    struct Outcome: Equatable {
        /// 要显示的延迟, nil 表示保持不变
        var display: Double?
        /// 非 nil 时应换一条新连接
        var reconnect: ReconnectReason?
    }

    /// 显示最近几次的中位数, 过滤单次抖动
    static let windowSize = 3
    /// 连续失败几次才显示 -1
    static let maxFailures = 2
    /// 基线 = 最近若干次的最小值; 网络整体变慢一段时间后基线随之上升, 不再频繁换连接
    static let baselineWindowSize = 20
    /// 当前连接偏高时最快多久换一次连接
    static let switchCooldown: TimeInterval = 60
    /// 启动时额外试几条连接
    static let startupExtraConnections = 2

    private var samples: [Double] = []
    private var recent: [Double] = []
    private var failures = 0
    private var highCount = 0
    private var lastSwitchAt = Date.distantPast
    private var startupTries = startupExtraConnections

    /// 刚启动还没有样本, 或仍在启动选连接阶段, 应尽快再测; 失败期间按正常间隔重试, 避免持续高频新建连接
    var needsQuickRetry: Bool {
        failures == 0 && (samples.isEmpty || startupTries > 0)
    }

    mutating func recordSuccess(_ ms: Double, now: Date = Date()) -> Outcome {
        failures = 0
        samples.append(ms)
        if samples.count > Self.windowSize {
            samples.removeFirst(samples.count - Self.windowSize)
        }
        // 偶数个样本时取较小的中位数, 启动时碰到差连接不会先显示高值
        let sorted = samples.sorted()
        let display = sorted[(sorted.count - 1) / 2]

        recent.append(ms)
        if recent.count > Self.baselineWindowSize {
            recent.removeFirst(recent.count - Self.baselineWindowSize)
        }
        if startupTries > 0 {
            startupTries -= 1
            return Outcome(display: display, reconnect: .startup)
        }
        // 同一目标域名的不同连接可能落到远近不同的服务器(实测 gstatic 常整条连接固定多出 100~340ms),
        // 当前连接连续明显高于基线时换一条; 真实的网络变慢换了也一样, 显示的仍是真实值
        let baseline = recent.min() ?? ms
        guard ms > baseline * 2, ms > baseline + 50 else {
            highCount = 0
            return Outcome(display: display, reconnect: nil)
        }
        highCount += 1
        guard highCount >= 2, now.timeIntervalSince(lastSwitchAt) > Self.switchCooldown else {
            return Outcome(display: display, reconnect: nil)
        }
        highCount = 0
        lastSwitchAt = now
        return Outcome(display: display, reconnect: .slow)
    }

    mutating func recordFailure() -> Outcome {
        failures += 1
        highCount = 0
        guard failures >= Self.maxFailures else {
            return Outcome(display: nil, reconnect: .failure)
        }
        samples.removeAll()
        return Outcome(display: -1, reconnect: .failure)
    }
}

/// 实时延迟: 经核心的 latency-in 入站与测速 URL 保持一条长连接, 定时在其上发请求。
/// 只计一次往返, 也不会每次都新建到服务器的连接。组合模式的配置没有 latency-in, 仍由 observatory / clash API 提供延迟。
actor RealtimeLatencyMonitor {
    /// 测速地址、间隔、结果去向; 测试时替换
    struct Environment: Sendable {
        var url: @Sendable () async -> URL
        /// 正常检测间隔(秒)
        var interval: @Sendable () -> TimeInterval
        /// 启动阶段的快速重测间隔(秒)
        var quickRetryInterval: TimeInterval
        var publish: @Sendable (Int) async -> Void

        static let app = Environment(
            url: { await AppSettings.shared.pingURL },
            interval: { TimeInterval(normalizedLatencyCheckInterval(UserDefaults.getInt(forKey: .latencyCheckInterval, defaultValue: defaultLatencyCheckInterval))) },
            quickRetryInterval: 2,
            publish: { value in
                await AppState.shared.setLatency(latency: Double(value))
                let uuid = await AppState.shared.runningProfile
                if !uuid.isEmpty {
                    ProfileStore.shared.updateSpeed(uuid: uuid, speed: value)
                }
            }
        )
    }

    static let shared = RealtimeLatencyMonitor(environment: .app)

    /// 定期换一条新连接, 避免长期粘在一个线路差的目标服务器上
    private let reconnectInterval: TimeInterval = 300
    private let environment: Environment

    init(environment: Environment) {
        self.environment = environment
    }

    private var task: Task<Void, Never>?
    private var session: URLSession?
    private var sessionCreatedAt = Date.distantPast
    private var sampler = LatencySampler()
    private var lastPublished: Int?

    /// 按当前运行的核心配置启动; 组合模式配置没有 latency-in, 不启动
    func start() {
        guard let port = LatencyTester.runningInboundPort() else {
            stop()
            logger.info("RealtimeLatencyMonitor: no \(latencyInboundTag) inbound in config, skip")
            return
        }
        start(port: port)
    }

    func start(port: UInt16) {
        stop()
        logger.info("RealtimeLatencyMonitor: start, port=\(port)")
        task = Task { await self.run(port: port) }
    }

    func stop() {
        task?.cancel()
        task = nil
        resetSession()
        sampler = LatencySampler()
        lastPublished = nil
    }

    private func run(port: UInt16) async {
        // 核心启动时不等待端口, 这里等入站就绪(最多 10 秒)
        let deadline = Date().addingTimeInterval(10)
        while !isPortOpen(port), Date() < deadline, !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 200_000_000)
        }
        while !Task.isCancelled {
            await probe(port: port)
            let interval = sampler.needsQuickRetry ? environment.quickRetryInterval : environment.interval()
            try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
        }
    }

    private func probe(port: UInt16) async {
        if session == nil || Date().timeIntervalSince(sessionCreatedAt) > reconnectInterval {
            resetSession()
            session = LatencyTester.makeSession(socksPort: port)
            sessionCreatedAt = Date()
        }
        guard let session else { return }
        let url = await environment.url()
        let outcome: LatencySampler.Outcome
        do {
            let ms = try await LatencyTester.measure(session: session, url: url)
            guard !Task.isCancelled else { return }
            outcome = sampler.recordSuccess(ms)
        } catch {
            guard !Task.isCancelled else { return }
            logger.info("RealtimeLatencyMonitor: failed: \(error.localizedDescription)")
            outcome = sampler.recordFailure()
        }
        // 先换连接再 publish: publish 期间 actor 可能重入(停止/重启), 之后不能再改动状态
        if let reason = outcome.reconnect {
            if reason == .slow {
                logger.info("RealtimeLatencyMonitor: current connection slow, switch")
            }
            resetSession()
        }
        if let display = outcome.display {
            await publish(display)
        }
    }

    /// 数值不变时不重复更新界面和数据库
    private func publish(_ latency: Double) async {
        let value = Int(latency.rounded())
        guard value != lastPublished else { return }
        lastPublished = value
        await environment.publish(value)
    }

    private func resetSession() {
        session?.invalidateAndCancel()
        session = nil
    }
}
