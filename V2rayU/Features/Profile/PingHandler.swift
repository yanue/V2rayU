//
//  PingHandler.swift
//  V2rayU
//
//  Created by yanue on 2025/9/21.
//
import Foundation
import Combine

let NOTIFY_UPDATE_Ping = Notification.Name(rawValue: "NOTIFY_UPDATE_Ping")

actor PingAll {
    static let shared = PingAll()

    private(set) var inPing: Bool = false
    
    private let maxConcurrentTasks = 30
    private var cancellables = Set<AnyCancellable>()
    private var totalCount = 0
    private var finishedCount = 0
    
    func run() {
        guard !inPing else {
            logger.info("Ping is already running.")
            NotificationCenter.default.post(name: NOTIFY_UPDATE_Ping, object: "Ping 已经在运行中")
            return
        }
        inPing = true
        killAllPing()
        self.finishedCount = 0

        let items = ProfileStore.shared.fetchAll()
        guard !items.isEmpty else {
            logger.info("No items to ping.")
            NotificationCenter.default.post(name: NOTIFY_UPDATE_Ping, object: "没有可 Ping 的节点")
            return
        }

        totalCount = items.count
        
        Task {
            await AppMenuManager.shared.refreshPingTip(pingTip: " - " + String(localized: .Testing) + "(\(finishedCount)/\(totalCount))")
        }

        logger.info("Ping started.")
        NotificationCenter.default.post(name: NOTIFY_UPDATE_Ping, object: "开始 Ping 所有节点")
        pingTaskGroup(items: items)
    }

    private func pingTaskGroup(items: [ProfileEntity]) {
        items.publisher
            .flatMap(maxPublishers: .max(self.maxConcurrentTasks)) { item in
                Future<Void, Error> { promise in
                    Task {
                        do {
                            NotificationCenter.default.post(name: NOTIFY_UPDATE_Ping, object: "Ping-start: \(item.remark)")
                            try await self.pingEachServer(item: item)
                            promise(.success(()))
                        } catch {
                            NotificationCenter.default.post(name: NOTIFY_UPDATE_Ping, object: "Ping-fail: \(item.remark) - \(error.localizedDescription)")
                            promise(.failure(error))
                        }
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
                        await AppMenuManager.shared.refreshServerItems() // 刷新servers
                    }
                case let .failure(error):
                    NotificationCenter.default.post(name: NOTIFY_UPDATE_Ping, object: "Ping-some-failed: \(error.localizedDescription)")
                    logger.info("Ping Error: \(error)")
                    Task {
                        await AppMenuManager.shared.refreshServerItems() // 刷新servers
                    }
                }
                killAllPing()
                
                // 在actor中,可以内部用 Task.sleep 2秒后设置为空
                Task { [weak self] in
                    try? await Task.sleep(nanoseconds: 2_000_000_000) // 2秒
                    await AppMenuManager.shared.refreshPingTip(pingTip: "")
                    // 不能直接设置,只能调用函数
                    await self?.setInPingFalse()
                }
            }, receiveValue: { _ in })
            .store(in: &cancellables)
    }
    
    private func setInPingFalse() {
        inPing = false
    }
    
    private func pingEachServer(item: ProfileEntity) async throws {
        let ping = PingServer(uuid: item.uuid)
        try await ping.doPing()
        let speed = await ping.getSpeed()

        // 更新进度
        finishedCount += 1
        
        Task {
            await AppMenuManager.shared.refreshPingTip(pingTip: " - " + String(localized: .Testing) + "(\(finishedCount)/\(totalCount))")
        }

        NotificationCenter.default.post(name: NOTIFY_UPDATE_Ping, object: "Ping-done: \(item.remark) - \(speed) ms")
    }
    
    func pingOne(item: ProfileEntity) {
        // 开始执行异步任务
        NotificationCenter.default.post(name: NOTIFY_UPDATE_Ping, object: "开始 Ping 节点")
        self.pingTaskGroup(items: [item])
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
        return self.item.speed
    }
    
    func doPing() async throws {
        guard let item = ProfileStore.shared.fetchOne(uuid: uuid) else {
            throw NSError(domain: "PingServerError", code: 404, userInfo: [NSLocalizedDescriptionKey: "Item not found"])
        }
        self.item = item
        self.bindPort = getRandomPort()
        self.jsonFile = "\(AppHomePath)/.config.\(item.uuid).json"
        
        self.createV2rayJsonFileForPing()
        
        // 启动并等待端口 ready
        try await launchProcess()
        
        // 端口 ready 后直接 ping
        try await ping()
        
        // 释放资源
        self.terminate()
    }
    
    private func ping() async throws {
        defer {
            ProfileStore.shared.update_speed(uuid: self.item.uuid, speed: self.item.speed)
        }
        do {
            let pingTime = try await testLatencyByProxyPort(port: self.bindPort)
            self.item.speed = pingTime
            logger.info("Ping success: \(self.item.remark), \(self.item.uuid) \(pingTime)ms")
            NotificationCenter.default.post(name: NOTIFY_UPDATE_Ping, object: "Ping-success: \(item.remark) - \(pingTime)ms")
        } catch {
            // ping 失败
            self.item.speed = -1
            NotificationCenter.default.post(name: NOTIFY_UPDATE_Ping, object: "Ping-error: \(item.remark) - \(error)")
            logger.info("Ping error: \(self.item.remark), \(self.item.uuid) \(error)")
        }
    }
    
    private func terminate() {
        logger.info("ping end: \(self.item.remark) - \(self.item.speed)")
        do {
            if self.process.isRunning {
                self.process.interrupt()
                self.process.terminate()
                self.process.waitUntilExit()
            }
            try FileManager.default.removeItem(at: URL(fileURLWithPath: jsonFile))
        } catch {
            logger.info("remove ping config error: \(error)")
        }
    }
    
    private func createV2rayJsonFileForPing() {
        let vCfg = V2rayConfigHandler()
        let jsonText = vCfg.toJSON(item: item, httpPort: String(self.bindPort))
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
        
        // 需要设置为nullDevice,不然会导致输出缓冲区阻塞,从而崩溃
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
        let corePath = self.item.getCoreFile()
        let pingCmd = "cd \(AppHomePath) && \(corePath) run -config \(jsonFile)"
        self.process = createProcess(command: pingCmd)
        self.process.launch()
        
        // 等待端口 ready
        let ready = await waitForPortReady(self.bindPort, timeout: 2)
        if !ready {
            self.terminate()
        }
    }
    
    private func waitForPortReady(_ port: UInt16, timeout: TimeInterval = 5) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if isPortOpen(port) { return true }
            try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 秒
        }
        return false
    }
}

/// 执行 Ping 操作并返回响应时间（单位：毫秒）
func testLatencyByProxyPort(port: UInt16) async throws -> Int {
    logger.info("testLatencyByProxyPort: \(port)")
    let start = Date()
    
    // 使用 URLSession 测试延迟
    let session = URLSession(configuration: getProxyUrlSessionConfigure(httpProxyPort: port))
    let (_, response) = try await session.data(for: URLRequest(url: AppSettings.shared.pingURL))

    // 这里可以根据 data 或 response 做更多校验
    guard let httpResponse = response as? HTTPURLResponse else {
        throw URLError(.badServerResponse)
    }

    // 只接受 204 状态码
    guard httpResponse.statusCode == 204 else {
        throw URLError(.badServerResponse)
    }
    
    // 最终延迟
    let pingTime = Int(Date().timeIntervalSince(start) * 1000)
    logger.info("testLatencyByProxyPort-end: \(port) - \(pingTime)ms")
    return pingTime
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
        try await Task.sleep(nanoseconds: 2 * 1_000_000_000) // Wait for 2 seconds
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
        ProfileStore.shared.update_speed(uuid: self.item.uuid, speed: pingTime)
    }
    
    /// 重置失败计数
    private func resetFailureCount() {
        failureCount = 0
    }

    /// 处理失败逻辑
    private func handleFailure() async {
        // 更新 ping 结果
        self.updateSpeed(pingTime: -1)
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
        await chooseNewServer(uuid: self.item.uuid)
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
        
        for svr in serverList where svr.uuid !=  uuid {
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
            await AppMenuManager.shared.refreshServerItems() // 刷新servers
        }
    }
}
