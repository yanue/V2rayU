import Foundation
import Network

actor TunHandler {
    static let shared = TunHandler()

    let tunHelperDaemon = "yanue.v2rayu.tun-helper"
    private var rebuildInProgress = false
    private var lastRebuildAt: Date?
    private let minRebuildInterval: TimeInterval = 8

    // MARK: - Start

    func start() async -> Bool {
        stop()
        do {
            let jsonText = TunConfigHandler.buildTunConfig()
            try jsonText.write(to: URL(fileURLWithPath: TunConfigFilePath), atomically: true, encoding: .utf8)
            logger.info("create tun config ok, path: \(TunConfigFilePath)")
        } catch {
            logger.error("Failed to write tun JSON file: \(error)")
            return false
        }
        return await startDaemon()
    }

    private func startDaemon() async -> Bool {
        do {
            let output = try runCommand(at: "/usr/bin/sudo", with: ["-n", "/bin/launchctl", "start", tunHelperDaemon])
            logger.info("startTunHelper done: \(output)")
        } catch let error {
            logger.info("startTunHelper failed: \(error), trigger install")
            await AppInstaller.shared.forceInstall(reason: "startTunHelper failed: \(error)")
            do {
                let output = try runCommand(at: "/usr/bin/sudo", with: ["-n", "/bin/launchctl", "start", tunHelperDaemon])
                logger.info("startTunHelper retry done: \(output)")
            } catch {
                logger.info("startTunHelper retry failed: \(error)")
                return false
            }
        }

        guard await waitForDaemonRunning() else {
            logger.error("startTunHelper: process not found after launchctl start")
            return false
        }
        logger.info("startTunHelper: process confirmed running")
        return true
    }

    // MARK: - Stop

    func stop() {
        guard isDaemonRunning() else {
            logger.info("stopTunHelper: not running, skip")
            return
        }
        do {
            _ = try runCommand(at: "/usr/bin/sudo", with: ["-n", "/bin/launchctl", "stop", tunHelperDaemon])
            logger.info("stopTunHelper: sent stop, waiting for exit")
        } catch let error {
            if error.localizedDescription.contains("password is required") {
                logger.info("stopTunHelper skipped: sudo not configured, run install first")
                return
            } else {
                logger.info("stopTunHelper failed: \(error)")
            }
        }
        waitForDaemonExit()
        if isDaemonRunning() {
            logger.warning("stopTunHelper: process still running, sending SIGKILL")
            _ = shell(launchPath: "/usr/bin/sudo", arguments: ["-n", "/usr/bin/killall", "-9", "sing-box"])
        }
    }

    // MARK: - Daemon Status

    var isRunning: Bool {
        isDaemonRunning()
    }

    static func daemonPID(fromLaunchctlPrint output: String) -> Int? {
        for line in output.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.hasPrefix("pid =") else { continue }

            let value = trimmed
                .dropFirst("pid =".count)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if let pid = Int(value), pid > 0 {
                return pid
            }
        }
        return nil
    }

    private func daemonPID() -> Int? {
        guard let output = try? runCommand(
            at: "/bin/launchctl",
            with: ["print", "system/\(tunHelperDaemon)"]
        ) else {
            return nil
        }
        return Self.daemonPID(fromLaunchctlPrint: output)
    }

    private func isDaemonRunning() -> Bool {
        daemonPID() != nil
    }

    private func waitForDaemonRunning(timeout: TimeInterval = 8) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if isDaemonRunning() { return true }
            try? await Task.sleep(nanoseconds: 300_000_000)
        }
        return isDaemonRunning()
    }

    private func waitForDaemonExit(timeout: TimeInterval = 6) {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if !isDaemonRunning() { return }
            Thread.sleep(forTimeInterval: 0.2)
        }
    }

    // MARK: - Network Recovery

    func rebuildAfterNetworkChange(reason: String) async {
        if rebuildInProgress {
            logger.info("rebuildAfterNetworkChange skip: rebuild already in progress (\(reason))")
            return
        }
        if let lastRebuildAt = lastRebuildAt, Date().timeIntervalSince(lastRebuildAt) < minRebuildInterval {
            logger.info("rebuildAfterNetworkChange skip: too soon after previous rebuild (\(reason))")
            return
        }

        let (turnOn, mode) = await MainActor.run { (AppState.shared.v2rayTurnOn, AppState.shared.runMode) }
        guard turnOn else {
            logger.info("rebuildAfterNetworkChange skip: not running (\(reason))")
            return
        }

        rebuildInProgress = true
        defer { rebuildInProgress = false }

        logger.info("rebuildAfterNetworkChange: \(reason), stopping stale TUN before waiting for network...")
        stop()

        logger.info("rebuildAfterNetworkChange: \(reason), waiting for network...")
        let ready = await waitForNetworkReady()
        if !ready {
            logger.info("rebuildAfterNetworkChange: network not ready, proceeding with restart anyway (\(reason))")
        }

        if mode == .tun {
            guard UserDefaults.getBool(forKey: .tunAutoRebuild, default: true) else {
                logger.info("rebuildAfterNetworkChange skip: tunAutoRebuild disabled (\(reason))")
                return
            }
            // TUN 模式：重建 TUN（若核心已死会自动 fallback 到完整重启）
            logger.info("rebuildAfterNetworkChange: rebuilding TUN (\(reason))")
            let ok = await V2rayLaunch.shared.rebuildTun()
            if !ok {
                logger.warning("rebuildAfterNetworkChange: TUN rebuild failed (\(reason))")
                let msg = await MainActor.run { String(localized: .TunServiceStartFailed) }
                makeToast(message: msg, displayDuration: 4)
            }
        } else {
            let turnOnNow = await MainActor.run { AppState.shared.v2rayTurnOn }
            guard turnOnNow else {
                logger.info("rebuildAfterNetworkChange skip: v2rayTurnOn became false (\(reason))")
                return
            }
            // 非 TUN 模式：核心的 TCP 连接会因网卡切换而断开，需重启核心重建连接
            logger.info("rebuildAfterNetworkChange: restarting core for non-TUN mode (\(reason))")
            await V2rayLaunch.shared.restart()
        }
        lastRebuildAt = Date()

        // 重建后刷新 UI 状态
        await MainActor.run {
            if AppState.shared.runningCombination.isEmpty,
               let running = ProfileStore.shared.getRunning() {
                AppState.shared.runningServer = running
            }
            AppMenuManager.shared.refreshAllMenus()
        }
        // 重新 ping 更新延迟显示
        await PingAll.shared.run()
    }

    // MARK: - Network Readiness

    private func currentDefaultRoute() -> (gateway: String?, interface: String?) {
        do {
            let output = try runCommand(at: "/sbin/route", with: ["-n", "get", "default"])
            var gateway: String?
            var interface: String?
            for line in output.components(separatedBy: .newlines) {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.hasPrefix("gateway:") {
                    gateway = trimmed.replacingOccurrences(of: "gateway:", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                } else if trimmed.hasPrefix("interface:") {
                    interface = trimmed.replacingOccurrences(of: "interface:", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
            return (gateway, interface)
        } catch {
            logger.info("currentDefaultRoute failed: \(error)")
            return (nil, nil)
        }
    }

    private func hasPhysicalDefaultRoute() -> Bool {
        let route = currentDefaultRoute()
        guard let interface = route.interface, !interface.isEmpty else { return false }
        if interface.hasPrefix("utun") || interface == "lo0" || interface.hasPrefix("lo") {
            logger.info("physical route not ready: default interface=\(interface), gateway=\(route.gateway ?? "")")
            return false
        }
        logger.info("physical route ready: interface=\(interface), gateway=\(route.gateway ?? "")")
        return true
    }

    func waitForNetworkReady(timeout: TimeInterval = 15) async -> Bool {
        let ready = await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            let monitor = NWPathMonitor()
            let flag = ResumeFlag()
            monitor.pathUpdateHandler = { path in
                if path.status == .satisfied {
                    Task {
                        await flag.tryResumeBool(cont, result: true)
                        monitor.cancel()
                    }
                }
            }
            monitor.start(queue: DispatchQueue(label: "net.yanue.V2rayU.tunNetworkReady"))
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
                Task {
                    await flag.tryResumeBool(cont, result: false)
                    monitor.cancel()
                }
            }
        }
        guard ready else { return false }

        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if hasPhysicalDefaultRoute() {
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                return hasPhysicalDefaultRoute()
            }
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
        return false
    }
}
