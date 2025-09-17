//
//  SleepManager.swift
//  V2rayU
//
//  Created by yanue on 2025/8/27.
//

import Cocoa

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
    
    private func handleSystemWillSleep() {
        // 系统即将睡眠时的处理逻辑
        // 例如：保存数据、关闭连接、暂停任务等
    }
    
    private func handleSystemDidWake() {
        // 系统唤醒后的处理逻辑
        // 例如：重新建立连接、恢复任务、刷新数据等
        logger.info("onWakeNote")
        if UserDefaults.getBool(forKey: .v2rayTurnOn) {
            logger.info("V2rayLaunch restart")
            Task {
               await V2rayLaunch.shared.restart()
            }
        }
        if UserDefaults.getBool(forKey: .autoCheckVersion) {
            // 自动检查更新
//            V2rayUpdater.checkForUpdates()
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
    
    deinit {
        // 移除通知观察者
        NotificationCenter.default.removeObserver(self)
    }
}
