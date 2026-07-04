//
//  SleepManager.swift
//  V2rayU
//
//  Created by yanue on 2025/8/27.
//

import Cocoa
import AppCenterAnalytics

actor SystemSleepManager {
    static let shared = SystemSleepManager()
    
    public func setup() {
        // 监听系统即将睡眠的通知
        NotificationCenter.default.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { _ in
            logger.info("系统即将进入睡眠状态")
            // 在这里处理睡眠前的逻辑
            Task {
                await self.handleSystemWillSleep()
            }
        }
        
        // 监听系统唤醒的通知
        NotificationCenter.default.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { _ in
            logger.info("系统已唤醒")
            // 在这里处理唤醒后的逻辑
            Task {
                await self.handleSystemDidWake()
            }
        }
    }
    
    private func handleSystemWillSleep() async {
        // 系统即将睡眠时的处理逻辑
        // TUN 模式下主动停掉 tun-helper, 避免休眠期间 utun 设备 / 系统路由表残留为"脏"状态,
        // 唤醒后由 didWake 干净重建。
        let turnOn = UserDefaults.getBool(forKey: .v2rayTurnOn)
        let mode = UserDefaults.getEnum(forKey: .runMode, type: RunMode.self, defaultValue: .tun)
        if turnOn && mode == .tun {
            logger.info("willSleep: stop tun-helper to avoid stale route on wake")
            await TunHandler.shared.stop()
        }
    }
    
    private func handleSystemDidWake() {
        // 系统唤醒后的处理逻辑
        logger.info("onWakeNote")
        Task {
            // 1. 恢复网络连接（按模式选择策略）
            let turnOn = UserDefaults.getBool(forKey: .v2rayTurnOn)
            if turnOn {
                logger.info("V2rayLaunch rebuild after wake")
                let mode = await MainActor.run { AppState.shared.runMode }
                if mode == .tun {
                    await TunHandler.shared.rebuildAfterNetworkChange(reason: "system wake")
                } else {
                    await V2rayLaunch.shared.restart()
                }
            }

            // 2. 同步运行中服务器状态（runningServer 是内存态，需从 DB 刷新）
            if turnOn {
                await MainActor.run {
                    if AppState.shared.runningCombination.isEmpty,
                       let running = ProfileStore.shared.getRunning() {
                        AppState.shared.runningServer = running
                        if AppState.shared.runningProfile != running.uuid {
                            AppState.shared.runningProfile = running.uuid
                        }
                    }
                }
            }

            // 3. 刷新所有菜单 UI，确保选中状态一致
            await MainActor.run {
                AppMenuManager.shared.refreshAllMenus()
            }

            // 4. 后台任务
            if UserDefaults.getBool(forKey: .autoCheckVersion) {
                await AppMenuManager.shared.versionController.checkForUpdates(showWindow: false)
            }
            if UserDefaults.getBool(forKey: .autoUpdateServers) {
                await SubscriptionHandler.shared.sync()
            }
            await PingAll.shared.run()
        }
    }
}
