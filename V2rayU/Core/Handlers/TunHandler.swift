import Foundation
import Network

actor TunHandler {
    static let shared = TunHandler()

    let tunHelperDaemon = "yanue.v2rayu.tun-helper"
    private var rebuildInProgress = false
    private var lastRebuildAt: Date?
    private let minRebuildInterval: TimeInterval = 8
    /// 被去抖/并发跳过的网络变化不能直接丢弃: xray 出站绑定了物理网卡名（TUN 模式）,
    /// 丢弃会导致一直绑在已失效的旧网卡上。改为延后补做一次。
    private var deferredRebuild: Task<Void, Never>?
    private var rebuildRequestedDuringRun = false

    /// tun-helper 存活检测: LaunchDaemon 为 KeepAlive=false, 意外退出后无人拉起,
    /// 表现为 UI 显示 TUN 运行而流量不再走代理。仅在 start 成功后到 stop 之间运行。
    private var watchdogTask: Task<Void, Never>?
    private let watchdogInterval: TimeInterval = 5
    /// 短时间内反复退出视为无法恢复, 停止重试并关闭代理, 避免无限重启
    private var recoveryTimes: [Date] = []
    /// 代理核心 SOCKS 端口连续不可达的检测次数。需连续 2 次（≥5s）才判定退出,
    /// 避免切换服务器等主动重启核心的几秒内误判。
    private var coreUnreachableTicks = 0
    /// 每次开启/停止检测递增; 已取消的旧检测任务在 await 之后恢复执行时据此退出
    private var watchdogGeneration = 0
    /// 每隔若干次存活检测做一次网页登录检测（约 60s）: 发现登录过期等情况时暂停 TUN
    private var captiveTick = 0
    private let captiveCheckEveryTicks = 12
    private let maxRecoveries = 3
    private let recoveryWindow: TimeInterval = 120

    // MARK: - Start

    func start() async -> Bool {
        await stop()
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
        startWatchdog()
        return true
    }

    // MARK: - Stop

    func stop() async {
        // 主动停止（模式切换/睡眠/重建/退出）前先停检测, 避免误判为意外退出
        stopWatchdog()
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
        await waitForDaemonExit()
        if isDaemonRunning() {
            logger.warning("stopTunHelper: process still running, sending SIGKILL via launchctl")
            do {
                _ = try runCommand(at: "/usr/bin/sudo", with: ["-n", "/bin/launchctl", "kill", "SIGKILL", "system/\(tunHelperDaemon)"])
                await waitForDaemonExit()
            } catch {
                logger.info("stopTunHelper: launchctl kill failed: \(error)")
            }
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

    private func waitForDaemonExit(timeout: TimeInterval = 6) async {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if !isDaemonRunning() { return }
            try? await Task.sleep(nanoseconds: 200_000_000)
        }
    }

    // MARK: - Watchdog

    private func startWatchdog() {
        coreUnreachableTicks = 0
        captiveTick = 0
        watchdogTask?.cancel()
        watchdogGeneration += 1
        let generation = watchdogGeneration
        watchdogTask = Task { [watchdogInterval] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(watchdogInterval * 1_000_000_000))
                if Task.isCancelled { return }
                if await self.checkHealth(generation: generation) { return }
            }
        }
    }

    private func stopWatchdog() {
        watchdogTask?.cancel()
        watchdogTask = nil
        watchdogGeneration += 1
    }

    /// 检测任务仍是当前这一轮, 且没有重建在进行
    private func isCurrentWatchdog(_ generation: Int) -> Bool {
        generation == watchdogGeneration && watchdogTask != nil && !rebuildInProgress
    }

    private func resetRecoveryHistory() {
        recoveryTimes = []
    }

    /// 检查 tun-helper 与代理核心是否存活。
    /// 核心退出后 TUN 仍在, 但流量转给不存在的 SOCKS 端口, 同样表现为全部断网。
    /// 返回 true 表示检测到意外退出并已触发恢复（检测循环随之结束, 恢复成功后由 start 重新开启）
    private func checkHealth(generation: Int) async -> Bool {
        guard isCurrentWatchdog(generation) else { return false }
        captiveTick += 1
        if captiveTick >= captiveCheckEveryTicks, isDaemonRunning() {
            captiveTick = 0
            if await CaptivePortal.loginRequired(), isCurrentWatchdog(generation) {
                watchdogTask = nil
                Task.detached { await V2rayLaunch.shared.pauseTunForCaptivePortal() }
                return true
            }
        }
        let what: String
        if isDaemonRunning() {
            // 切换服务器/路由等主动重载核心期间端口会短暂不可达, 不计入
            if await V2rayLaunch.shared.isBusy {
                coreUnreachableTicks = 0
                return false
            }
            let coreAlive = await TCPConnectivity.canConnect(host: "127.0.0.1", port: getEffectiveSocksProxyPort(), timeout: 1)
            coreUnreachableTicks = coreAlive ? 0 : coreUnreachableTicks + 1
            guard coreUnreachableTicks >= 2, isCurrentWatchdog(generation), !(await V2rayLaunch.shared.isBusy) else { return false }
            what = "proxy core"
        } else {
            // 二次确认, 排除 launchctl 状态瞬时抖动
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            guard isCurrentWatchdog(generation), !isDaemonRunning() else { return false }
            what = "tun-helper"
        }
        let (turnOn, mode) = await MainActor.run { (AppState.shared.v2rayTurnOn, AppState.shared.runMode) }
        guard turnOn, mode == .tun else {
            stopWatchdog()
            return true
        }

        watchdogTask = nil
        let now = Date()
        recoveryTimes = recoveryTimes.filter { now.timeIntervalSince($0) < recoveryWindow } + [now]
        let attempt = recoveryTimes.count
        // 恢复放到独立任务: 恢复过程会 stop() 本检测任务, 若在被取消的任务里执行, 其中的 sleep 会立即返回
        Task.detached { [maxRecoveries, recoveryWindow] in
            if attempt > maxRecoveries {
                logger.error("\(what) exited \(attempt) times within \(Int(recoveryWindow))s, giving up and stopping")
                await TunHandler.shared.resetRecoveryHistory()
                await V2rayLaunch.shared.stop()
                let msg = await MainActor.run { String(localized: .TunHelperExitedStopped) }
                makeToast(message: msg, displayDuration: 6)
                return
            }
            logger.warning("\(what) exited unexpectedly, recovering (attempt \(attempt)/\(maxRecoveries))")
            // 网络未变化, 不需要重新生成 xray 配置; 核心已退出时 rebuildTun 会自动完整重启
            let ok = await V2rayLaunch.shared.rebuildTun(reloadXray: false)
            logger.info("\(what) recovery done: \(ok)")
            if !ok {
                // 重建失败（TUN 未起来）: 重新开启检测, 下次检测会再次尝试, 直至超过次数上限后停止
                await TunHandler.shared.restartWatchdogAfterFailedRecovery()
            }
        }
        return true
    }

    private func restartWatchdogAfterFailedRecovery() {
        startWatchdog()
    }

    // MARK: - Network Recovery

    func rebuildAfterNetworkChange(reason: String) async {
        if rebuildInProgress {
            logger.info("rebuildAfterNetworkChange: rebuild in progress, will rebuild again afterwards (\(reason))")
            rebuildRequestedDuringRun = true
            return
        }
        if let lastRebuildAt = lastRebuildAt, Date().timeIntervalSince(lastRebuildAt) < minRebuildInterval {
            let delay = minRebuildInterval - Date().timeIntervalSince(lastRebuildAt)
            logger.info("rebuildAfterNetworkChange: too soon after previous rebuild, deferred \(Int(delay.rounded(.up)))s (\(reason))")
            deferRebuild(after: delay, reason: reason)
            return
        }
        deferredRebuild?.cancel()
        deferredRebuild = nil

        let (turnOn, mode) = await MainActor.run { (AppState.shared.v2rayTurnOn, AppState.shared.runMode) }
        guard turnOn else {
            logger.info("rebuildAfterNetworkChange skip: not running (\(reason))")
            return
        }

        rebuildInProgress = true
        rebuildRequestedDuringRun = false
        defer {
            rebuildInProgress = false
            if rebuildRequestedDuringRun {
                rebuildRequestedDuringRun = false
                deferRebuild(after: minRebuildInterval, reason: "network changed during rebuild")
            }
        }

        logger.info("rebuildAfterNetworkChange: \(reason), stopping stale TUN before waiting for network...")
        await stop()

        logger.info("rebuildAfterNetworkChange: \(reason), waiting for network...")
        let ready = await waitForNetworkReady()
        if !ready {
            logger.info("rebuildAfterNetworkChange: network not ready, proceeding with restart anyway (\(reason))")
        }

        if mode == .tun {
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

    private func deferRebuild(after delay: TimeInterval, reason: String) {
        deferredRebuild?.cancel()
        deferredRebuild = Task {
            try? await Task.sleep(nanoseconds: UInt64(max(delay, 0.5) * 1_000_000_000))
            if Task.isCancelled { return }
            await self.runDeferredRebuild(reason: reason)
        }
    }

    /// 先清掉自身引用再进入重建: rebuildAfterNetworkChange 会取消 deferredRebuild,
    /// 若仍指向当前任务会把自己取消, 之后所有 sleep 立即返回, 等待循环空转。
    private func runDeferredRebuild(reason: String) async {
        deferredRebuild = nil
        await rebuildAfterNetworkChange(reason: "deferred: \(reason)")
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
        // 两个阶段共用同一截止时间（最长 timeout, 而非 2×timeout）
        let deadline = Date().addingTimeInterval(timeout)
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
