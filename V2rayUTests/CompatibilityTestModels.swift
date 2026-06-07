import Foundation
@testable import V2rayU

// MARK: - Test environment configuration

struct CompatibilityTestConfig {
    /// Root directory containing versioned core binaries
    static var binDir: String {
        ProcessInfo.processInfo.environment["V2RAYU_TEST_BIN_DIR"]
            ?? "\(projectRoot)/Build/tests/bin"
    }

    /// Report output directory
    static var reportDir: String {
        ProcessInfo.processInfo.environment["V2RAYU_TEST_REPORT_DIR"]
            ?? "\(projectRoot)/Build/tests/reports"
    }

    /// Report file path for current run
    static var reportPath: String {
        let fm = DateFormatter()
        fm.dateFormat = "yyyy-MM-dd_HHmmss"
        let ts = fm.string(from: Date())
        return "\(reportDir)/compatibility-report-\(ts).json"
    }

    /// Xray versions to test (sorted ascending)
    static let xrayVersions: [String] = {
        sampled(versionsInRange(
            coreDir: "\(binDir)/xray-core",
            min: "v1.8.0",
            max: "v26.5.6"
        ))
    }()

    /// Sing-box versions to test (sorted ascending)
    static let singboxVersions: [String] = {
        sampled(versionsInRange(
            coreDir: "\(binDir)/sing-box",
            min: "v1.12.0",
            max: "v1.13.12"
        ))
    }()

    static var projectRoot: String {
        if let envPath = ProcessInfo.processInfo.environment["PROJECT_DIR"]
            ?? ProcessInfo.processInfo.environment["SRCROOT"] {
            return envPath
        }
        // Fallback: calculate from file path
        // xcodebuild typically gives full path in #file
        let base = #file as NSString
        // Go up from V2rayUTests/ to project root
        let dir = (base.deletingLastPathComponent as NSString).deletingLastPathComponent
        return dir
    }

    /// Check if test binaries are available for a given core type
    static func isAvailable(core: CoreType) -> Bool {
        switch core {
        case .XrayCore: return !xrayVersions.isEmpty
        case .SingBox: return !singboxVersions.isEmpty
        }
    }

    /// Get the binary path for a specific core version
    static func binaryPath(core: CoreType, version: String) -> String {
        let subDir: String
        let binaryName: String
        #if arch(arm64)
        switch core {
        case .XrayCore: binaryName = "xray-arm64"
        case .SingBox: binaryName = "sing-box-arm64"
        }
        #else
        switch core {
        case .XrayCore: binaryName = "xray-64"
        case .SingBox: binaryName = "sing-box-64"
        }
        #endif
        switch core {
        case .XrayCore: subDir = "xray-core"
        case .SingBox: subDir = "sing-box"
        }
        return "\(binDir)/\(subDir)/\(version)/\(binaryName)"
    }

    /// Sample N versions evenly from the sorted list (env V2RAYU_SAMPLE_VERSIONS, default 0 = all)
    static func sampled(_ versions: [String]) -> [String] {
        let maxStr = ProcessInfo.processInfo.environment["V2RAYU_SAMPLE_VERSIONS"] ?? "0"
        let maxCount = Int(maxStr) ?? 0
        guard maxCount > 0, versions.count > maxCount else { return versions }
        let step = Double(versions.count - 1) / Double(maxCount - 1)
        return (0..<maxCount).map { versions[Int(round(step * Double($0)))] }
    }

    static func versionsInRange(coreDir: String, min: String, max: String) -> [String] {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(atPath: coreDir) else {
            return []
        }
        let minV = XrayVersion(min) ?? XrayVersion(0, 0, 0)
        let maxV = XrayVersion(max) ?? XrayVersion(9999, 0, 0)
        return entries
            .filter { $0.hasPrefix("v") }
            .compactMap { tag -> String? in
                guard let v = XrayVersion(tag) else { return nil }
                return (v >= minV && v <= maxV) ? tag : nil
            }
            .sorted { a, b in
                let va = XrayVersion(a) ?? XrayVersion(0, 0, 0)
                let vb = XrayVersion(b) ?? XrayVersion(0, 0, 0)
                return va < vb
            }
    }
}

// MARK: - Test result models

enum ConnectionTestStatus: String, Codable {
    case skipped       // 根据能力规则跳过（不兼容）
    case pass          // 连接成功
    case fail          // 连接失败（核心启动但代理不通）
    case launchFailed  // 核心进程无法启动
    case configError   // JSON 配置生成失败
    case timeout       // 超时
}

struct ConnectionTestDetail: Codable {
    let status: ConnectionTestStatus
    let latencyMs: Int?
    let error: String?
    let rulePrediction: String  // "supported", "advisory", "unsupported", "unknown"
    let ruleMatched: Bool       // 规则预测与实际结果是否一致
}

struct ProfileTestResult: Codable {
    let profileUUID: String
    let profileRemark: String
    let protocolRaw: String
    let networkRaw: String
    let securityRaw: String
    let coreTypeRaw: String        // "xray" or "sing-box"
    let coreVersion: String
    let connection: ConnectionTestDetail
}

struct CompatibilityTestReport: Codable {
    var schemaVersion: Int = 1
    let generatedAt: String
    let environment: ReportEnvironment
    let summary: ReportSummary
    let ruleMismatches: [RuleMismatchEntry]
    let results: [ProfileTestResult]

    struct ReportEnvironment: Codable {
        let arch: String
        let osVersion: String
        let coreCounts: CoreCounts

        struct CoreCounts: Codable {
            let xrayVersions: Int
            let singboxVersions: Int
        }
    }

    struct ReportSummary: Codable {
        let totalCombinations: Int
        let passed: Int
        let failed: Int
        let skipped: Int
        let launchFailed: Int
        let configErrors: Int
        let ruleMismatchCount: Int
    }

    struct RuleMismatchEntry: Codable {
        let profileUUID: String
        let profileRemark: String
        let coreType: String
        let coreVersion: String
        let protocolRaw: String
        let rulePredicted: String
        let actualStatus: String
        let error: String?
    }
}

// MARK: - Report generation

enum CompatibilityReportGenerator {
    static func generate(from results: [ProfileTestResult]) -> CompatibilityTestReport {
        let summary = CompatibilityTestReport.ReportSummary(
            totalCombinations: results.count,
            passed: results.filter { $0.connection.status == .pass }.count,
            failed: results.filter { $0.connection.status == .fail }.count,
            skipped: results.filter { $0.connection.status == .skipped }.count,
            launchFailed: results.filter { $0.connection.status == .launchFailed }.count,
            configErrors: results.filter { $0.connection.status == .configError }.count,
            ruleMismatchCount: results.filter { !$0.connection.ruleMatched }.count
        )

        let mismatches = results
            .filter { !$0.connection.ruleMatched && $0.connection.status != .skipped }
            .map { result in
                CompatibilityTestReport.RuleMismatchEntry(
                    profileUUID: result.profileUUID,
                    profileRemark: result.profileRemark,
                    coreType: result.coreTypeRaw,
                    coreVersion: result.coreVersion,
                    protocolRaw: result.protocolRaw,
                    rulePredicted: result.connection.rulePrediction,
                    actualStatus: result.connection.status.rawValue,
                    error: result.connection.error
                )
            }

        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        let generatedAt = df.string(from: Date())

        #if arch(arm64)
        let arch = "arm64"
        #else
        let arch = "x86_64"
        #endif

        let env = CompatibilityTestReport.ReportEnvironment(
            arch: arch,
            osVersion: ProcessInfo.processInfo.operatingSystemVersionString,
            coreCounts: .init(
                xrayVersions: CompatibilityTestConfig.xrayVersions.count,
                singboxVersions: CompatibilityTestConfig.singboxVersions.count
            )
        )

        return CompatibilityTestReport(
            generatedAt: generatedAt,
            environment: env,
            summary: summary,
            ruleMismatches: mismatches,
            results: results
        )
    }

    static func writeReport(_ report: CompatibilityTestReport, to path: String) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(report)
        let url = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }
}
