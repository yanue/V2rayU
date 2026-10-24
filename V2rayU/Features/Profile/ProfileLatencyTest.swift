//
//  ProfileLatencyTest.swift
//  V2rayU
//
//  Created by yanue on 2025/9/21.
//
import Foundation

let NOTIFY_UPDATE_LATENCY_TEST = Notification.Name(rawValue: "NOTIFY_UPDATE_LATENCY_TEST")

actor LatencyTestRunner {
    static let shared = LatencyTestRunner()

    private(set) var inPing: Bool = false
    /// 每轮测速的编号; 结束后的延迟清理只在期间没有开始新一轮时执行
    private var runID = 0

    private var totalCount = 0
    private var finishedCount = 0

    private func localized(_ label: LanguageLabel, _ arguments: CVarArg...) async -> String {
        let format = await MainActor.run { LanguageManager.shared.localizedString(label.rawValue) }
        if arguments.isEmpty { return format }
        return String(format: format, arguments: arguments)
    }

    func runAll() async {
        guard !inPing else {
            logger.info("Ping is already running.")
            NotificationCenter.default.post(name: NOTIFY_UPDATE_LATENCY_TEST, object: await localized(.PingAlreadyRunning))
            return
        }
        inPing = true
        killAllPing()
        finishedCount = 0

        let items = ProfileStore.shared.fetchAll()
        guard !items.isEmpty else {
            logger.info("No items to ping.")
            inPing = false
            NotificationCenter.default.post(name: NOTIFY_UPDATE_LATENCY_TEST, object: await localized(.PingNoNodes))
            return
        }

        totalCount = items.count

        Task {
            await AppMenuManager.shared.refreshPingTip(pingTip: " - " + String(localized: .Testing) + "(\(finishedCount)/\(totalCount))")
        }

        logger.info("Ping started.")
        NotificationCenter.default.post(name: NOTIFY_UPDATE_LATENCY_TEST, object: await localized(.PingStartAll))
        await pingTaskGroup(items: items)
    }

    // MARK: - Fix 1: 改为 async func，避免在 closure 内跨 actor 边界访问 self

    private func pingTaskGroup(items: [ProfileEntity]) async {
        // MARK: - Fix 6: pingOne 也需要设置 inPing，统一通过此函数

        runID += 1
        let currentRun = runID
        let maxPublishers = await AppSettings.shared.safeLatencyTestConcurrency

        // 替代 Combine flatMap(maxPublishers:) + withCheckedContinuation，
        // checked continuation 在 main queue 上恢复时触发了 actor 执行器检查失败（SIGABRT）。
        // TaskGroup 直接使用结构化并发，无此问题。
        await withTaskGroup(of: Void.self) { group in
            var count = 0
            for item in items {
                if count >= maxPublishers {
                    await group.next()
                }
                count += 1
                group.addTask {
                    NotificationCenter.default.post(name: NOTIFY_UPDATE_LATENCY_TEST, object: "Ping-start: \(item.remark)")
                    do {
                        try await self.pingEachServer(item: item)
                    } catch {
                        NotificationCenter.default.post(name: NOTIFY_UPDATE_LATENCY_TEST, object: "Ping-fail: \(item.remark) - \(error.localizedDescription)")
                    }
                }
            }
        }

        NotificationCenter.default.post(name: NOTIFY_UPDATE_LATENCY_TEST, object: "Ping-all-done\n")
        logger.info("Ping completed")
        await AppMenuManager.shared.refreshServerItems()

        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2000000000)
            await self?.cleanUp(after: currentRun)
        }
    }

    /// 清理测速残留的核心进程; 这 2 秒内若已开始新一轮(如 runOne 结束后紧接着测下一个), 不能杀掉新一轮的进程
    private func cleanUp(after run: Int) async {
        guard run == runID else { return }
        killAllPing()
        await AppMenuManager.shared.refreshPingTip(pingTip: "")
        setInPingFalse()
    }

    private func setInPingFalse() {
        logger.info("setInPingFalse")
        inPing = false
    }

    private func pingEachServer(item: ProfileEntity) async throws {
        let ping = ProfileLatencyTest(uuid: item.uuid)
        try await ping.run()
        let speed = await ping.getSpeed()

        // MARK: - Fix 2: 在任务完成后再递增计数，进度条有实际意义

        finishedCount += 1

        Task {
            await AppMenuManager.shared.refreshPingTip(pingTip: " - " + String(localized: .Testing) + "(\(finishedCount)/\(totalCount))")
        }

        NotificationCenter.default.post(name: NOTIFY_UPDATE_LATENCY_TEST, object: "Ping-done: \(item.remark) - \(speed) ms")
    }

    // MARK: - Fix 6: pingOne 检查 inPing 状态，防止与 run() 并发

    func runOne(item: ProfileEntity) async {
        guard !inPing else {
            logger.info("Ping is already running, skip pingOne.")
            NotificationCenter.default.post(name: NOTIFY_UPDATE_LATENCY_TEST, object: await localized(.PingSingleAlreadyRunning))
            return
        }
        inPing = true
        defer {
            Task { await self.setInPingFalse() }
        }
        NotificationCenter.default.post(name: NOTIFY_UPDATE_LATENCY_TEST, object: await localized(.PingStartNode))
        await pingTaskGroup(items: [item])
    }
}

actor ProfileLatencyTest {
    private var uuid: String = ""
    private var item: ProfileEntity = ProfileEntity()
    private var process: Process = Process()
    private var jsonFile: String = ""
    private var bindPort: UInt16 = 0
    /// 测速用的 latency-in SOCKS 入站端口
    private var latencyPort: UInt16 = 0
    private var coreType: CoreType = .XrayCore

    private var serverIpCache: [String: String] = [:]

    init(uuid: String) {
        self.uuid = uuid
    }

    func getSpeed() -> Int {
        return item.speed
    }

    func run() async throws {
        guard let fetched = ProfileStore.shared.fetchOne(uuid: uuid) else {
            throw NSError(domain: "ProfileLatencyTestError", code: 404, userInfo: [NSLocalizedDescriptionKey: "Item not found"])
        }
        // 测试前自动获取证书指纹（allowInsecure 已被新 Xray-core 移除）；失败则由 AdaptCore 回退 Sing-Box。
        let item = await CertPinningCoordinator.ensurePinnedCert(for: fetched)
        self.item = item
        bindPort = getRandomPort()
        repeat {
            latencyPort = getRandomPort()
        } while latencyPort == bindPort
        coreType = item.AdaptCore()
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
            let pingTime = try await LatencyTester.test(socksPort: latencyPort)
            item.speed = pingTime

            if let serverIp = await fetchServerIp(port: bindPort), !serverIp.isEmpty {
                item.serverIp = serverIp
                ProfileStore.shared.updateServerIp(uuid: self.item.uuid, serverIp: serverIp)

                if let serverRegion = await fetchServerLocation(ip: serverIp), !serverRegion.isEmpty {
                    item.serverRegion = serverRegion
                    ProfileStore.shared.updateServerRegion(uuid: self.item.uuid, serverRegion: serverRegion)
                    logger.info("Server IP location: \(self.item.remark), \(serverIp) -> \(serverRegion)")
                }
            }

            logger.info("Ping success: \(self.item.remark), \(self.item.uuid) \(pingTime)ms")
            NotificationCenter.default.post(name: NOTIFY_UPDATE_LATENCY_TEST, object: "Ping-success: \(self.item.remark) - \(pingTime)ms")
        } catch {
            item.speed = -1
            NotificationCenter.default.post(name: NOTIFY_UPDATE_LATENCY_TEST, object: "Ping-error: \(self.item.remark) - \(error)")
            logger.info("Ping error: \(self.item.remark), \(self.item.uuid) \(error)")
        }
    }

    private func fetchServerIp(port: UInt16) async -> String? {
        return await withCheckedContinuation { continuation in
            let currentConnectionTestURL = UserDefaults.get(forKey: .currentConnectionTestURL, defaultValue: defaultCurrentConnectionTestURL)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let url = URL(string: currentConnectionTestURL.isEmpty ? "https://api.ipify.org?format=json" : currentConnectionTestURL)
                ?? URL(string: "https://api.ipify.org?format=json")!
            let configuration = getProxyUrlSessionConfigure(httpProxyPort: port)
            let session = URLSession(configuration: configuration)

            final class ResumableHolder: @unchecked Sendable {
                var done = false
                var lock = os_unfair_lock()
            }
            let holder = ResumableHolder()

            let finish: @Sendable (String?) -> Void = { result in
                os_unfair_lock_lock(&holder.lock)
                let already = holder.done
                if !already { holder.done = true }
                os_unfair_lock_unlock(&holder.lock)
                guard !already else { return }
                session.invalidateAndCancel()
                continuation.resume(returning: result)
            }

            let task = session.dataTask(with: url) { data, _, error in
                guard error == nil, let data = data,
                      let ip = self.parseIPFromConnectionInfo(data: data) else {
                    finish(nil)
                    return
                }
                finish(ip)
            }
            task.resume()

            DispatchQueue.global().asyncAfter(deadline: .now() + 5) {
                finish(nil)
            }
        }
    }

    private nonisolated func parseIPFromConnectionInfo(data: Data) -> String? {
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            for key in ["ip", "origin", "query"] {
                if let value = json[key] as? String,
                   let ip = extractFirstIP(from: value) {
                    return ip
                }
            }
        }

        guard let text = String(data: data, encoding: .utf8) else {
            return nil
        }
        return extractFirstIP(from: text)
    }

    private nonisolated func extractFirstIP(from text: String) -> String? {
        let pattern = #"\b(?:\d{1,3}\.){3}\d{1,3}\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range, in: text) else {
            return nil
        }
        return String(text[range])
    }

    private func fetchServerLocation(ip: String) async -> String? {
        if let cached = serverIpCache[ip] {
            return cached
        }

        guard let url = URL(string: "http://ip-api.com/json/\(ip)?fields=countryCode") else {
            return nil
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return nil
            }

            if let status = json["status"] as? String, status == "fail" {
                return nil
            }

            if let countryCode = json["countryCode"] as? String, !countryCode.isEmpty {
                serverIpCache[ip] = countryCode
                return countryCode
            }

            return nil
        } catch {
            logger.error("fetchServerLocation error: \(error)")
            return nil
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
        let jsonText = vCfg.toJSON(item: item, httpPort: String(bindPort), latencyPort: String(latencyPort))
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
        let corePath = getCoreFile(mode: coreType)
        let pingCmd = "cd \(AppHomePath) && \(corePath) run -c \(jsonFile)"
        process = createProcess(command: pingCmd)
        process.launch()

        let ready = await waitForPortReady(bindPort, timeout: 2)
        if !ready {
            terminate()
            throw NSError(domain: "ProfileLatencyTestError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Port \(bindPort) not ready after timeout"])
        }
        let latencyReady = await waitForPortReady(latencyPort, timeout: 2)
        if !latencyReady {
            terminate()
            throw NSError(domain: "ProfileLatencyTestError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Latency port \(latencyPort) not ready after timeout"])
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

actor RunningProfileCheck {
    static let shared = RunningProfileCheck()

    private let maxRetries = 3
    private let maxFailures = 3

    private var failureCount = 0
    private var isExecuting = false
    private var item: ProfileEntity = ProfileEntity()

    private func localized(_ label: LanguageLabel, _ arguments: CVarArg...) async -> String {
        let format = await MainActor.run { LanguageManager.shared.localizedString(label.rawValue) }
        if arguments.isEmpty { return format }
        return String(format: format, arguments: arguments)
    }

    /// 开始 Ping 流程
    func check() async throws {
        guard !isExecuting else {
            logger.info("Ping task is already running.")
            return
        }
        guard let item = ProfileStore.shared.getRunning() else {
            let title = await localized(.StartFailed)
            let message = await localized(.DiagConfigFileMissing)
            noticeTip(title: title, informativeText: message)
            return
        }
        self.item = item
        NotificationCenter.default.post(name: NOTIFY_UPDATE_LATENCY_TEST, object: await localized(.PingStartSingleNodeFormat, item.remark))
        // 睡眠
        try await Task.sleep(nanoseconds: 2 * 1000000000) // Wait for 2 seconds
        // 替换
        // 控制
        isExecuting = true
        defer { isExecuting = false }

        guard let port = LatencyTester.runningInboundPort() else {
            logger.info("RunningProfileCheck: no \(latencyInboundTag) inbound in config, skip")
            return
        }
        var retries = 0
        var success = false
        while retries < maxRetries && !success {
            do {
                let pingTime = try await LatencyTester.test(socksPort: port)
                logger.info("Ping success, time: \(pingTime)ms")
                NotificationCenter.default.post(name: NOTIFY_UPDATE_LATENCY_TEST, object: await localized(.PingSuccessFormat, item.remark, pingTime))
                resetFailureCount()
                success = true
            } catch {
                retries += 1
                NotificationCenter.default.post(name: NOTIFY_UPDATE_LATENCY_TEST, object: await localized(.PingFailureRetryFormat, item.remark, retries, error.localizedDescription))
                logger.info("Ping failed (\(retries)/\(self.maxRetries)): \(error)")
            }
        }

        if !success {
            await handleFailure()
        } else {
            NotificationCenter.default.post(name: NOTIFY_UPDATE_LATENCY_TEST, object: await localized(.PingCompleteSingleNodeFormat, item.remark))
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
