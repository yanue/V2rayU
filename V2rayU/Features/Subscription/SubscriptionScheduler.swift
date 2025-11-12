//
//  SubscriptionScheduler.swift
//  V2rayU
//
//  Created by yanue on 2025/11/8.
//
import Foundation
import Combine

actor SubscriptionScheduler {
    static let shared = SubscriptionScheduler()

    private var timers: [String: DispatchSourceTimer] = [:] // key: uuid
    private var cancellables: Set<AnyCancellable> = []
    
    func runAtStart() {
        Task {
            if await AppSettings.shared.autoUpdateServers {
                await SubscriptionHandler.shared.sync()
            }
            await SubscriptionScheduler.shared.refreshAll()
        }
    }
    
    // 全量刷新：根据 enable/interval 和全局开关做增删改
    func refreshAll() {
        Task {
            if await !AppSettings.shared.autoUpdateServers {
                // 全局关闭：停止所有计时器
                stopAll()
                return
            }
        }
        
        // 获取所有订阅
        let subs = SubscriptionStore.shared.fetchAll()

        // 目标集合：仅启用的, 如果周期<=0则设为3600秒
        let active = subs
            .filter { $0.enable }
            .map { sub -> SubscriptionEntity in
                var copy = sub
                if copy.updateInterval <= 0 {
                    copy.updateInterval = 3600
                }
                return copy
            }

        // 停掉已不在集合中的计时器
        let activeIds = Set(active.map { $0.uuid })
        for (uuid, _) in timers where !activeIds.contains(uuid) {
            stop(for: uuid)
        }

        // 对每个活跃项启动或更新
        for sub in active {
            startOrUpdate(for: sub)
        }
    }

    // 启动或更新指定订阅的计时器
    func startOrUpdate(for sub: SubscriptionEntity) {
        // 若已存在且周期相同，保持；若不同，则重建
        let existing = timers[sub.uuid]
        let desiredInterval = TimeInterval(sub.updateInterval)
        if let timer = existing {
            // 无法直接读取 schedule 参数，这里简化为重建，保证正确
            timer.cancel()
            timers[sub.uuid] = nil
        }

        let timer = DispatchSource.makeTimerSource(queue: .global(qos: .utility))
        timer.schedule(deadline: .now() + desiredInterval, repeating: desiredInterval)
        timer.setEventHandler { [sub] in
            Task {
                // 如果未启用，直接返回
                if !sub.enable {
                    return
                }
                // 再次检查全局开关，避免误触发
                if await AppSettings.shared.autoUpdateServers {
                    // 如果有针对单个订阅的同步方法，优先调用
                    await SubscriptionHandler.shared.syncOne(item: sub)
                }
            }
        }
        timer.resume()
        timers[sub.uuid] = timer
        logger.info("SubscriptionScheduler: Started timer for sub \(sub.uuid)-\(sub.remark)-\(sub.url) with interval \(desiredInterval) seconds")
    }

    // 停止指定订阅
    func stop(for uuid: String) {
        timers[uuid]?.cancel()
        timers[uuid] = nil
    }

    // 停止所有
    func stopAll() {
        for (uuid, timer) in timers {
            timer.cancel()
            timers[uuid] = nil
        }
    }
}
