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

    /// 订阅更新周期上限: 365 天
    static let maxUpdateInterval = 365 * 86400

    /// 校正更新周期(秒): <=0 用默认 1 小时, 过大截到上限。
    /// 负数或过大的周期传给 DispatchSource.schedule 会直接崩溃(SIGTRAP), 数据库里存了异常值的用户每次启动都会崩
    static func normalizedInterval(_ seconds: Int) -> Int {
        seconds <= 0 ? 3600 : min(seconds, maxUpdateInterval)
    }

    // 启动或更新指定订阅的计时器
    func startOrUpdate(for sub: SubscriptionEntity) {
        // 若已存在且周期相同，保持；若不同，则重建
        let existing = timers[sub.uuid]
        let desiredInterval = TimeInterval(Self.normalizedInterval(sub.updateInterval))
        if let timer = existing {
            // 无法直接读取 schedule 参数，这里简化为重建，保证正确
            timer.cancel()
            timers[sub.uuid] = nil
        }

        let timer = DispatchSource.makeTimerSource(queue: .global(qos: .utility))
        timer.schedule(deadline: .now() + desiredInterval, repeating: desiredInterval)
        timer.setEventHandler { [uuid = sub.uuid] in
            Task {
                // 每次按 uuid 取最新的订阅：定时器里的副本是创建时的旧值（改过地址/备注后会用旧值同步），
                // 订阅已被删除时停掉定时器 (#1668)
                guard let sub = SubscriptionStore.shared.fetchOne(uuid: uuid) else {
                    await SubscriptionScheduler.shared.stop(for: uuid)
                    return
                }
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
