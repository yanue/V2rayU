//
//  CertFingerprintFetcher.swift
//  V2rayU
//
//  自动获取服务器叶子证书指纹（pinnedPeerCertSha256），替代已被 Xray-core 26.1.31 移除的 allowInsecure。
//

import Foundation

/// 调用 `xray tls ping <host:port>` 获取叶子证书 SHA256（hex）。
/// `tls ping` 自 26.2.6 起会打印 "Cert's leaf SHA256:\t<hex>"，与 pinnedPeerCertSha256 接受的 hex 格式一致。
enum CertFingerprintFetcher {
    private static let fetchTimeout: TimeInterval = 3

    /// 返回叶子证书 SHA256（64 位小写 hex）；失败返回 nil。注意：走 TCP TLS 握手，不适用于 Hysteria2(QUIC)。
    static func fetchLeafSha256(host: String, port: Int, sni: String) -> String? {
        guard !host.isEmpty, port > 0 else { return nil }
        guard FileManager.default.fileExists(atPath: xrayCoreFile) else {
            logger.warning("CertFingerprintFetcher: xray binary not found at \(xrayCoreFile)")
            return nil
        }

        let serverName = sni.isEmpty ? host : sni
        var args = ["tls", "ping"]
        // tls ping 以参数域名做 SNI 握手；若 SNI 与实际连接地址不同，用 -ip 指定真实地址。
        if serverName != host {
            args += ["-ip", host]
        }
        args.append("\(serverName):\(port)")

        guard let output = runTLSCommand(arguments: args), !output.isEmpty else {
            return nil
        }
        return parseLeafSha256(from: output)
    }

    /// 从 `xray tls ping` 输出中解析叶子证书 SHA256。
    static func parseLeafSha256(from output: String) -> String? {
        for rawLine in output.split(whereSeparator: { $0 == "\n" || $0 == "\r" }) {
            let line = String(rawLine)
            guard let range = line.range(of: "leaf SHA256:") else { continue }
            let rest = line[range.upperBound...].trimmingCharacters(in: .whitespaces)
            let hex = rest.replacingOccurrences(of: ":", with: "").lowercased()
            if hex.count == 64, hex.allSatisfy({ $0.isHexDigit }) {
                return hex
            }
        }
        return nil
    }

    private static func runTLSCommand(arguments: [String]) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: xrayCoreFile)
        process.arguments = arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        let lock = NSLock()
        var timedOut = false

        do {
            try process.run()
        } catch {
            logger.error("CertFingerprintFetcher: failed to run xray tls ping: \(error)")
            return nil
        }

        let timeoutWork = DispatchWorkItem {
            lock.lock()
            timedOut = true
            lock.unlock()

            if process.isRunning {
                process.terminate()
                Thread.sleep(forTimeInterval: 0.2)
                if process.isRunning {
                    kill(process.processIdentifier, SIGKILL)
                }
            }
        }
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + fetchTimeout, execute: timeoutWork)

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        timeoutWork.cancel()

        lock.lock()
        let didTimeout = timedOut
        lock.unlock()

        if didTimeout {
            logger.warning("CertFingerprintFetcher: xray tls ping timed out after \(fetchTimeout)s")
            return nil
        }

        guard process.terminationStatus == 0 else {
            let output = String(data: data, encoding: .utf8) ?? ""
            logger.warning("CertFingerprintFetcher: xray tls ping failed: \(output)")
            return nil
        }

        return String(data: data, encoding: .utf8)
    }
}

/// 在启动/测试前，按需自动获取并持久化证书指纹；失败则原样返回（由兼容判定回退到 Sing-Box）。
enum CertPinningCoordinator {
    private static let refreshInterval: TimeInterval = 60 * 60

    struct Result {
        let profile: ProfileEntity
        let forceSingBox: Bool
    }

    /// 若该节点需要 pinnedPeerCertSha256，则自动获取/刷新一次。返回可能已更新指纹的 entity。
    static func ensurePinnedCert(for profile: ProfileEntity, refreshExisting: Bool = true) async -> ProfileEntity {
        await ensurePinnedCertResult(for: profile, refreshExisting: refreshExisting).profile
    }

    /// 若该节点的证书 pin 无法确认，返回一个本次运行强制 Sing-Box 的副本，避免 Xray 因旧 pin 熄火。
    static func ensurePinnedCertResult(for profile: ProfileEntity, refreshExisting: Bool = true) async -> Result {
        if shouldForceSingBoxWithoutFetch(profile) {
            return Result(profile: forceSingBox(profile, reason: "protocol cannot refresh pinnedPeerCertSha256"), forceSingBox: true)
        }

        guard shouldFetch(profile, refreshExisting: refreshExisting) else {
            return Result(profile: profile, forceSingBox: false)
        }

        let host = profile.address
        let port = profile.port
        let sni = profile.sni
        let oldPin = profile.pinnedPeerCertSha256.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        // shell 是同步阻塞调用，放到 detached 任务里避免阻塞调用方（actor）。
        let hex = await Task.detached(priority: .userInitiated) {
            CertFingerprintFetcher.fetchLeafSha256(host: host, port: port, sni: sni)
        }.value

        guard let hex, !hex.isEmpty else {
            logger.warning("ensurePinnedCert: 获取证书指纹失败 -> \(profile.remark)，本次回退 Sing-Box")
            return Result(profile: forceSingBox(profile, reason: "failed to refresh pinnedPeerCertSha256"), forceSingBox: true)
        }

        if hex == oldPin {
            logger.info("ensurePinnedCert: \(profile.remark) leaf sha256 unchanged")
            recordRefresh(uuid: profile.uuid)
            return Result(profile: profile, forceSingBox: false)
        }

        ProfileStore.shared.updatePinnedCert(uuid: profile.uuid, pin: hex)
        recordRefresh(uuid: profile.uuid)
        var updated = profile
        updated.pinnedPeerCertSha256 = hex
        let changeText = oldPin.isEmpty ? "obtained" : "refreshed"
        logger.info("ensurePinnedCert: \(profile.remark) \(changeText) leaf sha256=\(hex)")
        return Result(profile: updated, forceSingBox: false)
    }

    /// 批量：用于组合配置场景。
    static func ensurePinnedCerts(for profiles: [ProfileEntity], refreshExisting: Bool = true) async -> [Result] {
        await withTaskGroup(of: Result.self) { group in
            for profile in profiles {
                group.addTask {
                    await ensurePinnedCertResult(for: profile, refreshExisting: refreshExisting)
                }
            }

            var results: [Result] = []
            for await result in group {
                results.append(result)
            }
            return results
        }
    }

    private static func shouldForceSingBoxWithoutFetch(_ p: ProfileEntity) -> Bool {
        guard p.security == .tls, p.allowInsecure else { return false }
        guard xrayRequiresPinnedCert() else { return false }
        guard p.resolvedCoreSelection != .singbox else { return false }
        return p.protocol == .hysteria2
    }

    private static func shouldFetch(_ p: ProfileEntity, refreshExisting: Bool) -> Bool {
        guard p.security == .tls, p.allowInsecure else { return false }
        // Hysteria2 走 QUIC，无法用 TCP tls ping 取证书；已在 shouldForceSingBoxWithoutFetch 中提前回退。
        guard p.protocol != .hysteria2 else { return false }
        // 已强制使用 Sing-Box 的节点无需 pin。
        guard p.resolvedCoreSelection != .singbox else { return false }
        // 仅当前核心确实已移除 allowInsecure 时才需要获取。
        guard xrayRequiresPinnedCert() else { return false }
        let hasPin = !p.pinnedPeerCertSha256.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        guard hasPin else { return true }
        return refreshExisting && !isRefreshFresh(uuid: p.uuid)
    }

    private static func forceSingBox(_ profile: ProfileEntity, reason: String) -> ProfileEntity {
        var updated = profile
        updated.coreType = .singbox
        logger.warning("ensurePinnedCert: \(profile.remark) force Sing-Box for this run: \(reason)")
        return updated
    }

    private static func isRefreshFresh(uuid: String) -> Bool {
        let timestamps = refreshTimestamps()
        guard let timestamp = timestamps[uuid] else { return false }
        return Date().timeIntervalSince1970 - timestamp < refreshInterval
    }

    private static func recordRefresh(uuid: String) {
        var timestamps = refreshTimestamps()
        timestamps[uuid] = Date().timeIntervalSince1970

        guard let data = try? JSONEncoder().encode(timestamps),
              let text = String(data: data, encoding: .utf8) else {
            return
        }
        UserDefaults.set(forKey: .certPinRefreshTimestamps, value: text)
    }

    private static func refreshTimestamps() -> [String: TimeInterval] {
        let text = UserDefaults.get(forKey: .certPinRefreshTimestamps)
        guard let data = text.data(using: .utf8),
              let timestamps = try? JSONDecoder().decode([String: TimeInterval].self, from: data) else {
            return [:]
        }
        return timestamps
    }
}
