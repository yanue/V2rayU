import Foundation

struct Traffic: Codable {
    let up: Double
    let down: Double
}

func parseClashDelayValue(_ value: Any?) -> Double? {
    let delay: Double?
    switch value {
    case let number as NSNumber where !(number is Bool):
        delay = number.doubleValue
    case let string as String:
        delay = Double(string)
    default:
        delay = nil
    }
    guard let delay, delay.isFinite, delay > 0 else { return nil }
    return delay
}

func parseClashDelay(from data: Data) -> Double? {
    guard let result = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
    return parseClashDelayValue(result["delay"])
}

actor CoreTrafficStatsHandler {
    static let shared = CoreTrafficStatsHandler()
    
    private var directUpLink = 0
    private var directDownLink = 0
    private var proxyUpLink = 0
    private var proxyDownLink = 0

    var lastUpdate = Date()
    
    init() {}
    
    func resetData() {
        self.directDownLink = 0
        self.directUpLink = 0
        self.proxyDownLink = 0
        self.proxyUpLink = 0
        self.stopTask()
    }
    
    func startTask(coreType: CoreType) {
        self.stopTask()
        Task {
            // 判断coreType
            switch coreType {
            case .SingBox:
                // api stream 模式(更新流量统计)
                ClashApiStreamHandler.shared.startTask()
                // api request 模式(更新延迟)
                await ClashApilatencyHandler.shared.startTask()
            case .XrayCore:
                await XrayApiStatsHandler.shared.startTask()
            }
        }
    }

    func stopTask() {
        Task {
            ClashApiStreamHandler.shared.stopTask()
            await ClashApilatencyHandler.shared.stopTask()
            await XrayApiStatsHandler.shared.stopTask()
        }
    }

    func setTraffic(upLink: Double,downLink: Double) {
        Task {
            // 更新到 UI
            await AppState.shared.setTraffic(upSpeed: upLink/1024, downSpeed: downLink/1024 )
        }
    }

    func setSpeed(latency: Double, directUpLink: Int, directDownLink: Int, proxyUpLink: Int, proxyDownLink: Int) {
        let now = Date()
        let timeInterval = now.timeIntervalSince(lastUpdate)
        lastUpdate = now
        if timeInterval < 1 {
            return
        }
        // 计算速度（用增量除以时间）
        let directUpSpeed = (Double(directUpLink - self.directUpLink) / 1024  / timeInterval)
        let directDownSpeed = (Double(directDownLink - self.directDownLink) / 1024 / timeInterval)
        let proxyUpSpeed = (Double(proxyUpLink - self.proxyUpLink) / 1024 /  timeInterval)
        let proxyDownSpeed = (Double(proxyDownLink - self.proxyDownLink) / 1024 /  timeInterval)
        // 计算流量增量（当前累计值 - 上次累计值）
        let up = (directUpLink + proxyUpLink) - (self.directUpLink + self.proxyUpLink)
        let down = (directDownLink + proxyDownLink) - (self.directDownLink + self.proxyDownLink)
        // 保存当前累计值
        self.directUpLink = directUpLink
        self.directDownLink = directDownLink
        self.proxyUpLink = proxyUpLink
        self.proxyDownLink = proxyDownLink
        Task {
            // 更新到 UI
            await AppState.shared.setSpeed(latency: latency, directUpSpeed: directUpSpeed, directDownSpeed: directDownSpeed, proxyUpSpeed: proxyUpSpeed, proxyDownSpeed: proxyDownSpeed)
            let uuid = await AppState.shared.runningProfile
//             logger.info("setSpeed:\(now) - \(uuid) - \(up) - \(down) - \(latency) - \(timeInterval)")
            // 更新到数据库
            try ProfileStore.shared.updateStat(uuid: uuid, up: up, down: down, lastUpdate: now)
        }
    }
}

actor XrayApiStatsHandler: NSObject {
    static let shared = XrayApiStatsHandler()

    private var timer: DispatchSourceTimer?

    func startTask(interval: TimeInterval = 2) {
        let queue = DispatchQueue.global()
        timer = DispatchSource.makeTimerSource(queue: queue)
        timer?.schedule(deadline: .now(), repeating: interval)
        timer?.setEventHandler { [weak self] in
            Task { [weak self] in
                await self?.fetchV2RayStats()
            }
        }
        timer?.resume()
    }

    func stopTask() {
        timer?.cancel()
        timer = nil
    }

    // 将 fetchV2RayStats 改为异步函数
    func fetchV2RayStats() async {
        guard let url = URL(string: "\(coreApiBaseUrl)/debug/vars") else {
            logger.error("Invalid URL")
            return
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: URLRequest(url: url))

            guard let httpResponse = response as? HTTPURLResponse else {
                logger.error("Invalid response")
                return
            }

            if httpResponse.statusCode == 200 {
                await parseV2RayStats(jsonData: data)
            } else {
                logger.warning("Failed with status code: \(httpResponse.statusCode)")
            }
        } catch {
            logger.warning("Request failed: \(error.localizedDescription)")
        }
    }

    func parseV2RayStats(jsonData: Data) async {
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601 // 解析日期
            // try decode data
            let vars: V2rayMetricsVars = try decoder.decode(V2rayMetricsVars.self, from: jsonData)
            var latency = 0.0
            var directUpLink = 0
            var directDownLink = 0
            var proxyUpLink = 0
            var proxyDownLink = 0
            guard let stats = vars.stats else {
                logger.warning("Invalid V2Ray Stats")
                return
            }

            // 检测是否在组合模式
            let runningCombination = await MainActor.run { AppState.shared.runningCombination }
            let isComboMode = !runningCombination.isEmpty

            if isComboMode, let observatory = vars.observatory {
                // 组合模式: 遍历所有 combo-out-* 条目, 提取 UUID 更新每个 profile 的延迟
                var delays: [Double] = []
                for (tag, obs) in observatory where tag.hasPrefix("combo-out-") {
                    let parts = tag.components(separatedBy: "-")
                    guard parts.count >= 5 else { continue }
                    let uuid = parts[4...].joined(separator: "-")
                    let delay = obs.delay
                    if delay > 0 {
                        delays.append(delay)
                        ProfileStore.shared.updateSpeed(uuid: uuid, speed: Int(delay.rounded()))
                    }
                }
                // 使用最低延迟作为整体显示值
                latency = delays.min() ?? 0
            } else if let latencyValue = vars.observatory?["proxy"] {
                latency = latencyValue.delay
            }

            if let directUpLinkValue = stats.outbound["direct"] {
                directUpLink = directUpLinkValue.uplink
                directDownLink = directUpLinkValue.downlink
            }
            if let proxyUpLinkValue = stats.outbound["proxy"] {
                proxyUpLink = proxyUpLinkValue.uplink
                proxyDownLink = proxyUpLinkValue.downlink
            }
            // 这里设置后, 触发menu等更新
            await CoreTrafficStatsHandler.shared.setSpeed(latency: latency, directUpLink: directUpLink, directDownLink: directDownLink, proxyUpLink: proxyUpLink, proxyDownLink: proxyDownLink)
//            logger.info("Parsed V2Ray Stats: \(stats)")
        } catch {
            logger.error("Failed to parse JSON: \(error.localizedDescription)")
        }
    }
}

actor ClashApilatencyHandler: NSObject {
    static let shared = ClashApilatencyHandler()
    private var timer: DispatchSourceTimer?

    // MARK: - 延迟测试
    func startTask(interval: TimeInterval = 2) {
        let queue = DispatchQueue.global()
        timer = DispatchSource.makeTimerSource(queue: queue)
        timer?.schedule(deadline: .now(), repeating: interval)
        timer?.setEventHandler { [weak self] in
            Task { [weak self] in
                // 检测组合模式
                let runningCombination = await MainActor.run { AppState.shared.runningCombination }
                if !runningCombination.isEmpty {
                    await self?.checkDelayForCombination(comboUuid: runningCombination)
                } else {
                    await self?.checkDelayByClashApi(proxyName: "proxy")
                }
            }
        }
        timer?.resume()
    }

    func stopTask() {
        timer?.cancel()
        timer = nil
    }

    /// 组合模式：逐个查询组合中每个出站的延迟
    /// sing-box 的 Clash API 对 selector 组的 delay 查询可能不返回单个出站延迟，因此直接查每个出站
    private func checkDelayForCombination(comboUuid: String) async {
        guard let combo = CombinedConfigStore.shared.getValidCombination(uuid: comboUuid) else { return }

        var allDelays: [Double] = []

        for (groupIndex, group) in combo.groups.enumerated() {
            for (profileIndex, uuid) in group.outboundProfileUUIDs.enumerated() {
                let outboundTag = "combo-out-\(groupIndex)-\(profileIndex)-\(uuid)"
                if let delay = await queryDelay(proxyName: outboundTag) {
                    ProfileStore.shared.updateSpeed(uuid: uuid, speed: Int(delay.rounded()))
                    allDelays.append(delay)
                }
            }
        }

        if !allDelays.isEmpty {
            let minDelay = allDelays.min() ?? 0
            await AppState.shared.setLatency(latency: minDelay)
        }
    }

    /// 查询单个代理的延迟 (返回 `{"delay": 123}`)
    private func queryDelay(proxyName: String) async -> Double? {
        let timeoutMs = defaultLatencyTestTimeout * 1000
        let testURL = UserDefaults.get(forKey: .pingTestURL, defaultValue: defaultPingTestURL)
        var components = URLComponents(string: "\(coreApiBaseUrl)/proxies/\(proxyName)/delay")
        components?.queryItems = [
            URLQueryItem(name: "timeout", value: "\(timeoutMs)"),
            URLQueryItem(name: "url", value: testURL)
        ]
        guard let url = components?.url else { return nil }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let delay = parseClashDelay(from: data) {
                return delay
            }
        } catch {
            logger.error("Delay query failed for \(proxyName): \(error.localizedDescription)")
        }
        return nil
    }

    private func checkDelayByClashApi(proxyName: String) async {
        let timeoutMs = defaultLatencyTestTimeout * 1000
        let testURL = UserDefaults.get(forKey: .pingTestURL, defaultValue: defaultPingTestURL)
        var components = URLComponents(string: "\(coreApiBaseUrl)/proxies/\(proxyName)/delay")
        components?.queryItems = [
            URLQueryItem(name: "timeout", value: "\(timeoutMs)"),
            URLQueryItem(name: "url", value: testURL)
        ]
        guard let url = components?.url else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let delay = parseClashDelay(from: data) {
                await AppState.shared.setLatency(latency: delay)
            }
        } catch {
            logger.error("Delay check failed: \(error.localizedDescription)")
        }
    }

}

final class ClashApiStreamHandler: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    static let shared = ClashApiStreamHandler()
    
    private var clashApiSession: URLSession?
    private var clashApiTask: URLSessionDataTask?
    
    override init() {
        super.init()
        let config = URLSessionConfiguration.default
        // 不走系统代理，避免被自己的 http-in 代理拦截
        config.connectionProxyDictionary = [:]
        clashApiSession = URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }
    
   // MARK: - 流量监听
   func startTask() {
       guard let url = URL(string: "\(coreApiBaseUrl)/traffic") else { return }
       let request = URLRequest(url: url)
       clashApiTask = clashApiSession?.dataTask(with: request)
       clashApiTask?.resume()
   }

   func stopTask() {
       clashApiTask?.cancel()
   }

    // MARK: - URLSession Delegate
   func urlSession(_ clashApiSession: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        do {
            let traffic = try JSONDecoder().decode(Traffic.self, from: data)
//            print("Uplink: \(traffic.up), Downlink: \(traffic.down)")
            Task {
                await CoreTrafficStatsHandler.shared.setTraffic(upLink: traffic.up, downLink: traffic.down)
            }
        } catch {
            if let str = String(data: data, encoding: .utf8) {
                print("Raw traffic data: \(str)")
            }
        }
    }

    func urlSession(_ clashApiSession: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            logger.error("Traffic stream ended with error: \(error.localizedDescription)")
            // 自动重连
            DispatchQueue.global().asyncAfter(deadline: .now() + 3) {
                self.startTask()
            }
        } else {
            print("Traffic stream closed normally")
        }
    }
}
