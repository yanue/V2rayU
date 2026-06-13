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
        if UserDefaults.getBool(forKey: .v2rayTurnOn) {
            logger.info("V2rayLaunch rebuild after wake")
            Task {
                // 不直接 restart: 唤醒瞬间 Wi-Fi 仍在重连/DHCP, 过早重启会导致接口探测失败。
                // rebuildAfterNetworkChange 内部会等待物理网络就绪后再重建(TUN 模式),
                // 非 TUN 模式则回退为普通重启。
                let mode = await MainActor.run { AppState.shared.runMode }
                if mode == .tun {
                    await TunHandler.shared.rebuildAfterNetworkChange(reason: "system wake")
                } else {
                    await V2rayLaunch.shared.restart()
                }
            }
        }
        if UserDefaults.getBool(forKey: .autoCheckVersion) {
            // 自动检查更新
            Task {
                await AppMenuManager.shared.versionController.checkForUpdates(showWindow: false)
            }
        }
        if UserDefaults.getBool(forKey: .autoUpdateServers) {
            // 自动更新订阅服务器
            Task{
                await SubscriptionHandler.shared.sync()
            }
        }
        // ping
        Task {
            await PingAll.shared.run()
        }
    }
}
