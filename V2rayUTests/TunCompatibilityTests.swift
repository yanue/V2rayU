import Foundation
import Testing
@testable import V2rayU

private actor TunStartupRecorder {
    private var events: [String] = []

    func append(_ event: String) {
        events.append(event)
    }

    func snapshot() -> [String] {
        events
    }
}

@Suite struct TunCompatibilityTests {

    private let configHandler = CoreConfigHandler()
    private let testProfile = ProfileEntity(
        remark: "tun-test",
        protocol: .vmess,
        address: "example.com",
        port: 443,
        password: "test-uuid",
        network: .tcp,
        security: .tls
    )

    @Test("TUN does not start before its SOCKS backend is ready")
    func testTunWaitsForBackendReadiness() async {
        let recorder = TunStartupRecorder()

        let result = await V2rayLaunch.startTunWhenBackendReady(
            waitForBackend: {
                await recorder.append("wait")
                return false
            },
            startDaemon: {
                await recorder.append("start")
                return true
            }
        )

        #expect(result == .backendUnavailable)
        #expect(await recorder.snapshot() == ["wait"])
    }

    @Test("TUN starts after its SOCKS backend is ready")
    func testTunStartsAfterBackendIsReady() async {
        let recorder = TunStartupRecorder()

        let result = await V2rayLaunch.startTunWhenBackendReady(
            waitForBackend: {
                await recorder.append("wait")
                return true
            },
            startDaemon: {
                await recorder.append("start")
                return true
            }
        )

        #expect(result == .started)
        #expect(await recorder.snapshot() == ["wait", "start"])
    }

    @Test("TUN reports a daemon failure after its SOCKS backend is ready")
    func testTunReportsDaemonFailure() async {
        let recorder = TunStartupRecorder()

        let result = await V2rayLaunch.startTunWhenBackendReady(
            waitForBackend: {
                await recorder.append("wait")
                return true
            },
            startDaemon: {
                await recorder.append("start")
                return false
            }
        )

        #expect(result == .daemonFailed)
        #expect(await recorder.snapshot() == ["wait", "start"])
    }

    @Test("TUN exclusion hosts resolve to stable IP prefixes")
    func testTunRouteExcludeHostResolution() {
        let resolved = TunConfigHandler.resolveRouteExcludeAddresses(
            from: """
            vpn.example.test
            198.51.100.20, 2001:db8::1
            10.0.0.0/8
            2001:0db8::3
            127.1
            2130706433
            0x7f000001
            fe80::1%lo0
            192.0.2.1/33
            2001:db8::1/129
            invalid.example.test
            """,
            resolver: { host in
                switch host {
                case "vpn.example.test":
                    return ["192.0.2.10", "2001:db8::2", "192.0.2.10"]
                case "invalid.example.test":
                    return []
                default:
                    return ["203.0.113.9"]
                }
            }
        )

        #expect(resolved == [
            "192.0.2.10/32",
            "2001:db8::2/128",
            "198.51.100.20/32",
            "2001:db8::1/128",
            "10.0.0.0/8",
            "2001:db8::3/128",
        ])
    }

    @Test("Generated TUN config includes configured route exclusions")
    func testTunConfigIncludesRouteExclusions() throws {
        let key = UserDefaults.KEY.tunRouteExcludeHosts.rawValue
        let previousValue = UserDefaults.standard.object(forKey: key)
        defer {
            if let previousValue {
                UserDefaults.standard.set(previousValue, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }

        UserDefaults.set(
            forKey: .tunRouteExcludeHosts,
            value: "192.0.2.10/32\n198.51.100.20"
        )

        let jsonText = TunConfigHandler.buildTunConfig()
        let data = try #require(jsonText.data(using: .utf8))
        let parsed = try JSONDecoder().decode(SingboxStruct.self, from: data)
        let tunInbound = try #require(parsed.inbounds.first(where: { $0.type == "tun" }))

        #expect(tunInbound.route_exclude_address == [
            "192.0.2.10/32",
            "198.51.100.20/32",
        ])
    }

    @Test("TUN config generation and check syntax across all sing-box versions")
    func testTunConfigAcrossVersions() {
        let versions = CompatibilityTestConfig.singboxVersions
        guard !versions.isEmpty else {
            print("SKIP: No sing-box test binaries found in \(CompatibilityTestConfig.binDir)/sing-box/")
            return
        }

        print("=== TUN Config Generation Test ===")
        print("Sing-box versions: \(versions.count)  (\(versions.first!) ~ \(versions.last!))")

        var allResults: [TunTestResult] = []

        for version in versions {
            let result = testSingleVersion(version: version)
            allResults.append(result)
        }

        let report = generateReport(results: allResults)
        printReport(report)

        do {
            try writeReport(report, suffix: "config")
        } catch {
            print("ERROR: Failed to write report: \(error)")
        }

        let failures = allResults.filter { $0.status == .launchFailed || $0.status == .configError }
        if !failures.isEmpty {
            print("WARNING: \(failures.count) version(s) had config/syntax failures:")
            for f in failures {
                print("  - \(f.version): \(f.error ?? "unknown")")
            }
        }
    }

    @Test("TUN runtime connectivity on latest sing-box version")
    func testTunRuntimeConnectivity() {
        let versions = CompatibilityTestConfig.singboxVersions
        #expect(!versions.isEmpty, "No sing-box test binaries found in \(CompatibilityTestConfig.binDir)/sing-box/")
        guard !versions.isEmpty else { return }

        let latestVersion = versions.last!
        let binaryPath = CompatibilityTestConfig.binaryPath(core: .SingBox, version: latestVersion)
        #expect(FileManager.default.isExecutableFile(atPath: binaryPath), "Binary not found: \(binaryPath)")
        guard FileManager.default.isExecutableFile(atPath: binaryPath) else { return }

        // Verify sudoers allows running this binary non-interactively
        let sudoCheck = Process()
        sudoCheck.launchPath = "/usr/bin/sudo"
        sudoCheck.arguments = ["-n", binaryPath, "version"]
        do {
            try sudoCheck.run()
            sudoCheck.waitUntilExit()
        } catch {
            Issue.record("sudo not available: \(error.localizedDescription)")
            return
        }
        #expect(sudoCheck.terminationStatus == 0, "sudo -n NOPASSWD not configured for \(binaryPath)")
        guard sudoCheck.terminationStatus == 0 else { return }

        print("\n=== TUN Runtime Connectivity Test ===")
        print("Version: \(latestVersion)")
        print("Binary: \(binaryPath)")

        testSingboxVersionOverride = latestVersion
        defer { testSingboxVersionOverride = nil }

        let jsonText = TunConfigHandler.buildTunConfig()

        let configFile = "\(AppHomePath)/.tun-runtime-test.json"
        let logFile = "\(AppHomePath)/.tun-runtime-test.log"
        defer {
            try? FileManager.default.removeItem(atPath: configFile)
            try? FileManager.default.removeItem(atPath: logFile)
        }

        do {
            try jsonText.write(to: URL(fileURLWithPath: configFile), atomically: true, encoding: .utf8)
        } catch {
            print("FAIL: Write config failed: \(error.localizedDescription)")
            Issue.record("Write config failed: \(error.localizedDescription)")
            return
        }

        // Count utun interfaces before starting the test TUN
        let utunBefore = countUtunInterfaces()

        // Start TUN mode with sudo
        let process = Process()
        process.launchPath = "/usr/bin/sudo"
        process.arguments = ["-n", binaryPath, "run", "-c", configFile]
        process.currentDirectoryURL = URL(fileURLWithPath: AppHomePath)
        let stderrPipe = Pipe()
        process.standardOutput = FileHandle.nullDevice
        process.standardError = stderrPipe

        do {
            try process.run()
        } catch {
            Issue.record("sudo launch failed: \(error.localizedDescription)")
            return
        }

        let pid = process.processIdentifier
        var newUtunFound = false
        var connectivityOk = false

        defer {
            // Kill TUN process
            if process.isRunning {
                process.interrupt()
                process.terminate()
                for _ in 0..<30 {
                    if !process.isRunning { break }
                    Thread.sleep(forTimeInterval: 0.1)
                }
                if process.isRunning {
                    kill(pid, 9)
                    process.waitUntilExit()
                }
            }
            // Give kernel time to tear down the utun
            Thread.sleep(forTimeInterval: 1.0)
        }

        // Wait up to 10s for a NEW utun interface and connectivity
        let deadline = Date().addingTimeInterval(10)
        var curlAttempt = 0

        while Date() < deadline {
            if !process.isRunning {
                let exitCode = process.terminationStatus
                let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                let stderrText = String(data: stderrData, encoding: .utf8) ?? ""
                Issue.record("sing-box exited early (code \(exitCode)): \(String(stderrText.prefix(200)))")
                break
            }

            // Look for a NEW utun interface (one that appeared after we started)
            let currentUtunCount = countUtunInterfaces()
            if currentUtunCount > utunBefore {
                if !newUtunFound {
                    newUtunFound = true
                }

                // Test connectivity (curl directly - TUN routes all traffic)
                curlAttempt += 1
                if testDirectConnectivity() {
                    connectivityOk = true
                    break
                }
                Thread.sleep(forTimeInterval: 0.5)
            } else {
                Thread.sleep(forTimeInterval: 0.3)
            }
        }

        #expect(newUtunFound, "No new utun interface appeared within 10s for \(latestVersion)")
        #expect(connectivityOk, "Connectivity test failed after \(curlAttempt) attempts for \(latestVersion)")
    }

    // MARK: - Per-version config generation test

    private func testSingleVersion(version: String) -> TunTestResult {
        let binaryPath = CompatibilityTestConfig.binaryPath(core: .SingBox, version: version)
        var result = TunTestResult(version: version, binaryPath: binaryPath)

        testSingboxVersionOverride = version
        defer { testSingboxVersionOverride = nil }

        let jsonText = TunConfigHandler.buildTunConfig()
        result.generatedConfig = jsonText

        guard let data = jsonText.data(using: String.Encoding.utf8),
              let parsed = try? JSONDecoder().decode(SingboxStruct.self, from: data) else {
            result.status = .configError
            result.error = "Failed to parse generated TUN config JSON"
            return result
        }
        result.parsedConfig = parsed

        guard let tunInbound = parsed.inbounds.first(where: { $0.type == "tun" }) else {
            result.status = .configError
            result.error = "No tun inbound found in generated config"
            return result
        }
        result.tunInbound = tunInbound

        guard tunInbound.tag == "tun-in" else {
            result.status = .configError
            result.error = "TUN inbound tag mismatch: expected 'tun-in', got '\(tunInbound.tag ?? "nil")'"
            return result
        }

        guard let address = tunInbound.address, address.contains("10.0.0.1/30") else {
            result.status = .configError
            result.error = "TUN inbound address missing or incorrect"
            return result
        }

        let tunEnableIPv6 = UserDefaults.getBool(forKey: .tunEnableIPv6, default: true)
        if tunEnableIPv6 {
            if !address.contains("fd00::1/64") {
                result.addVersionIssue("Expected IPv6 address fd00::1/64 in TUN inbound address list")
            }
        }

        guard tunInbound.auto_route == true else {
            result.status = .configError
            result.error = "TUN inbound auto_route should be true"
            return result
        }

        guard let socksOutbound = parsed.outbounds.first(where: { $0.type == "socks" }) else {
            result.status = .configError
            result.error = "No socks outbound found in generated TUN config"
            return result
        }

        guard socksOutbound.server == "127.0.0.1" else {
            result.status = .configError
            result.error = "SOCKS outbound server should be 127.0.0.1, got '\(socksOutbound.server ?? "nil")'"
            return result
        }

        guard socksOutbound.server_port != nil, socksOutbound.server_port! > 0 else {
            result.status = .configError
            result.error = "SOCKS outbound port missing or invalid"
            return result
        }

        // Validate version-specific features
        let sv = SingboxVersion(version)

        if let sv, sv < SingboxVersion(1, 11, 0) {
            if tunInbound.sniff != true {
                result.addVersionIssue("Expected sniff=true for sing-box < 1.11.0, got \(tunInbound.sniff ?? nil)")
            }
            if tunInbound.sniff_override_destination != true {
                result.addVersionIssue("Expected sniff_override_destination=true for sing-box < 1.11.0, got \(tunInbound.sniff_override_destination ?? nil)")
            }
        } else {
            if tunInbound.sniff != nil {
                result.addVersionIssue("Expected sniff=nil for sing-box >= 1.11.0, got \(tunInbound.sniff!)")
            }
            if tunInbound.sniff_override_destination != nil {
                result.addVersionIssue("Expected sniff_override_destination=nil for sing-box >= 1.11.0, got \(tunInbound.sniff_override_destination!)")
            }
            let hasSniffRule = parsed.route.rules.contains { $0.action == "sniff" }
            if !hasSniffRule {
                result.addVersionIssue("Expected route rule with action 'sniff' for sing-box >= 1.11.0")
            }
        }

        if let sv, sv >= SingboxVersion(1, 12, 0) {
            if let localDns = parsed.dns.servers.first(where: { $0.tag == "local-dns" }) {
                if localDns.type != "udp" {
                    result.addVersionIssue("Expected DNS server type='udp' for sing-box >= 1.12.0, got '\(localDns.type ?? "nil")'")
                }
                if localDns.server == nil || localDns.server!.isEmpty {
                    result.addVersionIssue("Expected DNS server 'server' field for sing-box >= 1.12.0")
                }
                if localDns.address != nil {
                    result.addVersionIssue("Expected DNS server 'address'=nil for sing-box >= 1.12.0")
                }
            }
        } else {
            if let localDns = parsed.dns.servers.first(where: { $0.tag == "local-dns" }) {
                if localDns.address == nil || !localDns.address!.hasPrefix("udp://") {
                    result.addVersionIssue("Expected DNS server 'address' with udp:// prefix for sing-box < 1.12.0, got '\(localDns.address ?? "nil")'")
                }
                if localDns.type != nil {
                    result.addVersionIssue("Expected DNS server type=nil for sing-box < 1.12.0")
                }
            }
        }

        guard parsed.route.auto_detect_interface == true else {
            result.status = .configError
            result.error = "Route auto_detect_interface should be true"
            return result
        }

        guard parsed.route.default_domain_resolver == "local-dns" else {
            result.status = .configError
            result.error = "Route default_domain_resolver should be 'local-dns'"
            return result
        }

        let hasDirectRule = parsed.route.rules.contains { rule in
            rule.outbound == "direct" && rule.process_name?.contains("sing-box") == true
        }
        if !hasDirectRule {
            result.addVersionIssue("Missing direct outbound bypass rule for sing-box process")
        }

        // Binary syntax check
        if result.status == .pass || result.status == .advisory {
            let syntaxResult = syntaxCheck(binaryPath: binaryPath, jsonText: jsonText, version: version)
            result.status = syntaxResult.status
            result.error = syntaxResult.error
            result.launchLog = syntaxResult.log
        }

        if (result.status == .pass) && !result.versionIssues.isEmpty {
            result.status = .advisory
        }

        return result
    }

    private func syntaxCheck(binaryPath: String, jsonText: String, version: String) -> (status: TunTestStatus, error: String?, log: String?) {
        guard FileManager.default.isExecutableFile(atPath: binaryPath) else {
            return (.skipped, "Binary not found: \(binaryPath)", nil)
        }

        let configFile = "\(AppHomePath)/.tun-compat-\(version).json"
        let logFile = "\(AppHomePath)/.tun-compat-\(version).log"

        do {
            try jsonText.write(to: URL(fileURLWithPath: configFile), atomically: true, encoding: .utf8)
        } catch {
            return (.configError, "Write config failed: \(error.localizedDescription)", nil)
        }

        defer {
            try? FileManager.default.removeItem(atPath: configFile)
            try? FileManager.default.removeItem(atPath: logFile)
        }

        let process = Process()
        process.launchPath = "/bin/bash"
        process.arguments = ["-c", "cd \(AppHomePath) && \(binaryPath) check -c \(configFile) &>\(logFile)"]
        process.standardOutput = nil
        process.standardError = nil

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return (.launchFailed, "Launch failed: \(error.localizedDescription)", nil)
        }

        func readLog() -> String {
            guard let data = try? Data(contentsOf: URL(fileURLWithPath: logFile)),
                  let text = String(data: data, encoding: .utf8) else { return "" }
            let lines = text.components(separatedBy: .newlines).filter { !$0.isEmpty }
            let tail = lines.suffix(20)
            let joined = tail.joined(separator: "\n")
            return joined.count <= 2000 ? joined : String(joined.suffix(2000))
        }

        let logText = readLog()

        if process.terminationStatus == 0 {
            return (.pass, nil, nil)
        }

        if logText.contains("unknown subcommand") || logText.contains("unknown command") {
            return (.skipped, "'check' subcommand not supported", logText)
        }

        return (.launchFailed, "Binary check failed (exit \(process.terminationStatus))", logText)
    }

    // MARK: - Connectivity test helpers

    private func testDirectConnectivity() -> Bool {
        let process = Process()
        process.launchPath = "/usr/bin/curl"
        process.arguments = [
            "--connect-timeout", "2",
            "--max-time", "4",
            "-o", "/dev/null",
            "-s", "-w", "%{http_code}:%{time_total}",
            "https://www.gstatic.com/generate_204",
        ]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return false
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        let parts = output.split(separator: ":", maxSplits: 1)

        guard process.terminationStatus == 0,
              parts.count == 2,
              let httpCode = Int(parts[0]),
              (200..<400).contains(httpCode) else {
            return false
        }
        return true
    }

    private func countUtunInterfaces() -> Int {
        let process = Process()
        process.launchPath = "/sbin/ifconfig"
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return 0
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        let lines = output.components(separatedBy: .newlines)
        return lines.filter { $0.hasPrefix("utun") }.count
    }

    // MARK: - Report generation

    private func generateReport(results: [TunTestResult]) -> TunTestReport {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        let generatedAt = df.string(from: Date())

#if arch(arm64)
        let arch = "arm64"
#else
        let arch = "x86_64"
#endif

        return TunTestReport(
            generatedAt: generatedAt,
            environment: .init(
                arch: arch,
                osVersion: ProcessInfo.processInfo.operatingSystemVersionString,
                singboxVersions: results.count
            ),
            summary: .init(
                total: results.count,
                passed: results.filter { $0.status == .pass }.count,
                advisory: results.filter { $0.status == .advisory }.count,
                skipped: results.filter { $0.status == .skipped }.count,
                launchFailed: results.filter { $0.status == .launchFailed }.count,
                configErrors: results.filter { $0.status == .configError }.count,
                versionIssueCount: results.reduce(0) { $0 + $1.versionIssues.count }
            ),
            details: results.map { detail in
                .init(
                    version: detail.version,
                    status: detail.status.rawValue,
                    error: detail.error,
                    versionIssues: detail.versionIssues.isEmpty ? nil : detail.versionIssues,
                    launchLog: detail.launchLog
                )
            }
        )
    }

    private func printReport(_ report: TunTestReport) {
        print("\n=== TUN Config Generation Test Summary ===")
        print("Total:    \(report.summary.total)")
        print("Passed:   \(report.summary.passed)")
        print("Advisory: \(report.summary.advisory)")
        print("Skipped:  \(report.summary.skipped)")
        print("Launch:   \(report.summary.launchFailed)")
        print("Config:   \(report.summary.configErrors)")
        print("Issues:   \(report.summary.versionIssueCount)")
        print("==========================================\n")

        for detail in report.details {
            if detail.status != "pass" {
                print("  [\(detail.status)] \(detail.version): \(detail.error ?? detail.versionIssues?.joined(separator: "; ") ?? "")")
            }
        }
    }

    private func writeReport(_ report: TunTestReport, suffix: String) throws {
        let reportDir = CompatibilityTestConfig.reportDir
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd_HHmmss"
        let ts = df.string(from: Date())
        let path = "\(reportDir)/tun-\(suffix)-report-\(ts).json"

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(report)
        let url = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
        print("Report: \(path)")
    }
}

// MARK: - Test result types

enum TunTestStatus: String, Codable {
    case pass
    case advisory
    case skipped
    case configError
    case launchFailed
}

struct TunTestResult {
    let version: String
    let binaryPath: String
    var status: TunTestStatus = .pass
    var error: String?
    var generatedConfig: String?
    var parsedConfig: SingboxStruct?
    var tunInbound: SingboxInbound?
    var versionIssues: [String] = []
    var launchLog: String?

    mutating func addVersionIssue(_ issue: String) {
        versionIssues.append(issue)
        print("  [ISSUE] \(version): \(issue)")
    }
}

struct TunTestReport: Codable {
    let generatedAt: String
    let environment: Environment
    let summary: Summary
    let details: [Detail]

    struct Environment: Codable {
        let arch: String
        let osVersion: String
        let singboxVersions: Int
    }

    struct Summary: Codable {
        let total: Int
        let passed: Int
        let advisory: Int
        let skipped: Int
        let launchFailed: Int
        let configErrors: Int
        let versionIssueCount: Int
    }

    struct Detail: Codable {
        let version: String
        let status: String
        let error: String?
        let versionIssues: [String]?
        let launchLog: String?
    }
}
