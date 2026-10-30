//
//  RuleSetUpdater.swift
//  V2rayU
//
//  路由规则集自动更新: xray 的 geoip.dat / geosite.dat, sing-box 的 .srs 规则集
//  下载到 ~/.V2rayU/rule-set (用户可写), 生成配置时优先用这里的文件, 没有再用 /usr/local/v2rayu 下随安装带的
//

import Foundation

/// 用户目录下的规则集, 更新后的文件放这里
let userRuleSetPath = AppHomePath + "/rule-set"

enum RuleSetCore: String, Codable, CaseIterable {
    case xray
    case singbox
}

struct RuleSetSource: Codable, Identifiable, Equatable {
    var id: String
    var core: RuleSetCore
    /// 落盘文件名, 也是 sing-box 的 rule_set tag + ".srs"
    var fileName: String
    var url: String
    var enabled: Bool = true

    var localPath: String { userRuleSetPath + "/" + fileName }

    /// 随安装带的那份, 用户目录没有时拿它对比, 内容一样就不用写也不用重启
    var bundledPath: String {
        switch core {
        case .xray: return xrayCorePath + "/" + fileName
        case .singbox: return singboxRuleSetPath + "/" + fileName
        }
    }

    static let defaults: [RuleSetSource] = [
        RuleSetSource(id: "xray-geoip", core: .xray, fileName: "geoip.dat",
                      url: "https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat"),
        RuleSetSource(id: "xray-geosite", core: .xray, fileName: "geosite.dat",
                      url: "https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat"),
        RuleSetSource(id: "singbox-geoip-cn", core: .singbox, fileName: "geoip-cn.srs",
                      url: "https://raw.githubusercontent.com/SagerNet/sing-geoip/rule-set/geoip-cn.srs"),
        RuleSetSource(id: "singbox-geosite-cn", core: .singbox, fileName: "geosite-cn.srs",
                      url: "https://raw.githubusercontent.com/SagerNet/sing-geosite/rule-set/geosite-cn.srs"),
        RuleSetSource(id: "singbox-geosite-geolocation-!cn", core: .singbox, fileName: "geosite-geolocation-!cn.srs",
                      url: "https://raw.githubusercontent.com/SagerNet/sing-geosite/rule-set/geosite-geolocation-!cn.srs"),
        RuleSetSource(id: "singbox-geosite-category-ads-all", core: .singbox, fileName: "geosite-category-ads-all.srs",
                      url: "https://raw.githubusercontent.com/SagerNet/sing-geosite/rule-set/geosite-category-ads-all.srs"),
    ]
}

struct RuleSetUpdateResult: Equatable {
    var updated: [String] = []
    var unchanged: [String] = []
    var failed: [String: String] = [:]

    var summary: String {
        var parts: [String] = []
        if !updated.isEmpty { parts.append("updated: \(updated.joined(separator: ", "))") }
        if !unchanged.isEmpty { parts.append("unchanged: \(unchanged.count)") }
        if !failed.isEmpty { parts.append("failed: " + failed.map { "\($0.key) (\($0.value))" }.joined(separator: ", ")) }
        return parts.joined(separator: "; ")
    }
}

/// 规则集路径解析: 用户目录有就用用户目录的, 否则用安装目录的
enum RuleSetLocator {
    /// sing-box 某个 tag 的 .srs 路径
    static func singboxRuleSetFile(tag: String, userDir: String = userRuleSetPath, bundledDir: String = singboxRuleSetPath,
                                   fileExists: (String) -> Bool = { FileManager.default.fileExists(atPath: $0) }) -> String {
        let user = "\(userDir)/\(tag).srs"
        return fileExists(user) ? user : "\(bundledDir)/\(tag).srs"
    }

    /// xray 只能整目录指定 (XRAY_LOCATION_ASSET): geoip.dat 和 geosite.dat 都在用户目录时才切过去, 缺一个就还用安装目录
    static func xrayAssetDirectory(userDir: String = userRuleSetPath,
                                  fileExists: (String) -> Bool = { FileManager.default.fileExists(atPath: $0) }) -> String? {
        let all = ["geoip.dat", "geosite.dat"].allSatisfy { fileExists("\(userDir)/\($0)") }
        return all ? userDir : nil
    }
}

actor RuleSetUpdater {
    static let shared = RuleSetUpdater()

    static let defaultInterval = 86400
    static let intervalOptions = [86400, 3 * 86400, 7 * 86400]

    private var updating = false
    private var timer: DispatchSourceTimer?

    // MARK: - 设置

    static var sources: [RuleSetSource] {
        get {
            let raw = UserDefaults.get(forKey: .ruleSetSources, defaultValue: "")
            guard let data = raw.data(using: .utf8),
                  let list = try? JSONDecoder().decode([RuleSetSource].self, from: data),
                  !list.isEmpty else { return RuleSetSource.defaults }
            return list
        }
        set {
            if let data = try? JSONEncoder().encode(newValue), let text = String(data: data, encoding: .utf8) {
                UserDefaults.set(forKey: .ruleSetSources, value: text)
            }
        }
    }

    static var autoUpdate: Bool {
        get { UserDefaults.getBool(forKey: .ruleSetAutoUpdate, default: true) }
        set { UserDefaults.setBool(forKey: .ruleSetAutoUpdate, value: newValue) }
    }

    static var interval: Int {
        get { normalizedInterval(UserDefaults.getInt(forKey: .ruleSetUpdateInterval, defaultValue: defaultInterval)) }
        set { UserDefaults.setInt(forKey: .ruleSetUpdateInterval, value: normalizedInterval(newValue)) }
    }

    static func normalizedInterval(_ seconds: Int) -> Int {
        seconds < 3600 ? defaultInterval : min(seconds, 365 * 86400)
    }

    static var lastUpdate: Date? {
        let t = UserDefaults.standard.double(forKey: UserDefaults.KEY.ruleSetUpdateDate.rawValue)
        return t > 0 ? Date(timeIntervalSince1970: t) : nil
    }

    static func resetSources() {
        UserDefaults.del(forKey: .ruleSetSources)
    }

    // MARK: - 调度

    /// 启动时调用: 到期就更新, 之后每小时看一次是否到期 (App 常驻不重启也能按天更新)
    func start() {
        timer?.cancel()
        let t = DispatchSource.makeTimerSource(queue: .global(qos: .utility))
        t.schedule(deadline: .now() + 60, repeating: 3600)
        t.setEventHandler {
            Task { await RuleSetUpdater.shared.updateIfDue() }
        }
        t.resume()
        timer = t
    }

    /// 定时更新只下载不重启: 默认源每天都变, 每天自动重启核心 (TUN 下整套重启) 会断掉所有连接。
    /// 新规则在下次启动 / 切换节点、路由、模式时生效; 手动点"更新"才立即重启。
    func updateIfDue() async {
        guard Self.autoUpdate else { return }
        let elapsed = Date().timeIntervalSince1970 - (Self.lastUpdate?.timeIntervalSince1970 ?? 0)
        guard elapsed >= TimeInterval(Self.interval) else { return }
        _ = await update(restartCore: false)
    }

    // MARK: - 更新

    /// 下载所有启用的源; 有文件变化且核心在运行时重启核心让新规则生效
    @discardableResult
    func update(restartCore: Bool = true, only core: RuleSetCore? = nil) async -> RuleSetUpdateResult {
        guard !updating else { return RuleSetUpdateResult() }
        updating = true
        defer { updating = false }

        var result = RuleSetUpdateResult()
        try? FileManager.default.createDirectory(atPath: userRuleSetPath, withIntermediateDirectories: true)

        for source in Self.sources where source.enabled && (core == nil || source.core == core) {
            do {
                let data = try await download(source)
                try Self.validate(data, fileName: source.fileName)
                let fm = FileManager.default
                if let old = fm.contents(atPath: source.localPath), old == data {
                    result.unchanged.append(source.fileName)
                    continue
                }
                // 用户目录还没有: 和安装目录那份比, 相同就跳过, 免得装完第一次更新就白白重启核心
                if !fm.fileExists(atPath: source.localPath), let bundled = fm.contents(atPath: source.bundledPath), bundled == data {
                    result.unchanged.append(source.fileName)
                    continue
                }
                try data.write(to: URL(fileURLWithPath: source.localPath), options: .atomic)
                result.updated.append(source.fileName)
            } catch {
                result.failed[source.fileName] = error.localizedDescription
            }
        }

        // xray 只能整目录切换: 只更新了其中一个文件时, 把另一个从安装目录补进来, 不然用户目录不全、新文件不生效
        if result.updated.contains(where: { name in Self.sources.contains { $0.core == .xray && $0.fileName == name } }) {
            Self.completeXrayAssets()
        }

        // 有一个源成功就记时间: 某个源一直连不上时不能每小时反复下载全部文件
        if !result.updated.isEmpty || !result.unchanged.isEmpty {
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: UserDefaults.KEY.ruleSetUpdateDate.rawValue)
        }
        logger.info("rule-set update: \(result.summary)")

        let (coreOn, tunMode) = await MainActor.run { (AppState.shared.v2rayTurnOn, AppState.shared.runMode == .tun) }
        if restartCore, !result.updated.isEmpty, coreOn {
            // 非 TUN 只重载代理核心; TUN 的 tun.json 也引用规则集, 要整体重启
            if tunMode {
                await V2rayLaunch.shared.restart()
            } else {
                await V2rayLaunch.shared.reloadCore()
            }
        }
        return result
    }

    /// 用户目录缺的 geoip.dat / geosite.dat 从安装目录复制一份
    static func completeXrayAssets(userDir: String = userRuleSetPath, bundledDir: String = xrayCorePath) {
        let fm = FileManager.default
        for name in ["geoip.dat", "geosite.dat"] {
            let user = "\(userDir)/\(name)"
            let bundled = "\(bundledDir)/\(name)"
            guard !fm.fileExists(atPath: user), fm.fileExists(atPath: bundled) else { continue }
            do {
                try fm.copyItem(atPath: bundled, toPath: user)
            } catch {
                logger.info("rule-set: copy bundled \(name) failed: \(error.localizedDescription)")
            }
        }
    }

    /// 核心在运行就走代理下载 (GitHub 直连经常不通), 失败再直连试一次
    private func download(_ source: RuleSetSource) async throws -> Data {
        guard let url = URL(string: source.url) else { throw URLError(.badURL) }
        var request = URLRequest(url: url, timeoutInterval: 60)
        request.setValue("V2rayU/\(getAppVersion())", forHTTPHeaderField: "User-Agent")

        var configs: [URLSessionConfiguration] = []
        if await MainActor.run(body: { AppState.shared.v2rayTurnOn }) { configs.append(getProxyUrlSessionConfigure()) }
        let direct = URLSessionConfiguration.ephemeral
        direct.connectionProxyDictionary = [:]
        configs.append(direct)

        var lastError: Error = URLError(.unknown)
        for config in configs {
            do {
                let (data, response) = try await URLSession(configuration: config).data(for: request)
                if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                    throw NSError(domain: "RuleSetUpdater", code: http.statusCode,
                                  userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode)"])
                }
                return data
            } catch {
                lastError = error
            }
        }
        throw lastError
    }

    /// 防止把错误页当规则文件存下来: .srs 以 "SRS" 开头; .dat 是 protobuf, 至少要有点大小且不像文本
    static func validate(_ data: Data, fileName: String) throws {
        func fail(_ msg: String) -> NSError {
            NSError(domain: "RuleSetUpdater", code: 2001, userInfo: [NSLocalizedDescriptionKey: msg])
        }
        guard data.count > 64 else { throw fail("file too small") }
        if fileName.hasSuffix(".srs") {
            guard data.prefix(3) == Data("SRS".utf8) else { throw fail("not a sing-box rule-set") }
        } else if fileName.hasSuffix(".dat") {
            let head = data.prefix(16)
            if let text = String(data: head, encoding: .utf8), text.lowercased().hasPrefix("<") || text.hasPrefix("{") {
                throw fail("not a geo data file")
            }
        }
    }

    /// 本地文件状态: 大小和修改时间, 没有返回 nil
    static func localFileInfo(_ source: RuleSetSource) -> (size: Int, modified: Date)? {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: source.localPath) else { return nil }
        let size = (attrs[.size] as? NSNumber)?.intValue ?? 0
        let date = attrs[.modificationDate] as? Date ?? Date(timeIntervalSince1970: 0)
        return (size, date)
    }
}
