import Foundation

enum XrayCapabilityKind: String, CaseIterable, Codable {
    case inboundProtocol = "Inbound"
    case outboundProtocol = "Outbound"
    case transportMethod = "Transport"
    case transportSecurity = "Security"
    case additionalConfig = "Additional"
    case flow = "Flow"
}

enum CapabilityRulesCore: String, Codable {
    case xray
    case singbox = "sing-box"

    var bundledFileName: String {
        switch self {
        case .xray:
            return "xray-capability-rules"
        case .singbox:
            return "singbox-capability-rules"
        }
    }
}

enum CapabilityRuleStatus: String, Codable {
    case supported
    case legacy
    case compatibility
    case unsupported
    case removed
    case pendingReview
}

enum CapabilityRuleAppSupportLevel: String, Codable {
    case supported
    case advisory
    case unsupported
}

struct CapabilityRuleAppSupport: Codable {
    let level: CapabilityRuleAppSupportLevel
    let note: String
}

struct CapabilityEvidence: Codable {
    let id: String
    let kind: String
    let statement: String
    let sourceTitle: String
    let sourceURL: String
    let sourceVersion: String?
    let sourceDate: String?
    let quote: String
    let reviewedAt: String?
    let note: String?

    private enum CodingKeys: String, CodingKey {
        case id
        case kind
        case statement
        case sourceTitle
        case sourceVersion
        case sourceDate
        case quote
        case reviewedAt
        case note
        case sourceURL
    }

    private enum LegacyCodingKeys: String, CodingKey {
        case sourceURL
    }

    private enum SnakeCaseCodingKeys: String, CodingKey {
        case sourceURL = "source_url"
    }

    // JSONDecoder.keyDecodingStrategy = .convertFromSnakeCase 会把
    // JSON 中的 `source_url` 转换为内部 key `sourceUrl`（注意：仅首字母大写，
    // 不是 `sourceURL`），导致默认 CodingKeys/LegacyCodingKeys/SnakeCaseCodingKeys
    // 都匹配不到，从而触发整份 JSON 解码失败。这里增加一个兜底匹配。
    private enum ConvertedSnakeCaseCodingKeys: String, CodingKey {
        case sourceURL = "sourceUrl"
    }

    init(id: String, kind: String, statement: String, sourceTitle: String, sourceURL: String, sourceVersion: String?, sourceDate: String?, quote: String, reviewedAt: String?, note: String?) {
        self.id = id
        self.kind = kind
        self.statement = statement
        self.sourceTitle = sourceTitle
        self.sourceURL = sourceURL
        self.sourceVersion = sourceVersion
        self.sourceDate = sourceDate
        self.quote = quote
        self.reviewedAt = reviewedAt
        self.note = note
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let legacyContainer = try decoder.container(keyedBy: LegacyCodingKeys.self)
        let snakeCaseContainer = try decoder.container(keyedBy: SnakeCaseCodingKeys.self)
        let convertedContainer = try decoder.container(keyedBy: ConvertedSnakeCaseCodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        kind = try container.decode(String.self, forKey: .kind)
        statement = try container.decode(String.self, forKey: .statement)
        sourceTitle = try container.decode(String.self, forKey: .sourceTitle)
        if let value = try snakeCaseContainer.decodeIfPresent(String.self, forKey: .sourceURL) {
            sourceURL = value
        } else if let value = try convertedContainer.decodeIfPresent(String.self, forKey: .sourceURL) {
            sourceURL = value
        } else {
            sourceURL = try legacyContainer.decode(String.self, forKey: .sourceURL)
        }
        sourceVersion = try container.decodeIfPresent(String.self, forKey: .sourceVersion)
        sourceDate = try container.decodeIfPresent(String.self, forKey: .sourceDate)
        quote = try container.decode(String.self, forKey: .quote)
        reviewedAt = try container.decodeIfPresent(String.self, forKey: .reviewedAt)
        note = try container.decodeIfPresent(String.self, forKey: .note)
    }
}

struct CapabilityRulePayload: Codable {
    let type: CapabilityRuleStatus
    let legacyMin: String?
    let calendarMin: String?
    let removedAt: String?
    let note: String
}

struct CapabilityPayload: Codable {
    let key: String
    let displayName: String
    let kind: XrayCapabilityKind
    let docsPath: String?
    let rule: CapabilityRulePayload
    let appSupport: CapabilityRuleAppSupport?
    let evidence: [CapabilityEvidence]?
}

struct CapabilityRulesDocument: Codable {
    let schemaVersion: Int
    let core: CapabilityRulesCore
    let latestReviewedVersion: String?
    let capabilities: [CapabilityPayload]
}

enum CapabilityRulesSourceKind {
    case overrideFile
    case bundledFile
    case swiftFallback
    case unavailable
}

struct CapabilityRulesStatusSnapshot {
    let core: CapabilityRulesCore
    let sourceKind: CapabilityRulesSourceKind
    let path: String?
    let latestReviewedVersion: String?
    let capabilityCount: Int
}

struct CapabilityRulesUpdateResult: Sendable {
    let targetDirectory: String
    let xrayCapabilityCount: Int
    let singboxCapabilityCount: Int

    var message: String {
        "Capability rules updated in \(targetDirectory)\nXray: \(xrayCapabilityCount), Sing-Box: \(singboxCapabilityCount)"
    }
}

enum CapabilityRulesUpdateError: LocalizedError {
    case invalidBaseURL(String)
    case unexpectedHTTPStatus(URL, Int)
    case invalidDocument(URL, String)

    var errorDescription: String? {
        switch self {
        case .invalidBaseURL(let value):
            return "Invalid capability-rules base URL: \(value)"
        case .unexpectedHTTPStatus(let url, let statusCode):
            return "Capability rules download failed (\(statusCode)): \(url.absoluteString)"
        case .invalidDocument(let url, let reason):
            return "Invalid capability rules at \(url.absoluteString): \(reason)"
        }
    }
}

enum CapabilityRulesLoader {
    private static let bundleSubdirectory = "capability-rules"
    private static let primaryOverrideDirectoryName = "capability-rules"
    private static let supportedSchemaVersions: Set<Int> = [1, 2, 3, 4]

    static func load(core: CapabilityRulesCore) -> CapabilityRulesDocument? {
        loadDetailed(core: core)?.document
    }

    static func status(core: CapabilityRulesCore) -> CapabilityRulesStatusSnapshot {
        if let loaded = loadDetailed(core: core) {
            return CapabilityRulesStatusSnapshot(
                core: core,
                sourceKind: loaded.sourceKind,
                path: loaded.url.path,
                latestReviewedVersion: loaded.document.latestReviewedVersion,
                capabilityCount: loaded.document.capabilities.count
            )
        }

        switch core {
        case .xray:
            return CapabilityRulesStatusSnapshot(
                core: core,
                sourceKind: .swiftFallback,
                path: nil,
                latestReviewedVersion: nil,
                capabilityCount: XraySupportCatalog.builtInCapabilities.count
            )
        case .singbox:
            return CapabilityRulesStatusSnapshot(
                core: core,
                sourceKind: .unavailable,
                path: nil,
                latestReviewedVersion: nil,
                capabilityCount: 0
            )
        }
    }

    static func overrideDirectoryPath() -> String {
        URL(fileURLWithPath: AppHomePath)
            .appendingPathComponent(primaryOverrideDirectoryName, isDirectory: true)
            .path
    }

    static func updateFromRemote(baseURL: String) async throws -> CapabilityRulesUpdateResult {
        let xrayURL = try remoteRulesURL(baseURL: baseURL, fileName: CapabilityRulesCore.xray.bundledFileName)
        let singboxURL = try remoteRulesURL(baseURL: baseURL, fileName: CapabilityRulesCore.singbox.bundledFileName)

        let xray = try await downloadAndValidateRules(from: xrayURL, expectedCore: .xray)
        let singbox = try await downloadAndValidateRules(from: singboxURL, expectedCore: .singbox)

        let targetDirectory = URL(fileURLWithPath: overrideDirectoryPath(), isDirectory: true)
        try FileManager.default.createDirectory(at: targetDirectory, withIntermediateDirectories: true)
        try xray.data.write(
            to: targetDirectory.appendingPathComponent("\(CapabilityRulesCore.xray.bundledFileName).json"),
            options: .atomic
        )
        try singbox.data.write(
            to: targetDirectory.appendingPathComponent("\(CapabilityRulesCore.singbox.bundledFileName).json"),
            options: .atomic
        )

        return CapabilityRulesUpdateResult(
            targetDirectory: targetDirectory.path,
            xrayCapabilityCount: xray.document.capabilities.count,
            singboxCapabilityCount: singbox.document.capabilities.count
        )
    }

    private static func loadDetailed(core: CapabilityRulesCore) -> (document: CapabilityRulesDocument, url: URL, sourceKind: CapabilityRulesSourceKind)? {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        for candidate in candidateURLs(for: core) {
            guard FileManager.default.fileExists(atPath: candidate.url.path) else {
                continue
            }
            do {
                let data = try Data(contentsOf: candidate.url)
                let document = try decoder.decode(CapabilityRulesDocument.self, from: data)
                guard supportedSchemaVersions.contains(document.schemaVersion), document.core == core, !document.capabilities.isEmpty else {
                    logger.warning("capability rules invalid: \(candidate.url.path)")
                    continue
                }
                return (document, candidate.url, candidate.sourceKind)
            } catch {
                logger.warning("capability rules load failed: \(candidate.url.path) error=\(error.localizedDescription)")
            }
        }
        return nil
    }

    private static func candidateURLs(for core: CapabilityRulesCore) -> [(url: URL, sourceKind: CapabilityRulesSourceKind)] {
        var urls: [(url: URL, sourceKind: CapabilityRulesSourceKind)] = []
        let fileName = core.bundledFileName

        let overrideURL = URL(fileURLWithPath: AppHomePath)
            .appendingPathComponent(primaryOverrideDirectoryName, isDirectory: true)
            .appendingPathComponent("\(fileName).json", isDirectory: false)
        urls.append((overrideURL, .overrideFile))

        if let bundleURL = Bundle.main.url(forResource: fileName, withExtension: "json", subdirectory: bundleSubdirectory) {
            urls.append((bundleURL, .bundledFile))
        }

        return urls
    }

    private static func remoteRulesURL(baseURL: String, fileName: String) throws -> URL {
        let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let separator = trimmed.hasSuffix("/") ? "" : "/"
        guard let url = URL(string: "\(trimmed)\(separator)\(fileName).json"),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
            throw CapabilityRulesUpdateError.invalidBaseURL(baseURL)
        }
        return url
    }

    private static func downloadAndValidateRules(from url: URL, expectedCore: CapabilityRulesCore) async throws -> (data: Data, document: CapabilityRulesDocument) {
        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        let (data, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse,
           !(200..<300).contains(httpResponse.statusCode) {
            throw CapabilityRulesUpdateError.unexpectedHTTPStatus(url, httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let document = try decoder.decode(CapabilityRulesDocument.self, from: data)
        try validateRemoteDocument(document, expectedCore: expectedCore, sourceURL: url)
        return (data, document)
    }

    private static func validateRemoteDocument(_ document: CapabilityRulesDocument, expectedCore: CapabilityRulesCore, sourceURL: URL) throws {
        guard supportedSchemaVersions.contains(document.schemaVersion) else {
            throw CapabilityRulesUpdateError.invalidDocument(sourceURL, "schemaVersion must be 1, 2, 3, or 4")
        }
        guard document.core == expectedCore else {
            throw CapabilityRulesUpdateError.invalidDocument(sourceURL, "core mismatch: \(document.core.rawValue) != \(expectedCore.rawValue)")
        }
        guard !document.capabilities.isEmpty else {
            throw CapabilityRulesUpdateError.invalidDocument(sourceURL, "capabilities must be a non-empty array")
        }
        for (index, capability) in document.capabilities.enumerated() {
            if let evidence = capability.evidence, evidence.isEmpty {
                throw CapabilityRulesUpdateError.invalidDocument(sourceURL, "capability[\(index)].evidence must be non-empty when present")
            }
        }
    }
}

enum XrayFeatureAvailability {
    case supported
    case advisory(reason: String)
    case unsupported(reason: String)
    case unknown(reason: String)
}

struct XraySupportRule {
    let status: CapabilityRuleStatus
    let legacyMin: XrayVersion?
    let calendarMin: XrayVersion?
    let removedAt: XrayVersion?
    let note: String

    static func supported(note: String, legacyMin: XrayVersion? = nil, calendarMin: XrayVersion? = nil, removedAt: XrayVersion? = nil) -> XraySupportRule {
        XraySupportRule(status: .supported, legacyMin: legacyMin, calendarMin: calendarMin, removedAt: removedAt, note: note)
    }

    static func legacy(note: String, legacyMin: XrayVersion? = nil, calendarMin: XrayVersion? = nil, removedAt: XrayVersion? = nil) -> XraySupportRule {
        XraySupportRule(status: .legacy, legacyMin: legacyMin, calendarMin: calendarMin, removedAt: removedAt, note: note)
    }

    static func compatibility(note: String, legacyMin: XrayVersion? = nil, calendarMin: XrayVersion? = nil, removedAt: XrayVersion? = nil) -> XraySupportRule {
        XraySupportRule(status: .compatibility, legacyMin: legacyMin, calendarMin: calendarMin, removedAt: removedAt, note: note)
    }

    static func removed(note: String, legacyMin: XrayVersion? = nil, calendarMin: XrayVersion? = nil, removedAt: XrayVersion? = nil) -> XraySupportRule {
        XraySupportRule(status: .removed, legacyMin: legacyMin, calendarMin: calendarMin, removedAt: removedAt, note: note)
    }

    static func pendingReview(note: String) -> XraySupportRule {
        XraySupportRule(status: .pendingReview, legacyMin: nil, calendarMin: nil, removedAt: nil, note: note)
    }


    func describe() -> String {
        let statusText: String
        switch status {
        case .supported:
            statusText = "当前主线支持功能"
        case .legacy:
            statusText = "历史/兼容功能"
        case .compatibility:
            statusText = "兼容映射功能"
        case .unsupported:
            statusText = "当前应用/核心组合不支持功能"
        case .removed:
            statusText = "已移除功能"
        case .pendingReview:
            statusText = "待核对功能"
        }

        var parts: [String] = [statusText]
        if let legacyMin {
            parts.append("旧语义版本 >= \(legacyMin.description)")
        }
        if let calendarMin {
            parts.append("日期版本 >= \(calendarMin.description)")
        }
        if let removedAt {
            parts.append("< \(removedAt.description)")
        }
        return "\(parts.joined(separator: "，"))。\(note)"
    }

    func evaluate(version: XrayVersion?, featureName: String) -> XrayFeatureAvailability {
        if let boundaryResult = evaluateVersionBounds(version: version, featureName: featureName) {
            return boundaryResult
        }

        switch status {
        case .supported, .compatibility:
            return .supported
        case .legacy:
            return .advisory(reason: note)
        case .unsupported:
            return .unsupported(reason: note)
        case .removed:
            if let version, let removedAt {
                return .advisory(reason: "\(featureName) 在较新版本已被标记为 removed（>= \(removedAt.description)）；当前版本 \(version.description) 仍可能可用。\(note)")
            }
            return .unsupported(reason: "\(featureName) 已被当前功能支持规则标记为 removed。\(note)")
        case .pendingReview:
            return .advisory(reason: note)
        }
    }

    private func evaluateVersionBounds(version: XrayVersion?, featureName: String) -> XrayFeatureAvailability? {
        guard legacyMin != nil || calendarMin != nil || removedAt != nil else {
            return nil
        }
        guard let version else {
            return .unknown(reason: "无法识别当前 Xray-core 版本，无法判断 \(featureName) 的版本边界。\(note)")
        }
        if let removedAt, version >= removedAt {
            let removalText = status == .removed ? "已被移除" : "在当前兼容规则中不建议继续使用"
            return .unsupported(reason: "\(featureName) 在 Xray-core \(version.description) 已落入受限区间（>= \(removedAt.description)），该功能\(removalText)。\(note)")
        }
        if version.isCalendarStyle {
            if let calendarMin, version < calendarMin {
                return .unsupported(reason: "\(featureName) 需要日期版本 >= \(calendarMin.description)。\(note)")
            }
        } else if let legacyMin, version < legacyMin {
            return .unsupported(reason: "\(featureName) 需要旧语义版本 >= \(legacyMin.description)。\(note)")
        }
        return nil
    }
}

struct XrayCapabilityDefinition {
    let key: String
    let displayName: String
    let kind: XrayCapabilityKind
    let rule: XraySupportRule
    let docsPath: String?
    let evidence: [CapabilityEvidence]

    init(key: String, displayName: String, kind: XrayCapabilityKind, rule: XraySupportRule, docsPath: String?, evidence: [CapabilityEvidence] = []) {
        self.key = key
        self.displayName = displayName
        self.kind = kind
        self.rule = rule
        self.docsPath = docsPath
        self.evidence = evidence
    }
}

extension XraySupportRule {
    init?(payload: CapabilityRulePayload) {
        let legacyMin = payload.legacyMin.flatMap(XrayVersion.init)
        let calendarMin = payload.calendarMin.flatMap(XrayVersion.init)
        let removedAt = payload.removedAt.flatMap(XrayVersion.init)
        switch payload.type {
        case .supported:
            self = .supported(note: payload.note, legacyMin: legacyMin, calendarMin: calendarMin, removedAt: removedAt)
        case .legacy:
            self = .legacy(note: payload.note, legacyMin: legacyMin, calendarMin: calendarMin, removedAt: removedAt)
        case .compatibility:
            self = .compatibility(note: payload.note, legacyMin: legacyMin, calendarMin: calendarMin, removedAt: removedAt)
        case .unsupported:
            self = XraySupportRule(status: .unsupported, legacyMin: legacyMin, calendarMin: calendarMin, removedAt: removedAt, note: payload.note)
        case .removed:
            self = .removed(note: payload.note, legacyMin: legacyMin, calendarMin: calendarMin, removedAt: removedAt)
        case .pendingReview:
            self = .pendingReview(note: payload.note)
        }
    }
}

extension XrayCapabilityDefinition {
    init?(payload: CapabilityPayload) {
        guard let rule = XraySupportRule(payload: payload.rule) else {
            return nil
        }
        self.init(
            key: payload.key,
            displayName: payload.displayName,
            kind: payload.kind,
            rule: rule,
            docsPath: payload.docsPath,
            evidence: payload.evidence ?? []
        )
    }
}

struct XrayCompatibilityIssue {
    let capability: XrayCapabilityDefinition
    let availability: XrayFeatureAvailability

    var isBlocking: Bool {
        switch availability {
        case .unsupported, .unknown:
            return true
        case .supported, .advisory:
            return false
        }
    }

    var message: String {
        switch availability {
        case .supported:
            return ""
        case .advisory(let reason):
            return "• [提示][\(capability.kind.rawValue)] \(capability.displayName)：\(reason)"
        case .unsupported(let reason):
            return "• [不兼容][\(capability.kind.rawValue)] \(capability.displayName)：\(reason)"
        case .unknown(let reason):
            return "• [待确认][\(capability.kind.rawValue)] \(capability.displayName)：\(reason)"
        }
    }
}

struct XrayCoreCompatibilityDecision {
    let coreType: CoreType
    let warningMessage: String?
    let issues: [XrayCompatibilityIssue]
    let canLaunch: Bool
}

enum SingboxFallbackCompatibility {
    static func incompatibilityReasons(for profile: ProfileEntity) -> [String] {
        SingboxFallbackResolver.incompatibilityReasons(for: profile)
    }
}

enum XraySupportCatalog {
    static let builtInCapabilities: [XrayCapabilityDefinition] = [
        // MARK: Inbound protocols
        XrayCapabilityDefinition(key: "inbound.tunnel", displayName: "Tunnel (dokodemo-door) inbound", kind: .inboundProtocol, rule: .supported(note: "官方入站协议列表可见。"), docsPath: "/config/inbounds/tunnel.html"),
        XrayCapabilityDefinition(key: "inbound.http", displayName: "HTTP inbound", kind: .inboundProtocol, rule: .supported(note: "官方入站协议列表可见。"), docsPath: "/config/inbounds/http.html"),
        XrayCapabilityDefinition(key: "inbound.shadowsocks", displayName: "Shadowsocks inbound", kind: .inboundProtocol, rule: .supported(note: "官方入站协议列表可见。"), docsPath: "/config/inbounds/shadowsocks.html"),
        XrayCapabilityDefinition(key: "inbound.socks", displayName: "SOCKS inbound", kind: .inboundProtocol, rule: .supported(note: "官方入站协议列表可见。"), docsPath: "/config/inbounds/socks.html"),
        XrayCapabilityDefinition(key: "inbound.trojan", displayName: "Trojan inbound", kind: .inboundProtocol, rule: .supported(note: "官方入站协议列表可见。"), docsPath: "/config/inbounds/trojan.html"),
        XrayCapabilityDefinition(key: "inbound.vless", displayName: "VLESS inbound", kind: .inboundProtocol, rule: .supported(note: "官方入站协议列表可见。"), docsPath: "/config/inbounds/vless.html"),
        XrayCapabilityDefinition(key: "inbound.vmess", displayName: "VMess inbound", kind: .inboundProtocol, rule: .supported(note: "官方入站协议列表可见。"), docsPath: "/config/inbounds/vmess.html"),
        XrayCapabilityDefinition(key: "inbound.wireguard", displayName: "WireGuard inbound", kind: .inboundProtocol, rule: .supported(note: "当前官方入站协议列表明确列出。"), docsPath: "/config/inbounds/wireguard.html"),
        XrayCapabilityDefinition(key: "inbound.hysteria", displayName: "Hysteria inbound", kind: .inboundProtocol, rule: .supported(note: "当前官方入站协议列表明确列出。"), docsPath: "/config/inbounds/hysteria.html"),
        XrayCapabilityDefinition(key: "inbound.tun", displayName: "TUN inbound", kind: .inboundProtocol, rule: .supported(note: "当前官方入站协议列表明确列出。"), docsPath: "/config/inbounds/tun.html"),

        XrayCapabilityDefinition(key: "inbound.mixed", displayName: "Mixed (HTTP+SOCKS) inbound", kind: .inboundProtocol, rule: .supported(note: "Xray-core 已支持 mixed 入站协议类型，可同时处理 HTTP 和 SOCKS5 连接。", legacyMin: XrayVersion(1, 8, 24)), docsPath: nil),

        // MARK: Outbound protocols
        XrayCapabilityDefinition(key: "outbound.blackhole", displayName: "Blackhole outbound", kind: .outboundProtocol, rule: .supported(note: "当前官方出站协议列表可见。"), docsPath: "/config/outbounds/blackhole.html"),
        XrayCapabilityDefinition(key: "outbound.dns", displayName: "DNS outbound", kind: .outboundProtocol, rule: .supported(note: "当前官方出站协议列表可见。"), docsPath: "/config/outbounds/dns.html"),
        XrayCapabilityDefinition(key: "outbound.freedom", displayName: "Freedom outbound", kind: .outboundProtocol, rule: .supported(note: "当前官方出站协议列表可见。"), docsPath: "/config/outbounds/freedom.html"),
        XrayCapabilityDefinition(key: "outbound.http", displayName: "HTTP outbound", kind: .outboundProtocol, rule: .supported(note: "当前官方出站协议列表可见。"), docsPath: "/config/outbounds/http.html"),
        XrayCapabilityDefinition(key: "outbound.loopback", displayName: "Loopback outbound", kind: .outboundProtocol, rule: .supported(note: "当前官方出站协议列表明确列出。"), docsPath: "/config/outbounds/loopback.html"),
        XrayCapabilityDefinition(key: "outbound.shadowsocks", displayName: "Shadowsocks outbound", kind: .outboundProtocol, rule: .supported(note: "当前官方出站协议列表可见。"), docsPath: "/config/outbounds/shadowsocks.html"),
        XrayCapabilityDefinition(key: "outbound.socks", displayName: "SOCKS outbound", kind: .outboundProtocol, rule: .supported(note: "当前官方出站协议列表可见。"), docsPath: "/config/outbounds/socks.html"),
        XrayCapabilityDefinition(key: "outbound.trojan", displayName: "Trojan outbound", kind: .outboundProtocol, rule: .supported(note: "当前官方出站协议列表可见。"), docsPath: "/config/outbounds/trojan.html"),
        XrayCapabilityDefinition(key: "outbound.vless", displayName: "VLESS outbound", kind: .outboundProtocol, rule: .supported(note: "当前官方出站协议列表可见。"), docsPath: "/config/outbounds/vless.html"),
        XrayCapabilityDefinition(key: "outbound.vmess", displayName: "VMess outbound", kind: .outboundProtocol, rule: .supported(note: "当前官方出站协议列表可见。"), docsPath: "/config/outbounds/vmess.html"),
        XrayCapabilityDefinition(key: "outbound.anytls", displayName: "AnyTLS outbound", kind: .outboundProtocol, rule: XraySupportRule(status: .unsupported, legacyMin: nil, calendarMin: nil, removedAt: nil, note: "V2rayU 当前未实现 Xray-core AnyTLS outbound 配置生成；按 capability rule 自动选择 sing-box。"), docsPath: nil),
        XrayCapabilityDefinition(key: "outbound.naive", displayName: "Naive outbound", kind: .outboundProtocol, rule: XraySupportRule(status: .unsupported, legacyMin: nil, calendarMin: nil, removedAt: nil, note: "Xray-core/V2rayU 当前没有 naive outbound 配置生成；按 capability rule 自动选择 sing-box。"), docsPath: nil),
        XrayCapabilityDefinition(key: "outbound.wireguard", displayName: "WireGuard outbound", kind: .outboundProtocol, rule: .supported(note: "当前官方出站协议列表明确列出。"), docsPath: "/config/outbounds/wireguard.html"),
        XrayCapabilityDefinition(key: "outbound.hysteria", displayName: "Hysteria outbound", kind: .outboundProtocol, rule: .supported(note: "当前官方出站协议列表明确列出。"), docsPath: "/config/outbounds/hysteria.html"),

        // MARK: Transport methods
        XrayCapabilityDefinition(key: "transport.raw", displayName: "RAW transport", kind: .transportMethod, rule: .supported(note: "当前官方 transport 主列表可见；RAW 为曾经 TCP transport 的新名称。"), docsPath: "/config/transports/raw.html"),
        XrayCapabilityDefinition(key: "transport.tcpAlias", displayName: "TCP (RAW alias)", kind: .transportMethod, rule: .compatibility(note: "V2rayU 当前节点模型仍以 tcp 表示 RAW；官方当前文档使用 RAW 命名。"), docsPath: "/config/transports/raw.html"),
        XrayCapabilityDefinition(
            key: "transport.xhttp",
            displayName: "XHTTP transport",
            kind: .transportMethod,
            rule: .supported(note: "官方当前 transport 主列表可见；这里保留 V2rayU 现有的 XHTTP 最低版本兼容阈值。", legacyMin: XrayVersion(1, 8, 24), calendarMin: XrayVersion(24, 9, 30), removedAt: nil),
            docsPath: "/config/transports/xhttp.html",
            evidence: [
                CapabilityEvidence(
                    id: "release-v25.4.30-xhttp-default-mode",
                    kind: "releaseNote",
                    statement: "Xray-core v25.4.30 的 release note 已明确讨论 XHTTP 的默认行为变化，可确认 XHTTP 在新历版本线中已是实际存在且持续维护的 transport；这条证据用于支持功能存在与持续演进，不单独声明精确首发版本。",
                    sourceTitle: "Xray-core v25.4.30 release notes",
                    sourceURL: "https://github.com/XTLS/Xray-core/releases/tag/v25.4.30",
                    sourceVersion: "25.4.30",
                    sourceDate: "2025-04-30",
                    quote: "XHTTP TLS 默认改为 packet-up，XHTTP REALITY 默认仍为 stream-one",
                    reviewedAt: "2026-05-18",
                    note: "来自当前仓库内的 release 分析整理，原始来源为对应 GitHub release 页面。"
                )
            ]
        ),
        XrayCapabilityDefinition(key: "transport.mkcp", displayName: "mKCP transport", kind: .transportMethod, rule: .supported(note: "当前官方 transport 主列表可见。"), docsPath: "/config/transports/mkcp.html"),
        XrayCapabilityDefinition(key: "transport.grpc", displayName: "gRPC transport", kind: .transportMethod, rule: .supported(note: "当前官方 transport 主列表仍明确列出，因此 V2rayU 不再将其视为已下架功能。"), docsPath: "/config/transports/grpc.html"),
        XrayCapabilityDefinition(key: "transport.websocket", displayName: "WebSocket transport", kind: .transportMethod, rule: .supported(note: "当前官方 transport 主列表仍明确列出，因此 V2rayU 不再将其视为已下架功能。"), docsPath: "/config/transports/websocket.html"),
        XrayCapabilityDefinition(key: "transport.httpupgrade", displayName: "HTTPUpgrade transport", kind: .transportMethod, rule: .supported(note: "当前官方 transport 主列表明确列出。"), docsPath: "/config/transports/httpupgrade.html"),
        XrayCapabilityDefinition(key: "transport.hysteria", displayName: "Hysteria transport", kind: .transportMethod, rule: .supported(note: "当前官方 transport 主列表明确列出。"), docsPath: "/config/transports/hysteria.html"),

        // MARK: Legacy or compatibility items
        XrayCapabilityDefinition(key: "transport.h2", displayName: "HTTP/2 transport", kind: .transportMethod, rule: .legacy(note: "HTTP/2 不在当前官方 transport 主列表中，但站点仍保留历史页面/兼容痕迹；V2rayU 对导入的旧节点保留兼容，不再直接假定其已在所有新版本中下架。"), docsPath: "/config/transports/h2.html"),
        XrayCapabilityDefinition(key: "transport.quic", displayName: "QUIC transport", kind: .transportMethod, rule: .legacy(note: "QUIC 不在当前官方 transport 主列表中，但站点仍保留历史页面；V2rayU 仅作历史兼容映射。"), docsPath: "/config/transports/quic.html"),
        XrayCapabilityDefinition(key: "transport.domainsocket", displayName: "Domain Socket transport", kind: .transportMethod, rule: .compatibility(note: "当前官方 transport 主列表未单列 Domain Socket；V2rayU 仅按现有模型做兼容保留。"), docsPath: nil),

        // MARK: Transport security / additional config
        XrayCapabilityDefinition(key: "security.none", displayName: "No extra transport security", kind: .transportSecurity, rule: .compatibility(note: "无 TLS/REALITY 时的默认情况，不在官方 transport security 主列表单列。"), docsPath: nil),
        XrayCapabilityDefinition(key: "security.reality", displayName: "REALITY", kind: .transportSecurity, rule: .supported(note: "当前官方 transport security 主列表明确列出。"), docsPath: "/config/transports/reality.html"),
        XrayCapabilityDefinition(key: "security.tls", displayName: "TLS", kind: .transportSecurity, rule: .supported(note: "当前官方 transport security 主列表明确列出。"), docsPath: "/config/transports/tls.html"),
        XrayCapabilityDefinition(
            key: "security.tls.allowInsecure",
            displayName: "TLS allowInsecure",
            kind: .transportSecurity,
            rule: .removed(note: "Xray-core 自 26.1.31 移除 allowInsecure，并于 UTC 2026-06-01 00:00 起硬禁用；请改用 pinnedPeerCertSha256（应用会自动获取证书指纹），获取失败或 Hysteria2 将回退 Sing-Box。", removedAt: XrayVersion(26, 1, 31)),
            docsPath: "/config/transports/tls.html",
            evidence: [
                CapabilityEvidence(
                    id: "release-v26.2.6-allowinsecure-removed",
                    kind: "releaseNote",
                    statement: "Xray-core v26.2.6 release note 明确移除 allowInsecure，迁移到 pinnedPeerCertSha256 / verifyPeerCertByName，并设延时自动禁用至 UTC 2026-06-01。",
                    sourceTitle: "Xray-core v26.2.6 release notes",
                    sourceURL: "https://github.com/XTLS/Xray-core/releases/tag/v26.2.6",
                    sourceVersion: "26.2.6",
                    sourceDate: "2026-02-06",
                    quote: "TLS 移除了 allowInsecure 配置项，请使用 pinnedPeerCertSha256 和 verifyPeerCertByName 代替",
                    reviewedAt: "2026-06-01",
                    note: "首次移除见 v26.1.31；hy2 自签 + pinnedPeerCertSha256 失效见 issue #5655。"
                )
            ]
        ),
        XrayCapabilityDefinition(key: "additional.finalmask", displayName: "FinalMask", kind: .additionalConfig, rule: .supported(note: "当前官方 additional config 主列表明确列出。"), docsPath: "/config/transports/finalmask.html"),
        XrayCapabilityDefinition(key: "additional.sockopt", displayName: "Sockopt", kind: .additionalConfig, rule: .supported(note: "当前官方 additional config 主列表明确列出。"), docsPath: "/config/transports/sockopt.html"),

        // MARK: Flow - app-level compatibility notes
        XrayCapabilityDefinition(key: "flow.xtls-rprx-vision", displayName: "xtls-rprx-vision flow", kind: .flow, rule: .compatibility(note: "Flow 属 VLESS/XTLS 细分配置，当前并不在官方 transport 列表单列，V2rayU 暂不基于 docs 对其做硬版本校验。"), docsPath: "/config/inbounds/vless.html"),
        XrayCapabilityDefinition(key: "flow.xtls-rprx-vision-udp443", displayName: "xtls-rprx-vision-udp443 flow", kind: .flow, rule: .compatibility(note: "Flow 属 VLESS/XTLS 细分配置，当前并不在官方 transport 列表单列，V2rayU 暂不基于 docs 对其做硬版本校验。"), docsPath: "/config/inbounds/vless.html")
    ]

    static func allCapabilities() -> [XrayCapabilityDefinition] {
        if let document = CapabilityRulesLoader.load(core: .xray) {
            let configured = document.capabilities.compactMap(XrayCapabilityDefinition.init(payload:))
            if !configured.isEmpty {
                return configured
            }
        }
        return builtInCapabilities
    }

    static func definitions(for kind: XrayCapabilityKind) -> [XrayCapabilityDefinition] {
        allCapabilities().filter { $0.kind == kind }
    }

    /// Check whether a specific capability is supported by the current core version
    static func isSupported(key: String) -> Bool {
        guard let definition = capability(forKey: key) else { return true }
        let version = XrayCompatibilityResolver.currentVersion()
        return evaluate(definition: definition, version: version) == nil
    }

    static func definition(forOutbound protocol: V2rayProtocolOutbound) -> XrayCapabilityDefinition? {
        switch `protocol` {
        case .freedom:
            return capability(forKey: "outbound.freedom")
        case .blackhole:
            return capability(forKey: "outbound.blackhole")
        case .dns:
            return capability(forKey: "outbound.dns")
        case .http:
            return capability(forKey: "outbound.http")
        case .socks:
            return capability(forKey: "outbound.socks")
        case .shadowsocks:
            return capability(forKey: "outbound.shadowsocks")
        case .vmess:
            return capability(forKey: "outbound.vmess")
        case .vless:
            return capability(forKey: "outbound.vless")
        case .trojan:
            return capability(forKey: "outbound.trojan")
        case .hysteria2:
            return capability(forKey: "outbound.hysteria")
        case .anytls:
            return capability(forKey: "outbound.anytls")
        case .naive:
            return capability(forKey: "outbound.naive")
        }
    }

    static func definition(forTransport network: V2rayStreamNetwork) -> XrayCapabilityDefinition? {
        switch network {
        case .tcp:
            return capability(forKey: "transport.tcpAlias")
        case .kcp:
            return capability(forKey: "transport.mkcp")
        case .quic:
            return capability(forKey: "transport.quic")
        case .domainsocket:
            return capability(forKey: "transport.domainsocket")
        case .ws:
            return capability(forKey: "transport.websocket")
        case .h2:
            return capability(forKey: "transport.h2")
        case .grpc:
            return capability(forKey: "transport.grpc")
        case .xhttp:
            return capability(forKey: "transport.xhttp")
        case .hysteria2:
            return capability(forKey: "transport.hysteria")
        }
    }

    static func definition(forSecurity security: V2rayStreamSecurity) -> XrayCapabilityDefinition? {
        switch security {
        case .none:
            return capability(forKey: "security.none")
        case .tls:
            return capability(forKey: "security.tls")
        case .reality:
            return capability(forKey: "security.reality")
        case .xtls:
            return capability(forKey: "security.tls")
        }
    }

    static func definition(forFlow flow: String) -> XrayCapabilityDefinition? {
        switch flow {
        case "xtls-rprx-vision":
            return capability(forKey: "flow.xtls-rprx-vision")
        case "xtls-rprx-vision-udp443":
            return capability(forKey: "flow.xtls-rprx-vision-udp443")
        default:
            return nil
        }
    }

    static func capability(forKey key: String) -> XrayCapabilityDefinition? {
        allCapabilities().first { $0.key == key } ?? builtInCapabilities.first { $0.key == key }
    }

    static func evaluate(definition: XrayCapabilityDefinition, version: XrayVersion?) -> XrayCompatibilityIssue? {
        let availability = definition.rule.evaluate(version: version, featureName: definition.displayName)
        switch availability {
        case .supported:
            return nil
        case .advisory, .unsupported, .unknown:
            return XrayCompatibilityIssue(capability: definition, availability: availability)
        }
    }
}

enum SingboxFallbackResolver {
    private struct RequiredCapability {
        let key: String
        let displayName: String
        let kind: XrayCapabilityKind
    }

    static func incompatibilityReasons(for profile: ProfileEntity) -> [String] {
        guard let document = CapabilityRulesLoader.load(core: .singbox) else {
            return legacyFallbackReasons(for: profile)
        }

        let version = SingboxVersion(getSingboxVersion())
        let capabilities = Dictionary(uniqueKeysWithValues: document.capabilities.map { ($0.key, $0) })
        var reasons: [String] = []

        appendReasons(for: outboundRequirement(for: profile.protocol), capabilities: capabilities, version: version, reasons: &reasons)
        appendReasons(for: transportRequirement(for: profile.network), capabilities: capabilities, version: version, reasons: &reasons)
        appendReasons(for: securityRequirement(for: profile.security), capabilities: capabilities, version: version, reasons: &reasons)

        if !profile.flow.isEmpty {
            appendReasons(for: flowRequirement(for: profile.flow), capabilities: capabilities, version: version, reasons: &reasons)
        }

        if profile.network == .tcp && profile.headerType == .http {
            appendReasons(for: RequiredCapability(key: "additional.tcphttpheader", displayName: "TCP + HTTP header disguise", kind: .additionalConfig), capabilities: capabilities, version: version, reasons: &reasons)
        }

        return unique(reasons)
    }

    private static func appendReasons(for requirement: RequiredCapability?, capabilities: [String: CapabilityPayload], version: SingboxVersion?, reasons: inout [String]) {
        guard let requirement else {
            return
        }
        guard let capability = capabilities[requirement.key] else {
            reasons.append("Sing-Box 功能支持规则未声明 [\(requirement.kind.rawValue)] \(requirement.displayName)，无法安全自动回退。")
            return
        }
        reasons.append(contentsOf: Self.reasons(for: capability, version: version))
    }

    private static func reasons(for capability: CapabilityPayload, version: SingboxVersion?) -> [String] {
        var reasons: [String] = []

        if let coreReason = coreBlockingReason(for: capability, version: version) {
            reasons.append(coreReason)
        }

        if let appSupport = capability.appSupport {
            switch appSupport.level {
            case .supported, .advisory:
                break
            case .unsupported:
                reasons.append("Sing-Box [\(capability.kind.rawValue)] \(capability.displayName)：\(appSupport.note)")
            }
        }

        return reasons
    }

    private static func coreBlockingReason(for capability: CapabilityPayload, version: SingboxVersion?) -> String? {
        let minimumVersion = capability.rule.legacyMin.flatMap(SingboxVersion.init)
        let removedAt = capability.rule.removedAt.flatMap(SingboxVersion.init)

        if minimumVersion != nil || removedAt != nil {
            guard let version else {
                return "Sing-Box [\(capability.kind.rawValue)] \(capability.displayName)：无法识别当前 sing-box 版本，不能确认版本边界。\(capability.rule.note)"
            }
            if let removedAt, version >= removedAt {
                return "Sing-Box [\(capability.kind.rawValue)] \(capability.displayName)：当前版本 \(version.description) 已落入配置声明的受限区间（>= \(removedAt.description)）。\(capability.rule.note)"
            }
            if let minimumVersion, version < minimumVersion {
                return "Sing-Box [\(capability.kind.rawValue)] \(capability.displayName)：需要版本 >= \(minimumVersion.description)。\(capability.rule.note)"
            }
        }

        switch capability.rule.type {
        case .supported, .legacy, .compatibility:
            return nil
        case .unsupported:
            return "Sing-Box [\(capability.kind.rawValue)] \(capability.displayName)：当前状态为 unsupported，不能作为安全自动回退目标。\(capability.rule.note)"
        case .removed:
            return "Sing-Box [\(capability.kind.rawValue)] \(capability.displayName)：当前状态为 removed，不作为安全自动回退目标。\(capability.rule.note)"
        case .pendingReview:
            return "Sing-Box [\(capability.kind.rawValue)] \(capability.displayName)：当前状态为 pendingReview，缺少足够依据确认自动回退安全性。\(capability.rule.note)"
        }
    }

    private static func outboundRequirement(for protocol: V2rayProtocolOutbound) -> RequiredCapability? {
        switch `protocol` {
        case .freedom:
            return RequiredCapability(key: "outbound.freedom", displayName: "Direct outbound", kind: .outboundProtocol)
        case .blackhole:
            return RequiredCapability(key: "outbound.blackhole", displayName: "Block outbound", kind: .outboundProtocol)
        case .dns:
            return RequiredCapability(key: "outbound.dns", displayName: "DNS outbound", kind: .outboundProtocol)
        case .http:
            return RequiredCapability(key: "outbound.http", displayName: "HTTP outbound", kind: .outboundProtocol)
        case .socks:
            return RequiredCapability(key: "outbound.socks", displayName: "SOCKS outbound", kind: .outboundProtocol)
        case .shadowsocks:
            return RequiredCapability(key: "outbound.shadowsocks", displayName: "Shadowsocks outbound", kind: .outboundProtocol)
        case .vmess:
            return RequiredCapability(key: "outbound.vmess", displayName: "VMess outbound", kind: .outboundProtocol)
        case .vless:
            return RequiredCapability(key: "outbound.vless", displayName: "VLESS outbound", kind: .outboundProtocol)
        case .trojan:
            return RequiredCapability(key: "outbound.trojan", displayName: "Trojan outbound", kind: .outboundProtocol)
        case .hysteria2:
            return RequiredCapability(key: "outbound.hysteria2", displayName: "Hysteria2 outbound", kind: .outboundProtocol)
        case .anytls:
            return RequiredCapability(key: "outbound.anytls", displayName: "AnyTLS outbound", kind: .outboundProtocol)
        case .naive:
            return RequiredCapability(key: "outbound.naive", displayName: "Naive outbound", kind: .outboundProtocol)
        }
    }

    private static func transportRequirement(for network: V2rayStreamNetwork) -> RequiredCapability? {
        switch network {
        case .tcp:
            return RequiredCapability(key: "transport.tcpAlias", displayName: "TCP transport", kind: .transportMethod)
        case .kcp:
            return RequiredCapability(key: "transport.kcp", displayName: "KCP transport", kind: .transportMethod)
        case .quic:
            return RequiredCapability(key: "transport.quic", displayName: "QUIC transport", kind: .transportMethod)
        case .domainsocket:
            return RequiredCapability(key: "transport.domainsocket", displayName: "Domain Socket transport", kind: .transportMethod)
        case .ws:
            return RequiredCapability(key: "transport.websocket", displayName: "WebSocket transport", kind: .transportMethod)
        case .h2:
            return RequiredCapability(key: "transport.h2", displayName: "HTTP transport", kind: .transportMethod)
        case .grpc:
            return RequiredCapability(key: "transport.grpc", displayName: "gRPC transport", kind: .transportMethod)
        case .xhttp:
            return RequiredCapability(key: "transport.xhttp", displayName: "XHTTP transport", kind: .transportMethod)
        case .hysteria2:
            return RequiredCapability(key: "transport.hysteria2", displayName: "Hysteria2 transport", kind: .transportMethod)
        }
    }

    private static func securityRequirement(for security: V2rayStreamSecurity) -> RequiredCapability? {
        switch security {
        case .none:
            return RequiredCapability(key: "security.none", displayName: "No extra transport security", kind: .transportSecurity)
        case .tls:
            return RequiredCapability(key: "security.tls", displayName: "TLS", kind: .transportSecurity)
        case .reality:
            return RequiredCapability(key: "security.reality", displayName: "REALITY", kind: .transportSecurity)
        case .xtls:
            return RequiredCapability(key: "security.xtls", displayName: "XTLS", kind: .transportSecurity)
        }
    }

    private static func flowRequirement(for flow: String) -> RequiredCapability? {
        switch flow {
        case "xtls-rprx-vision":
            return RequiredCapability(key: "flow.xtls-rprx-vision", displayName: "xtls-rprx-vision flow", kind: .flow)
        case "xtls-rprx-vision-udp443":
            return RequiredCapability(key: "flow.xtls-rprx-vision-udp443", displayName: "xtls-rprx-vision-udp443 flow", kind: .flow)
        default:
            return nil
        }
    }

    private static func unique(_ reasons: [String]) -> [String] {
        var seen: Set<String> = []
        return reasons.filter { seen.insert($0).inserted }
    }

    private static func legacyFallbackReasons(for profile: ProfileEntity) -> [String] {
        var reasons: [String] = []

        switch profile.protocol {
        case .http:
            reasons.append("当前节点使用 HTTP outbound，现有自动回退逻辑无法等价转换到 Sing-Box。")
        case .dns:
            reasons.append("当前节点使用 DNS outbound，现有自动回退逻辑无法等价转换到 Sing-Box。")
        default:
            break
        }

        switch profile.network {
        case .xhttp:
            reasons.append("当前节点使用 xhttp 传输，Sing-Box 回退路径暂无可用等价实现，不能直接自动切换。")
        default:
            break
        }

        if profile.security == .xtls {
            reasons.append("当前节点使用 XTLS，现有自动回退逻辑未实现对应的 Sing-Box 配置转换。")
        }

        if profile.network == .tcp && profile.headerType == .http {
            reasons.append("当前节点使用 TCP + HTTP 伪装，现有自动回退逻辑未实现对应的 Sing-Box 配置转换。")
        }

        return reasons
    }
}

enum XrayCompatibilityResolver {
    private static let capabilityRulesNotice = "当前兼容判定优先使用本地功能支持规则配置；若本地未提供，则回退到内置 Swift 默认值。"
    private static let defaultLatestReviewedCalendarVersion = XrayVersion(26, 3, 27)

    static func currentVersion() -> XrayVersion? {
        XrayVersion(getCoreVersion())
    }

    private static func latestReviewedCalendarVersion() -> XrayVersion {
        if let configured = CapabilityRulesLoader.load(core: .xray)?.latestReviewedVersion,
           let version = XrayVersion(configured),
           version.isCalendarStyle {
            return version
        }
        return defaultLatestReviewedCalendarVersion
    }

    private static func forwardCompatibilityNotice(for version: XrayVersion?) -> String? {
        let latestReviewedCalendarVersion = latestReviewedCalendarVersion()
        guard let version, version.isCalendarStyle, version > latestReviewedCalendarVersion else {
            return nil
        }
        return "当前 Xray-core 版本 \(version.description) 高于功能支持规则最近一次核对的日期版本 \(latestReviewedCalendarVersion.description)。本次仍按配置中的开区间规则判定；如上游后续发生功能变更，需要更新功能支持规则配置。"
    }

    static func fullSupportList() -> [XrayCapabilityDefinition] {
        XraySupportCatalog.allCapabilities()
    }

    static func decision(for profile: ProfileEntity) -> XrayCoreCompatibilityDecision {
        switch profile.resolvedCoreSelection {
        case .auto:
            return automaticDecision(for: profile)
        case .xray:
            return xrayDecision(for: profile)
        case .singbox:
            return singboxDecision(for: profile)
        }
    }

    private static func automaticDecision(for profile: ProfileEntity) -> XrayCoreCompatibilityDecision {
        let version = currentVersion()
        let shortVersion = getCoreShortVersion()
        let forwardNotice = forwardCompatibilityNotice(for: version)
        let issues = xrayIssues(for: profile, version: version)

        if issues.isEmpty {
            return XrayCoreCompatibilityDecision(coreType: .XrayCore, warningMessage: nil, issues: [], canLaunch: true)
        }

        let blockingIssues = issues.filter(\.isBlocking)
        let issueText = issues.map(\.message).joined(separator: "\n")
        let futureVersionText = forwardNotice.map { "\n\n\($0)" } ?? ""

        if blockingIssues.isEmpty {
            // 无非阻塞问题：检查 sing-box 是否能接管；能则静默切换，否则继续用 xray 并提示
            let fallbackReasons = SingboxFallbackCompatibility.incompatibilityReasons(for: profile)
            if fallbackReasons.isEmpty {
                return singboxFallbackDecision(for: profile, issues: issues)
            }
            let warningMessage = "当前节点与已安装的 Xray-core \(shortVersion) 存在以下兼容性提示：\n\n\(issueText)\n\n本次仍继续使用 Xray-core 启动。\n\n\(capabilityRulesNotice)\(futureVersionText)"
            return XrayCoreCompatibilityDecision(coreType: .XrayCore, warningMessage: warningMessage, issues: issues, canLaunch: true)
        }

        let fallbackReasons = SingboxFallbackCompatibility.incompatibilityReasons(for: profile)
        if !fallbackReasons.isEmpty {
            let fallbackText = fallbackReasons.map { "• [回退受限] \($0)" }.joined(separator: "\n")
            let warningMessage = "当前节点与已安装的 Xray-core \(shortVersion) 存在以下不兼容项：\n\n\(issueText)\n\n此外，当前节点不能自动回退到 Sing-Box：\n\n\(fallbackText)\n\n请升级 Xray-core，或调整节点配置后重试。\n\n\(capabilityRulesNotice)\(futureVersionText)"
            return XrayCoreCompatibilityDecision(coreType: .XrayCore, warningMessage: warningMessage, issues: issues, canLaunch: false)
        }

        return singboxFallbackDecision(for: profile, issues: issues)
    }

    private static func singboxFallbackDecision(for profile: ProfileEntity, issues: [XrayCompatibilityIssue]) -> XrayCoreCompatibilityDecision {
        var warningMessage: String?
        if profile.protocol == .vmess && profile.alterId > 0 {
            warningMessage = "VMess alterId > 0（旧版 MD5 认证）与 sing-box 不兼容，请将 alterId 改为 0（AEAD 模式）"
        }
        return XrayCoreCompatibilityDecision(coreType: .SingBox, warningMessage: warningMessage, issues: issues, canLaunch: true)
    }

    private static func xrayDecision(for profile: ProfileEntity) -> XrayCoreCompatibilityDecision {
        let version = currentVersion()
        let shortVersion = getCoreShortVersion()
        let forwardNotice = forwardCompatibilityNotice(for: version)
        let issues = xrayIssues(for: profile, version: version)

        guard !issues.isEmpty else {
            return XrayCoreCompatibilityDecision(coreType: .XrayCore, warningMessage: nil, issues: [], canLaunch: true)
        }

        let issueText = issues.map(\.message).joined(separator: "\n")
        let futureVersionText = forwardNotice.map { "\n\n\($0)" } ?? ""
        let blockingIssues = issues.filter(\.isBlocking)

        if blockingIssues.isEmpty {
            let warningMessage = "当前节点已手动选择 Xray-core；与已安装的 Xray-core \(shortVersion) 存在以下兼容性提示：\n\n\(issueText)\n\n本次仍继续使用 Xray-core 启动。\n\n\(capabilityRulesNotice)\(futureVersionText)"
            return XrayCoreCompatibilityDecision(coreType: .XrayCore, warningMessage: warningMessage, issues: issues, canLaunch: true)
        }

        let warningMessage = "当前节点已手动选择 Xray-core，但与已安装的 Xray-core \(shortVersion) 存在以下不兼容项：\n\n\(issueText)\n\n请切换为 Auto/Sing-Box，升级 Xray-core，或调整节点配置后重试。\n\n\(capabilityRulesNotice)\(futureVersionText)"
        return XrayCoreCompatibilityDecision(coreType: .XrayCore, warningMessage: warningMessage, issues: issues, canLaunch: false)
    }

    private static func singboxDecision(for profile: ProfileEntity) -> XrayCoreCompatibilityDecision {
        let fallbackReasons = SingboxFallbackCompatibility.incompatibilityReasons(for: profile)
        guard fallbackReasons.isEmpty else {
            let fallbackText = fallbackReasons.map { "• [不兼容] \($0)" }.joined(separator: "\n")
            let warningMessage = "当前节点已手动选择 Sing-Box，但依据功能支持规则检测到以下不兼容项：\n\n\(fallbackText)\n\n请切换为 Auto/Xray，更新 Sing-Box 功能支持规则，或调整节点配置后重试。\n\n\(capabilityRulesNotice)"
            return XrayCoreCompatibilityDecision(coreType: .SingBox, warningMessage: warningMessage, issues: [], canLaunch: false)
        }

        return XrayCoreCompatibilityDecision(coreType: .SingBox, warningMessage: nil, issues: [], canLaunch: true)
    }

    private static func xrayIssues(for profile: ProfileEntity, version: XrayVersion?) -> [XrayCompatibilityIssue] {
        var issues: [XrayCompatibilityIssue] = []

        if let definition = XraySupportCatalog.definition(forOutbound: profile.protocol),
           let issue = XraySupportCatalog.evaluate(definition: definition, version: version) {
            issues.append(issue)
        }

        if let definition = XraySupportCatalog.definition(forTransport: profile.network),
           let issue = XraySupportCatalog.evaluate(definition: definition, version: version) {
            issues.append(issue)
        }


        if let definition = XraySupportCatalog.definition(forSecurity: profile.security),
           let issue = XraySupportCatalog.evaluate(definition: definition, version: version) {
            issues.append(issue)
        }

        if !profile.flow.isEmpty,
           let definition = XraySupportCatalog.definition(forFlow: profile.flow),
           let issue = XraySupportCatalog.evaluate(definition: definition, version: version) {
            issues.append(issue)
        }

        if let issue = allowInsecureIssue(for: profile, version: version) {
            issues.append(issue)
        }

        return issues
    }

    // allowInsecure 在 Xray-core 26.1.31 被移除。新核心下：
    // - 已自动获取到 pinnedPeerCertSha256 的普通 TLS 节点 -> 可继续用 Xray（无 issue）。
    // - Hysteria2 -> 无法用 TCP tls ping 取证书，且 Xray hy2 自签 + pinnedPeerCertSha256 失效(#5655)，强制回退 Sing-Box。
    // - 其余未能取到指纹的节点 -> 阻塞，交由自动回退到 Sing-Box（sing-box 仍支持 insecure）。
    private static func allowInsecureIssue(for profile: ProfileEntity, version: XrayVersion?) -> XrayCompatibilityIssue? {
        guard profile.security == .tls, profile.allowInsecure else { return nil }
        // 仅 >= 26.1.31 的核心受影响；旧核心仍支持 allowInsecure。版本未知时按现代核心处理。
        if let version, version < xrayAllowInsecureRemovedVersion { return nil }
        guard let definition = XraySupportCatalog.capability(forKey: "security.tls.allowInsecure") else { return nil }
        let versionText = version?.description ?? "(未知版本)"

        if profile.protocol == .hysteria2 {
            return XrayCompatibilityIssue(capability: definition, availability: .unsupported(
                reason: "Hysteria2 在 Xray-core \(versionText) 无法用 allowInsecure 跳过证书校验（26.1.31 已移除），且无法自动获取其 QUIC 证书指纹、Xray hy2 自签 + pinnedPeerCertSha256 当前不可用（#5655）；将回退 Sing-Box。"))
        }

        let hasPin = !profile.pinnedPeerCertSha256.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if hasPin { return nil }

        return XrayCompatibilityIssue(capability: definition, availability: .unsupported(
            reason: "allowInsecure 已在 Xray-core 26.1.31 移除；未能自动获取服务器证书指纹（pinnedPeerCertSha256），将回退 Sing-Box。请确认节点可达后重试 Ping 以重新获取。"))
    }
}

extension ProfileEntity {
    var resolvedCoreSelection: ProfileCoreSelection {
        if let coreType, coreType != .auto {
            return coreType
        }
        return CoreSelectionDefaults.selection(for: self.protocol)
    }

    func resolveCoreCompatibility() -> XrayCoreCompatibilityDecision {
        XrayCompatibilityResolver.decision(for: self)
    }
}
