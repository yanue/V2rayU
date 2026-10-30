//
//  ProfileSpeedTest.swift
//  V2rayU
//
//  真实下载测速: 单独起一个核心实例, 通过它的 http 入站拉一个测速文件若干秒, 算平均下载速度 (字节/秒) 存到节点上
//  延迟低但带宽差的节点靠这个才能筛出来
//

import Foundation

let defaultSpeedTestUrl = "https://speed.cloudflare.com/__down?bytes=100000000"
let NOTIFY_UPDATE_SPEED_TEST = Notification.Name(rawValue: "NOTIFY_UPDATE_SPEED_TEST")

enum SpeedTestSettings {
    /// 用户自定义地址优先, 之后按顺序兜底 (有的地区 Cloudflare 直接 403)
    static let fallbackUrls = [
        defaultSpeedTestUrl,
        "https://cachefly.cachefly.net/50mb.test",
        "https://download.parallels.com/desktop/v17/17.1.4-51567/ParallelsDesktop-17.1.4-51567.dmg",
    ]

    static var urls: [String] {
        let custom = UserDefaults.get(forKey: .speedTestUrl, defaultValue: "").trimmingCharacters(in: .whitespacesAndNewlines)
        var list = fallbackUrls
        if !custom.isEmpty { list.insert(custom, at: 0) }
        return list
    }
    /// 最多下载这么久, 到时间就按已收到的字节算
    static let maxDuration: TimeInterval = 8
    static let minBytesForValidResult = 64 * 1024
}

/// 字节/秒 → "12.3 MB/s"
func formatDownloadSpeed(_ bytesPerSecond: Int) -> String {
    guard bytesPerSecond > 0 else { return "-" }
    return formatBytesFixed(Double(bytesPerSecond), base: 1024) + "/s"
}

/// 边收边计时: 收到的字节数和耗时算平均速度, 超时就停
final class SpeedTestCollector: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    private let lock = NSLock()
    private var received = 0
    private let start = Date()
    private let maxDuration: TimeInterval
    private var finished = false
    private var continuation: CheckedContinuation<(bytes: Int, seconds: Double), Error>?

    init(maxDuration: TimeInterval) {
        self.maxDuration = maxDuration
    }

    /// 先装好 continuation 再启动任务, 不然任务秒失败时回调先到, continuation 永远没人唤醒
    func result(starting task: URLSessionTask) async throws -> (bytes: Int, seconds: Double) {
        try await withCheckedThrowingContinuation { c in
            lock.lock(); continuation = c; lock.unlock()
            task.resume()
        }
    }

    private func finish(_ error: Error?, task: URLSessionTask?) {
        lock.lock()
        guard !finished else { lock.unlock(); return }
        finished = true
        let c = continuation
        continuation = nil
        let bytes = received
        lock.unlock()
        task?.cancel()
        let seconds = Date().timeIntervalSince(start)
        if let error, bytes == 0 {
            c?.resume(throwing: error)
        } else {
            c?.resume(returning: (bytes, seconds))
        }
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        lock.lock()
        received += data.count
        let elapsed = Date().timeIntervalSince(start)
        lock.unlock()
        if elapsed >= maxDuration { finish(nil, task: dataTask) }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        // 主动 cancel 也会回调, 已结束的忽略
        finish(error, task: nil)
    }
}

actor ProfileSpeedTest {
    private let uuid: String
    private var item = ProfileEntity()
    private var process = Process()
    private var jsonFile = ""
    private var httpPort: UInt16 = 0

    init(uuid: String) {
        self.uuid = uuid
    }

    /// 返回字节/秒; 失败抛错并把节点速度记成 0
    @discardableResult
    func run() async throws -> Int {
        guard let fetched = ProfileStore.shared.fetchOne(uuid: uuid) else {
            throw NSError(domain: "ProfileSpeedTest", code: 404, userInfo: [NSLocalizedDescriptionKey: "Item not found"])
        }
        item = await CertPinningCoordinator.ensurePinnedCert(for: fetched)
        httpPort = getRandomPort()
        jsonFile = "\(AppHomePath)/.speedtest.\(item.uuid).json"
        defer {
            terminate()
            try? FileManager.default.removeItem(atPath: jsonFile)
        }
        do {
            try writeConfig()
            try await launch()
            let speed = try await Self.measureWithFallback(httpPort: httpPort)
            ProfileStore.shared.updateDownloadSpeed(uuid: item.uuid, speed: speed)
            NotificationCenter.default.post(name: NOTIFY_UPDATE_SPEED_TEST, object: "Speed: \(item.remark) - \(formatDownloadSpeed(speed))")
            logger.info("speed test ok: \(self.item.remark) \(formatDownloadSpeed(speed))")
            return speed
        } catch {
            ProfileStore.shared.updateDownloadSpeed(uuid: item.uuid, speed: 0)
            NotificationCenter.default.post(name: NOTIFY_UPDATE_SPEED_TEST, object: "Speed-error: \(item.remark) - \(error.localizedDescription)")
            logger.info("speed test fail: \(self.item.remark) \(error.localizedDescription)")
            throw error
        }
    }

    /// 按地址列表依次试, 第一个拉到数据的算数
    static func measureWithFallback(httpPort: UInt16, urls: [String] = SpeedTestSettings.urls) async throws -> Int {
        var lastError: Error = URLError(.unknown)
        for url in urls {
            do {
                return try await measure(httpPort: httpPort, url: url)
            } catch {
                lastError = error
                logger.info("speed test url failed, try next: \(url) \(error.localizedDescription)")
            }
        }
        throw lastError
    }

    /// 经 127.0.0.1:httpPort 的 http 代理下载, 返回字节/秒
    static func measure(httpPort: UInt16, url: String, maxDuration: TimeInterval = SpeedTestSettings.maxDuration) async throws -> Int {
        guard let testUrl = URL(string: url) else { throw URLError(.badURL) }
        let config = getProxyUrlSessionConfigure(httpProxyPort: httpPort)
        config.timeoutIntervalForRequest = 15
        config.urlCache = nil
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        let collector = SpeedTestCollector(maxDuration: maxDuration)
        let session = URLSession(configuration: config, delegate: collector, delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        var request = URLRequest(url: testUrl)
        request.setValue("V2rayU/\(getAppVersion())", forHTTPHeaderField: "User-Agent")
        let (bytes, seconds) = try await collector.result(starting: session.dataTask(with: request))
        guard bytes >= SpeedTestSettings.minBytesForValidResult, seconds > 0 else {
            throw NSError(domain: "ProfileSpeedTest", code: 1, userInfo: [NSLocalizedDescriptionKey: "too little data received (\(bytes) bytes)"])
        }
        return Int(Double(bytes) / seconds)
    }

    private func writeConfig() throws {
        let jsonText = CoreConfigHandler().toJSON(item: item, httpPort: String(httpPort))
        try jsonText.write(to: URL(fileURLWithPath: jsonFile), atomically: true, encoding: .utf8)
    }

    private func launch() async throws {
        let corePath = getCoreFile(mode: item.AdaptCore())
        // 直接起核心进程, 不套 bash: 套了 bash 的话 terminate 只杀得掉 bash, 核心成孤儿一直占着端口
        process = Process()
        process.executableURL = URL(fileURLWithPath: corePath)
        process.arguments = ["run", "-c", jsonFile]
        process.currentDirectoryURL = URL(fileURLWithPath: AppHomePath)
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        let deadline = Date().addingTimeInterval(3)
        while Date() < deadline {
            if isPortOpen(httpPort) { return }
            try? await Task.sleep(nanoseconds: 200_000_000)
        }
        throw NSError(domain: "ProfileSpeedTest", code: -1, userInfo: [NSLocalizedDescriptionKey: "core not ready on port \(httpPort)"])
    }

    private func terminate() {
        if process.isRunning {
            process.terminate()
            process.waitUntilExit()
        }
    }
}

/// 批量测速: 一个一个来, 并发会互相抢带宽; 测试中又点了别的节点就排队, 不丢
actor SpeedTestRunner {
    static let shared = SpeedTestRunner()
    private var running = false
    private var pending: [String] = []

    var isRunning: Bool { running }

    func run(uuids: [String]) async {
        for uuid in uuids where !pending.contains(uuid) { pending.append(uuid) }
        guard !running else { return }
        running = true
        defer { running = false }
        while !pending.isEmpty {
            let uuid = pending.removeFirst()
            _ = try? await ProfileSpeedTest(uuid: uuid).run()
        }
        await AppMenuManager.shared.refreshServerItems()
    }
}
