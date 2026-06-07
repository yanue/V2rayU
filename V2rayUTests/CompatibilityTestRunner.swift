import Foundation
import Testing
@testable import V2rayU

@Suite struct CompatibilityTestRunner {

    private let configHandler = CoreConfigHandler()

    @Test("Run full compatibility test matrix")
    func runCompatibilityTest() {
        let testConfig = readTestConfig()
        let xrayVersions = CompatibilityTestConfig.xrayVersions
        let singboxVersions = CompatibilityTestConfig.singboxVersions

        guard !xrayVersions.isEmpty || !singboxVersions.isEmpty else {
            print("SKIP: No test binaries found")
            return
        }

        let profiles = ProfileStore.shared.fetchAll()
        guard !profiles.isEmpty else {
            print("SKIP: No profiles found in database")
            return
        }

        let limitedProfiles = testConfig.maxProfiles > 0
            ? Array(profiles.prefix(testConfig.maxProfiles))
            : profiles
        let sampledXray = testConfig.sampleVersions > 0
            ? sample(from: xrayVersions, count: testConfig.sampleVersions)
            : xrayVersions
        let sampledSingbox = testConfig.sampleVersions > 0
            ? sample(from: singboxVersions, count: testConfig.sampleVersions)
            : singboxVersions

        let totalCombos = limitedProfiles.count * (sampledXray.count + sampledSingbox.count)
        print("=== Compatibility Test ===")
        print("Profiles: \(limitedProfiles.count) (config.max=\(testConfig.maxProfiles))")
        print("Xray versions: \(sampledXray.count) (total=\(xrayVersions.count), sample=\(testConfig.sampleVersions))")
        print("Sing-box versions: \(sampledSingbox.count) (total=\(singboxVersions.count), sample=\(testConfig.sampleVersions))")
        print("Total combinations: \(totalCombos)")

        var allResults: [ProfileTestResult] = []

        for profile in limitedProfiles {
            for version in sampledXray {
                let r = testSingleCombination(profile: profile, coreType: .XrayCore, version: version)
                allResults.append(r)
            }
            for version in sampledSingbox {
                let r = testSingleCombination(profile: profile, coreType: .SingBox, version: version)
                allResults.append(r)
            }
        }

        let report = CompatibilityReportGenerator.generate(from: allResults)
        do {
            try CompatibilityReportGenerator.writeReport(report, to: CompatibilityTestConfig.reportPath)
        } catch {
            print("ERROR: Failed to write report: \(error)")
        }

        print("\n=== Compatibility Test Summary ===")
        print("Total:    \(report.summary.totalCombinations)")
        print("Passed:   \(report.summary.passed)")
        print("Failed:   \(report.summary.failed)")
        print("Skipped:  \(report.summary.skipped)")
        print("Launch:   \(report.summary.launchFailed)")
        print("Config:   \(report.summary.configErrors)")
        print("Mismatches: \(report.summary.ruleMismatchCount)")
        print("Report:   \(CompatibilityTestConfig.reportPath)")
        print("==================================\n")

        if !report.ruleMismatches.isEmpty {
            print("WARNING: \(report.ruleMismatches.count) rule mismatches found!")
            for mm in report.ruleMismatches.prefix(10) {
                print("  - [\(mm.coreType) \(mm.coreVersion)] \(mm.profileRemark): " +
                      "predicted=\(mm.rulePredicted), actual=\(mm.actualStatus)")
            }
        }
    }

    private func testSingleCombination(
        profile: ProfileEntity,
        coreType: CoreType,
        version: String
    ) -> ProfileTestResult {
        let binaryPath = CompatibilityTestConfig.binaryPath(core: coreType, version: version)

        guard FileManager.default.isExecutableFile(atPath: binaryPath) else {
            return ProfileTestResult(
                profileUUID: profile.uuid,
                profileRemark: profile.remark,
                protocolRaw: profile.protocol.rawValue,
                networkRaw: profile.network.rawValue,
                securityRaw: profile.security.rawValue,
                coreTypeRaw: coreType.rawValue,
                coreVersion: version,
                connection: ConnectionTestDetail(
                    status: .skipped,
                    latencyMs: nil,
                    error: "Binary not found: \(binaryPath)",
                    rulePrediction: "unknown",
                    ruleMatched: true
                )
            )
        }

        let rulePrediction = predictCapability(profile: profile, coreType: coreType, version: version)

        if rulePrediction == "unsupported" {
            return ProfileTestResult(
                profileUUID: profile.uuid,
                profileRemark: profile.remark,
                protocolRaw: profile.protocol.rawValue,
                networkRaw: profile.network.rawValue,
                securityRaw: profile.security.rawValue,
                coreTypeRaw: coreType.rawValue,
                coreVersion: version,
                connection: ConnectionTestDetail(
                    status: .skipped,
                    latencyMs: nil,
                    error: nil,
                    rulePrediction: rulePrediction,
                    ruleMatched: true
                )
            )
        }

        let bindPort = getRandomPort()

        print("  Testing \(profile.remark) on port \(bindPort)...")
        var testProfile = profile
        testProfile.coreType = coreType == .XrayCore ? .xray : .singbox
        let jsonText = configHandler.toJSON(item: testProfile, httpPort: String(bindPort), apiPort: nil)
        print("  JSON generated (\(jsonText.count) chars)")

        return launchAndTest(
            profile: profile,
            coreType: coreType,
            version: version,
            binaryPath: binaryPath,
            bindPort: bindPort,
            jsonText: jsonText,
            rulePrediction: rulePrediction
        )
    }

    private func launchAndTest(
        profile: ProfileEntity,
        coreType: CoreType,
        version: String,
        binaryPath: String,
        bindPort: UInt16,
        jsonText: String,
        rulePrediction: String
    ) -> ProfileTestResult {
        let configFile = "\(AppHomePath)/.compat-test.\(profile.uuid).\(coreType.rawValue).\(version).json"

        do {
            try jsonText.write(to: URL(fileURLWithPath: configFile), atomically: true, encoding: .utf8)
        } catch {
            return ProfileTestResult(
                profileUUID: profile.uuid, profileRemark: profile.remark,
                protocolRaw: profile.protocol.rawValue, networkRaw: profile.network.rawValue,
                securityRaw: profile.security.rawValue, coreTypeRaw: coreType.rawValue,
                coreVersion: version,
                connection: ConnectionTestDetail(status: .configError, latencyMs: nil,
                    error: "Write config failed: \(error.localizedDescription)",
                    rulePrediction: rulePrediction, ruleMatched: false))
        }

        let process = Process()
        process.launchPath = "/bin/bash"
        process.arguments = ["-c", "cd \(AppHomePath) && \(binaryPath) run -c \(configFile)"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            try? FileManager.default.removeItem(atPath: configFile)
            return ProfileTestResult(
                profileUUID: profile.uuid, profileRemark: profile.remark,
                protocolRaw: profile.protocol.rawValue, networkRaw: profile.network.rawValue,
                securityRaw: profile.security.rawValue, coreTypeRaw: coreType.rawValue,
                coreVersion: version,
                connection: ConnectionTestDetail(status: .launchFailed, latencyMs: nil,
                    error: "Launch failed: \(error.localizedDescription)",
                    rulePrediction: rulePrediction, ruleMatched: false))
        }

        defer {
            if process.isRunning {
                let pid = process.processIdentifier
                process.interrupt()
                process.terminate()
                Thread.sleep(forTimeInterval: 0.3)
                if process.isRunning {
                    kill(pid, 9)
                }
                process.waitUntilExit()
            }
        }

        let portTimeout: TimeInterval = profile.network == .kcp ? 3 : 1
        let portReady = waitForPortSync(bindPort, timeout: portTimeout)

        let portReady = waitForPortSync(bindPort, timeout: portTimeout)
        guard portReady else {
            return ProfileTestResult(
                profileUUID: profile.uuid, profileRemark: profile.remark,
                protocolRaw: profile.protocol.rawValue, networkRaw: profile.network.rawValue,
                securityRaw: profile.security.rawValue, coreTypeRaw: coreType.rawValue,
                coreVersion: version,
                connection: ConnectionTestDetail(status: .timeout, latencyMs: nil,
                    error: "Port \(bindPort) not ready after \(Int(portTimeout))s",
                    rulePrediction: rulePrediction, ruleMatched: false))
        }

        do {
            let isKcp = profile.network == .kcp
            let latency = try testConnectivitySync(port: bindPort, isKcp: isKcp)
            let ruleMatched = (rulePrediction == "supported" || rulePrediction == "advisory")
            return ProfileTestResult(
                profileUUID: profile.uuid, profileRemark: profile.remark,
                protocolRaw: profile.protocol.rawValue, networkRaw: profile.network.rawValue,
                securityRaw: profile.security.rawValue, coreTypeRaw: coreType.rawValue,
                coreVersion: version,
                connection: ConnectionTestDetail(status: .pass, latencyMs: latency, error: nil,
                    rulePrediction: rulePrediction, ruleMatched: ruleMatched))
        } catch {
            let ruleMatched = (rulePrediction == "unsupported") || (rulePrediction == "unknown")
            return ProfileTestResult(
                profileUUID: profile.uuid, profileRemark: profile.remark,
                protocolRaw: profile.protocol.rawValue, networkRaw: profile.network.rawValue,
                securityRaw: profile.security.rawValue, coreTypeRaw: coreType.rawValue,
                coreVersion: version,
                connection: ConnectionTestDetail(status: .fail, latencyMs: nil,
                    error: "Connectivity test failed: \(error.localizedDescription)",
                    rulePrediction: rulePrediction, ruleMatched: ruleMatched))
        }
    }

    private func testConnectivitySync(port: UInt16, isKcp: Bool = false) throws -> Int {
        let process = Process()
        process.launchPath = "/usr/bin/curl"
        let connectTimeout = isKcp ? "3" : "1"
        let maxTime = isKcp ? "6" : "2"
        process.arguments = [
            "-x", "http://127.0.0.1:\(port)",
            "--connect-timeout", connectTimeout,
            "--max-time", maxTime,
            "-o", "/dev/null",
            "-s", "-w", "%{http_code}:%{time_total}",
            "https://www.gstatic.com/generate_204",
        ]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        let parts = output.split(separator: ":", maxSplits: 1)

        guard process.terminationStatus == 0,
              parts.count == 2,
              let httpCode = Int(parts[0]),
              (200..<400).contains(httpCode),
              let elapsed = Double(parts[1]) else {
            let detail = output.trimmingCharacters(in: .whitespacesAndNewlines).prefix(80)
            throw NSError(domain: "test", code: Int(process.terminationStatus),
                         userInfo: [NSLocalizedDescriptionKey: "curl failed (\(process.terminationStatus)): \(detail)"])
        }

        return max(1, Int(elapsed * 1000))
    }

    private func predictCapability(profile: ProfileEntity, coreType: CoreType, version: String) -> String {
        switch coreType {
        case .XrayCore:
            return predictXrayCapability(profile: profile, version: version)
        case .SingBox:
            return predictSingboxCapability(profile: profile, version: version)
        }
    }

    private func predictXrayCapability(profile: ProfileEntity, version: String) -> String {
        let xrayVersion = XrayVersion(version)
        var issues: [XrayCompatibilityIssue] = []
        if let def = XraySupportCatalog.definition(forOutbound: profile.protocol),
           let issue = XraySupportCatalog.evaluate(definition: def, version: xrayVersion) {
            issues.append(issue)
        }
        if let def = XraySupportCatalog.definition(forTransport: profile.network),
           let issue = XraySupportCatalog.evaluate(definition: def, version: xrayVersion) {
            issues.append(issue)
        }
        if let def = XraySupportCatalog.definition(forSecurity: profile.security),
           let issue = XraySupportCatalog.evaluate(definition: def, version: xrayVersion) {
            issues.append(issue)
        }
        if profile.security == .tls, profile.allowInsecure,
           let def = XraySupportCatalog.capability(forKey: "security.tls.allowInsecure"),
           let issue = XraySupportCatalog.evaluate(definition: def, version: xrayVersion) {
            issues.append(issue)
        }
        if issues.isEmpty { return "supported" }
        return issues.contains(where: \.isBlocking) ? "unsupported" : "advisory"
    }

    private func predictSingboxCapability(profile: ProfileEntity, version: String) -> String {
        let reasons = SingboxFallbackCompatibility.incompatibilityReasons(for: profile)
        if !reasons.isEmpty { return "unsupported" }
        if profile.protocol == .naive {
            guard let sv = SingboxVersion(version) else { return "advisory" }
            let minNaive = SingboxVersion(1, 13, 0)
            if sv < minNaive { return "unsupported" }
        }
        return "supported"
    }
}

private struct TestScopeConfig {
    let maxProfiles: Int
    let sampleVersions: Int
}

private func readTestConfig() -> TestScopeConfig {
    let env = ProcessInfo.processInfo.environment
    let configPaths: [String] = [
        env["PROJECT_DIR"].map { "\($0)/Build/tests/test-config.json" },
        "\(CompatibilityTestConfig.projectRoot)/Build/tests/test-config.json",
    ].compactMap { $0 }

    for path in configPaths {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Int] else {
            continue
        }
        return TestScopeConfig(
            maxProfiles: json["maxProfiles"] ?? 0,
            sampleVersions: json["sampleVersions"] ?? 0
        )
    }
    return TestScopeConfig(maxProfiles: 0, sampleVersions: 0)
}

private func sample<T>(from array: [T], count: Int) -> [T] {
    guard count > 0, array.count > count else { return array }
    if count == 1 { return [array[0]] }
    let step = Double(array.count - 1) / Double(count - 1)
    return (0..<count).map { array[Int(round(step * Double($0)))] }
}

private func waitForPortSync(_ port: UInt16, timeout: TimeInterval) -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    repeat {
        if isPortOpen(port) { return true }
        Thread.sleep(forTimeInterval: 0.2)
    } while Date() < deadline
    return false
}

private func isPortOpen(_ port: UInt16) -> Bool {
    let sock = socket(AF_INET, SOCK_STREAM, 0)
    guard sock >= 0 else { return false }
    defer { close(sock) }
    var addr = sockaddr_in()
    addr.sin_family = sa_family_t(AF_INET)
    addr.sin_port = CFSwapInt16HostToBig(port)
    addr.sin_addr.s_addr = inet_addr("127.0.0.1")
    let result = withUnsafePointer(to: &addr) {
        $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
            Darwin.connect(sock, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
        }
    }
    return result == 0
}
