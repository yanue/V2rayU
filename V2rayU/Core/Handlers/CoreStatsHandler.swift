import Foundation

struct Traffic: Codable {
    let up: Double
    let down: Double
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
                ClashApiStreamHandler.shared.startTask()
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
        // 计算速度
        let directUpSpeed = (Double(directUpLink - self.directUpLink) / 1024  / timeInterval)
        let directDownSpeed = (Double(directDownLink - self.directDownLink) / 1024 / timeInterval)
        let proxyUpSpeed = (Double(proxyUpLink - self.proxyUpLink) / 1024 /  timeInterval)
        let proxyDownSpeed = (Double(proxyDownLink - self.proxyDownLink) / 1024 / timeInterval)
        // 替换
        self.directUpLink = directUpLink
        self.directDownLink = directDownLink
        self.proxyUpLink = proxyUpLink
        self.proxyDownLink = proxyDownLink
        // 计算流量(代理流量=代理上行+代理下行)
        let up = directUpLink + proxyUpLink
        let down = directDownLink + proxyDownLink
        Task {
            // 更新到 UI
            await AppState.shared.setSpeed(latency: latency, directUpSpeed: directUpSpeed, directDownSpeed: directDownSpeed, proxyUpSpeed: proxyUpSpeed, proxyDownSpeed: proxyDownSpeed)
            let uuid = await AppState.shared.runningProfile
//             logger.info("setSpeed:\(now) - \(uuid) - \(up) - \(down) - \(latency) - \(timeInterval)")
            // 更新到数据库
            try ProfileStore.shared.update_stat(uuid: uuid, up: up, down: down,lastUpdate: now)
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
        guard let url = URL(string: "http://127.0.0.1:11111/debug/vars") else {
            logger.info("Invalid URL")
            return
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: URLRequest(url: url))
            
            guard let httpResponse = response as? HTTPURLResponse else {
                logger.info("Invalid response")
                return
            }
            
            if httpResponse.statusCode == 200 {
                await parseV2RayStats(jsonData: data)
            } else {
                logger.info("Failed with status code: \(httpResponse.statusCode)")
            }
        } catch {
            logger.info("Request failed: \(error.localizedDescription)")
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
                logger.info("Invalid V2Ray Stats")
                return
            }
            if let latencyValue = vars.observatory?["proxy"] {
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
            await CoreTrafficStatsHandler.shared.setSpeed(latency: latency, directUpLink: directUpLink, directDownLink: directDownLink, proxyUpLink: proxyUpLink, proxyDownLink: proxyDownLink)
//            logger.info("Parsed V2Ray Stats: \(stats)")
        } catch {
            logger.info("Failed to parse JSON: \(error.localizedDescription)")
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
               await self?.checkDelayByClashApi(proxyName: "proxy")
            }
        }
        timer?.resume()
    }

    func stopTask() {
        timer?.cancel()
        timer = nil
    }
    
    private func checkDelayByClashApi(proxyName: String) {
        guard let url = URL(string: "http://127.0.0.1:11111/proxies/\(proxyName)/delay?timeout=5000&url=http://www.gstatic.com/generate_204") else { return }
        let task = URLSession.shared.dataTask(with: url) { data, _, error in
            if let data = data,
               let result = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let delay = result["delay"] as? Double {
                Task {
                  await AppState.shared.setLatency(latency: delay)
                }
            } else if let error = error {
                logger.error("Delay check failed: \(error.localizedDescription)")
            }
        }
        task.resume()
    }

}

final class ClashApiStreamHandler: NSObject, URLSessionDataDelegate {
    static let shared = ClashApiStreamHandler()
    
    private var clashApiSession: URLSession!
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
       guard let url = URL(string: "http://127.0.0.1:11111/traffic") else { return }
       let request = URLRequest(url: url)
       clashApiTask = clashApiSession.dataTask(with: request)
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
