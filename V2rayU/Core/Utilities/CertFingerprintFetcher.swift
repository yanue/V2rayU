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

        guard let output = shell(launchPath: xrayCoreFile, arguments: args), !output.isEmpty else {
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
}

/// 在启动/测试前，按需自动获取并持久化证书指纹；失败则原样返回（由兼容判定回退到 Sing-Box）。
enum CertPinningCoordinator {
    /// 若该节点需要 pinnedPeerCertSha256 且尚未拥有，则自动获取一次。返回可能已更新指纹的 entity。
    static func ensurePinnedCert(for profile: ProfileEntity) async -> ProfileEntity {
        guard shouldFetch(profile) else { return profile }

        let host = profile.address
        let port = profile.port
        let sni = profile.sni
        // shell 是同步阻塞调用，放到 detached 任务里避免阻塞调用方（actor）。
        let hex = await Task.detached(priority: .userInitiated) {
            CertFingerprintFetcher.fetchLeafSha256(host: host, port: port, sni: sni)
        }.value

        guard let hex, !hex.isEmpty else {
            logger.warning("ensurePinnedCert: 获取证书指纹失败 -> \(profile.remark)，将回退 Sing-Box")
            return profile
        }

        ProfileStore.shared.updatePinnedCert(uuid: profile.uuid, pin: hex)
        var updated = profile
        updated.pinnedPeerCertSha256 = hex
        logger.info("ensurePinnedCert: \(profile.remark) leaf sha256=\(hex)")
        return updated
    }

    /// 批量：用于组合配置场景。
    static func ensurePinnedCerts(for profiles: [ProfileEntity]) async {
        for profile in profiles {
            _ = await ensurePinnedCert(for: profile)
        }
    }

    private static func shouldFetch(_ p: ProfileEntity) -> Bool {
        guard p.security == .tls, p.allowInsecure else { return false }
        // Hysteria2 走 QUIC，无法用 TCP tls ping 取证书；交由兼容判定回退 Sing-Box。
        guard p.protocol != .hysteria2 else { return false }
        // 已强制使用 Sing-Box 的节点无需 pin。
        guard p.resolvedCoreSelection != .singbox else { return false }
        // 已有指纹则跳过。
        guard p.pinnedPeerCertSha256.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        // 仅当前核心确实已移除 allowInsecure 时才需要获取。
        guard xrayRequiresPinnedCert() else { return false }
        return true
    }
}
