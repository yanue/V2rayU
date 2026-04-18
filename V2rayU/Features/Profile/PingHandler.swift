//
//  PingHandler.swift
//  V2rayU
//
//  Created by yanue on 2025/9/21.
//
import Combine
import Foundation

let NOTIFY_UPDATE_Ping = Notification.Name(rawValue: "NOTIFY_UPDATE_Ping")

actor PingAll {
    static let shared = PingAll()

    private(set) var inPing: Bool = false

    private let maxConcurrentTasks = 10
    private var cancellables = Set<AnyCancellable>()
    private var totalCount = 0
    private var finishedCount = 0

    func run() async {
        guard !inPing else {
            logger.info("Ping is already running.")
            NotificationCenter.default.post(name: NOTIFY_UPDATE_Ping, object: "Ping 已经在运行中")
            return
        }
        inPing = true
        killAllPing()
        finishedCount = 0

        let items = ProfileStore.shared.fetchAll()
        guard !items.isEmpty else {
            logger.info("No items to ping.")
            inPing = false
            NotificationCenter.default.post(name: NOTIFY_UPDATE_Ping, object: "没有可 Ping 的节点")
            return
        }

        totalCount = items.count

        Task {
            await AppMenuManager.shared.refreshPingTip(pingTip: " - " + String(localized: .Testing) + "(\(finishedCount)/\(totalCount))")
        }

        logger.info("Ping started.")
        NotificationCenter.default.post(name: NOTIFY_UPDATE_Ping, object: "开始 Ping 所有节点")
        await pingTaskGroup(items: items)
    }

    // MARK: - Fix 1: 改为 async func，避免在 closure 内跨 actor 边界访问 self

    private func pingTaskGroup(items: [ProfileEntity]) async {
        // MARK: - Fix 6: pingOne 也需要设置 inPing，统一通过此函数

        let maxPublishers = maxConcurrentTasks

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            items.publisher
                .flatMap(maxPublishers: .max(maxPublishers)) { item in
                    Future<Void, Never> { promise in
                        Task {
                            do {
                                NotificationCenter.default.post(name: NOTIFY_UPDATE_Ping, object: "Ping-start: \(item.remark)")
                                try await self.pingEachServer(item: item)
                            } catch {
                                NotificationCenter.default.post(name: NOTIFY_UPDATE_Ping, object: "Ping-fail: \(item.remark) - \(error.localizedDescription)")
                            }
                            // 无论成功失败都 resolve，不让单个失败终止 stream
                            promise(.success(()))
                        }
                    }
                }
                .collect()
                .sink(receiveCompletion: { completion in
                    switch completion {
                    case .finished:
                        NotificationCenter.default.post(name: NOTIFY_UPDATE_Ping, object: "Ping-all-done\n")
                        logger.info("Ping completed")
                        Task {
                            await AppMenuManager.shared.refreshServerItems()
                        }
                    case .failure:
                        break
                    }

                    Task { [weak self] in
                        try? await Task.sleep(nanoseconds: 2000000000)
                        killAllPing()
                        await AppMenuManager.shared.refreshPingTip(pingTip: "")
                        await self?.setInPingFalse()
                    }

                    continuation.resume()
                }, receiveValue: { _ in })
                .store(in: &self.cancellables)
        }
    }

    private func setInPingFalse() async {
        logger.info("setInPingFalse")
        inPing = false
    }

    private func pingEachServer(item: ProfileEntity) async throws {
        let ping = PingServer(uuid: item.uuid)
        try await ping.doPing()
        let speed = await ping.getSpeed()

        // MARK: - Fix 2: 在任务完成后再递增计数，进度条有实际意义

        finishedCount += 1

        Task {
            await AppMenuManager.shared.refreshPingTip(pingTip: " - " + String(localized: .Testing) + "(\(finishedCount)/\(totalCount))")
        }

        NotificationCenter.default.post(name: NOTIFY_UPDATE_Ping, object: "Ping-done: \(item.remark) - \(speed) ms")
    }

    // MARK: - Fix 6: pingOne 检查 inPing 状态，防止与 run() 并发

    func pingOne(item: ProfileEntity) async {
        guard !inPing else {
            logger.info("Ping is already running, skip pingOne.")
            NotificationCenter.default.post(name: NOTIFY_UPDATE_Ping, object: "Ping 已在运行中，跳过单节点 Ping")
            return
        }
        inPing = true
        defer {
            Task { await self.setInPingFalse() }
        }
        NotificationCenter.default.post(name: NOTIFY_UPDATE_Ping, object: "开始 Ping 节点")
        await pingTaskGroup(items: [item])
    }
}

actor PingServer {
    private var uuid: String = ""
    private var item: ProfileEntity = ProfileEntity()
    private var process: Process = Process()
    private var jsonFile: String = ""
    private var bindPort: UInt16 = 0

    init(uuid: String) {
        self.uuid = uuid
    }

    func getSpeed() -> Int {
        return item.speed
    }

    func doPing() async throws {
        guard let item = ProfileStore.shared.fetchOne(uuid: uuid) else {
            throw NSError(domain: "PingServerError", code: 404, userInfo: [NSLocalizedDescriptionKey: "Item not found"])
        }
        self.item = item
        bindPort = getRandomPort()
        jsonFile = "\(AppHomePath)/.config.\(item.uuid).json"

        createV2rayJsonFileForPing()

        try await launchProcess()
        try await ping()
        terminate()
    }

    private func ping() async throws {
        defer {
            ProfileStore.shared.updateSpeed(uuid: self.item.uuid, speed: self.item.speed)
        }
        do {
            let pingTime = try await testLatencyByProxyPort(port: bindPort)
            item.speed = pingTime
            let runningProfile = await AppState.shared.runningProfile
            if item.uuid == runningProfile {
                await AppState.shared.setLatency(latency: Double(pingTime))
            }
            logger.info("Ping success: \(self.item.remark), \(self.item.uuid) \(pingTime)ms")
            NotificationCenter.default.post(name: NOTIFY_UPDATE_Ping, object: "Ping-success: \(self.item.remark) - \(pingTime)ms")
        } catch {
            item.speed = -1
            let runningProfile = await AppState.shared.runningProfile
            if item.uuid == runningProfile {
                await AppState.shared.setLatency(latency: -1)
            }
            NotificationCenter.default.post(name: NOTIFY_UPDATE_Ping, object: "Ping-error: \(item.remark) - \(error)")
            logger.info("Ping error: \(self.item.remark), \(self.item.uuid) \(error)")
        }
    }

    private func terminate() {
        logger.info("ping end: \(self.item.remark) - \(self.item.speed)")
        do {
            if process.isRunning {
                process.interrupt()
                process.terminate()
                process.waitUntilExit()
            }
            try FileManager.default.removeItem(at: URL(fileURLWithPath: jsonFile))
        } catch {
            logger.info("remove ping config error: \(error)")
        }
    }

    private func createV2rayJsonFileForPing() {
        let vCfg = CoreConfigHandler()
        let jsonText = vCfg.toJSON(item: item, httpPort: String(bindPort))
        do {
            try jsonText.write(to: URL(fileURLWithPath: jsonFile), atomically: true, encoding: .utf8)
        } catch {
            logger.info("Failed to write JSON file: \(error)")
        }
    }

    private func createProcess(command: String) -> Process {
        let process = Process()
        process.launchPath = "/bin/bash"
        process.arguments = ["-c", command]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        process.terminationHandler = { _process in
            if _process.terminationStatus != EXIT_SUCCESS {
                _process.terminate()
                _process.waitUntilExit()
            }
        }
        return process
    }

    private func launchProcess() async throws {
        let corePath = item.getCoreFile()
        let pingCmd = "cd \(AppHomePath) && \(corePath) run -c \(jsonFile)"
        process = createProcess(command: pingCmd)
        process.launch()

        let ready = await waitForPortReady(bindPort, timeout: 2)
        if !ready {
            terminate()
            throw NSError(domain: "PingServerError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Port \(bindPort) not ready after timeout"])
        }
    }

    private func waitForPortReady(_ port: UInt16, timeout: TimeInterval = 5) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if isPortOpen(port) { return true }
            try? await Task.sleep(nanoseconds: 200000000)
        }
        return false
    }
}

actor PingRunning {
    static let shared = PingRunning()

    private let maxRetries = 3
    private let maxFailures = 3

    private var failureCount = 0
    private var isExecuting = false
    private var item: ProfileEntity = ProfileEntity()

    /// 开始 Ping 流程
    func startPing() async throws {
        guard !isExecuting else {
            logger.info("Ping task is already running.")
            return
        }
        guard let item = ProfileStore.shared.getRunning() else {
            noticeTip(title: "启动失败", informativeText: "配置文件不存在")
            return
        }
        self.item = item
        NotificationCenter.default.post(name: NOTIFY_UPDATE_Ping, object: "开始单节点 Ping: \(item.remark)")
        // 睡眠
        try await Task.sleep(nanoseconds: 2 * 1000000000) // Wait for 2 seconds
        // 替换
        // 控制
        isExecuting = true
        defer { isExecuting = false }

        var retries = 0
        var success = false
        let port = getHttpProxyPort()
        while retries < maxRetries && !success {
            do {
                let pingTime = try await testLatencyByProxyPort(port: port)
                logger.info("Ping success, time: \(pingTime)ms")
                NotificationCenter.default.post(name: NOTIFY_UPDATE_Ping, object: "Ping 成功: \(item.remark) - \(pingTime)ms")
                resetFailureCount()
                success = true
            } catch {
                retries += 1
                NotificationCenter.default.post(name: NOTIFY_UPDATE_Ping, object: "Ping 失败: \(item.remark) - 第\(retries)次: \(error.localizedDescription)")
                logger.info("Ping failed (\(retries)/\(self.maxRetries)): \(error)")
            }
        }

        if !success {
            await handleFailure()
        } else {
            NotificationCenter.default.post(name: NOTIFY_UPDATE_Ping, object: "完成单节点 Ping: \(item.remark)")
        }
    }

    private func updateSpeed(pingTime: Int) {
        // 更新 speed
        Task {
            await AppState.shared.setLatency(latency: Double(pingTime))
        }
        ProfileStore.shared.updateSpeed(uuid: item.uuid, speed: pingTime)
    }

    /// 重置失败计数
    private func resetFailureCount() {
        failureCount = 0
    }

    /// 处理失败逻辑
    private func handleFailure() async {
        // 更新 ping 结果
        updateSpeed(pingTime: -1)
        failureCount += 1
        if failureCount >= maxFailures {
            failureCount = 0
            logger.info("Ping failed \(self.maxFailures) times, switching to backup...")
            await switchServer()
        }
    }

    /// 切换到备用服务器
    private func switchServer() async {
        // 实现切换逻辑，比如更新 AppState.shared.pingURL 或其他参数
        await chooseNewServer(uuid: item.uuid)
    }

    func chooseNewServer(uuid: String) async {
        guard UserDefaults.getBool(forKey: .autoSelectFastestServer) else {
            logger.info(" - choose new server: disabled")
            return
        }

        let serverList = ProfileStore.shared.fetchAll()
        guard serverList.count > 1 else {
            return
        }

        var pingedSvrs = [String: Int]()
        var allSvrs = [String]()

        for svr in serverList where svr.uuid != uuid {
            allSvrs.append(svr.uuid)
            if svr.speed != -1 {
                pingedSvrs[svr.uuid] = svr.speed
            }
        }

        let newSvrName: String
        if let fastestSvr = pingedSvrs.sorted(by: { $0.value < $1.value }).first {
            newSvrName = fastestSvr.key
        } else if let randomSvr = allSvrs.randomElement() {
            newSvrName = randomSvr
        } else {
            return
        }

        logger.info(" - choose new server: \(newSvrName)")
        UserDefaults.set(forKey: .runningProfile, value: newSvrName)
        Task {
            await V2rayLaunch.shared.restart()
            await AppMenuManager.shared.refreshServerItems()
        }
    }
}

// MARK: - Fix 7: 预热和采样共享同一个 session，确保连接池复用真正生效

func testLatencyByProxyPort(port: UInt16) async throws -> Int {
    logger.info("testLatencyByProxyPort: \(port)")
    let configuration = getProxyUrlSessionConfigure(httpProxyPort: port)

    // 预热：用同一个 session 暖化连接池
    let warmupSession = URLSession(configuration: configuration, delegate: nil, delegateQueue: nil)
    defer { warmupSession.finishTasksAndInvalidate() }
    _ = try await performLatencyRequest(session: warmupSession)

    // 采样：复用相同 configuration，共享连接
    var samples: [Int] = []
    for _ in 0 ..< 1 {
        let pingTime = try await performLatencyRequestWithMetrics(configuration: configuration)
        samples.append(pingTime)
    }

    let pingTime = samples.min() ?? -1
    logger.info("testLatencyByProxyPort-end: \(port) - \(pingTime)ms")
    return pingTime
}

private func performLatencyRequest(session: URLSession) async throws -> HTTPURLResponse {
    let (_, response) = try await session.data(for: URLRequest(url: AppSettings.shared.pingURL))

    guard let httpResponse = response as? HTTPURLResponse else {
        throw URLError(.badServerResponse)
    }
    guard httpResponse.statusCode == 204 else {
        throw URLError(.badServerResponse)
    }
    return httpResponse
}

// MARK: - Fix 7: 接收 configuration 而非 session，内部自行创建带 delegate 的 session

private func performLatencyRequestWithMetrics(configuration: URLSessionConfiguration) async throws -> Int {
    let url = await AppSettings.shared.pingURL

    return try await withCheckedThrowingContinuation { continuation in
        let delegate = LatencyMetricsDelegate(continuation: continuation)
        // session 由 delegate 持有引用，在 invalidate 后自动释放
        let metricsSession = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
        delegate.session = metricsSession // 弱持有 session 以便超时时主动 invalidate

        let task = metricsSession.dataTask(with: url)
        task.resume()

        // MARK: - Fix 4: 超时后 cancel task 并 invalidateAndCancel session，防止泄漏

        DispatchQueue.global().asyncAfter(deadline: .now() + 5) {
            guard !delegate.hasResumed else { return }
            task.cancel()
            metricsSession.invalidateAndCancel()
            // hasResumed 由 delegate 内部用 os_unfair_lock 保护，此处无需再设
            delegate.resumeWithError(NSError(domain: "Timeout", code: -1, userInfo: [NSLocalizedDescriptionKey: "Ping timeout"]))
        }
    }
}

// MARK: - Fix 3 & 4: 用 os_unfair_lock 保护 hasResumed，消除数据竞争；Fix 4: 持有 session 以便超时 invalidate

final class LatencyMetricsDelegate: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    var latencyMs: Int = -1
    private var continuation: CheckedContinuation<Int, Error>?

    // MARK: - Fix 3: 用锁保护共享状态，消除多线程数据竞争

    private var lock = os_unfair_lock()
    private(set) var hasResumed = false
    /// 弱引用 session，用于超时时 invalidate（session 强持有 delegate，不能强引用 session）
    weak var session: URLSession?

    init(continuation: CheckedContinuation<Int, Error>?) {
        self.continuation = continuation
        super.init()
    }

    func resumeWithLatency(_ latency: Int) {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        guard !hasResumed else { return }
        hasResumed = true
        session?.finishTasksAndInvalidate()
        continuation?.resume(returning: latency)
        continuation = nil
    }

    func resumeWithError(_ error: Error) {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        guard !hasResumed else { return }
        hasResumed = true
        continuation?.resume(throwing: error)
        continuation = nil
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        // 不需要处理 body
    }

    // MARK: - Fix 3: error == nil 时也检查，避免 metrics 未触发时 continuation 永久挂起

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            resumeWithError(error)
        }
        // error == nil 时由 didFinishCollecting 负责 resume；
        // 若 metrics 也未触发，超时逻辑兜底，不会永久挂起。
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
        guard let transactionMetrics = metrics.transactionMetrics.first,
              let fetchStart = transactionMetrics.fetchStartDate,
              let responseEnd = transactionMetrics.responseEndDate else {
            // metrics 数据不完整时用错误兜底，避免 continuation 泄漏
            resumeWithError(NSError(domain: "LatencyMetrics", code: -1, userInfo: [NSLocalizedDescriptionKey: "Incomplete metrics"]))
            return
        }

        let duration = responseEnd.timeIntervalSince(fetchStart)
        let latency = Int(duration * 1000)
        latencyMs = latency
        logger.info("LatencyMetrics: \(latency)ms")
        resumeWithLatency(latency)
    }
}
