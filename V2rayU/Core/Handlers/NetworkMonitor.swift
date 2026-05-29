//
//  NetworkMonitor.swift
//  V2rayU
//
//  监听网络路径变化（切换 Wi-Fi / 插拔网线 / 网络中断恢复）。
//  TUN 模式下, 物理默认接口/网关变化会使 sing-box 已建立的路由失效 → 整体断网。
//  本监听器在网络变化后(去抖)触发 V2rayLaunch.rebuildAfterNetworkChange, 重建 TUN。
//

import Foundation
import Network

actor NetworkMonitor {
    static let shared = NetworkMonitor()

    private var monitor: NWPathMonitor?
    private var started = false

    // 基线: 用于判断"是否真的发生了变化", 避免首次/抖动误触发
    private var hasBaseline = false
    private var lastInterfaceKey = ""
    private var wasSatisfied = false

    // 去抖任务: 网络切换瞬间会有多次回调, 合并为一次重建
    private var debounceTask: Task<Void, Never>?

    func start() {
        guard !started else { return }
        started = true

        let m = NWPathMonitor()
        monitor = m
        m.pathUpdateHandler = { [weak self] path in
            // pathUpdateHandler 在专用队列回调, 转入 actor 串行处理
            Task { await self?.handlePath(path) }
        }
        m.start(queue: DispatchQueue(label: "net.yanue.V2rayU.networkMonitor"))
        logger.info("NetworkMonitor started")
    }

    func stop() {
        debounceTask?.cancel()
        debounceTask = nil
        monitor?.cancel()
        monitor = nil
        started = false
        hasBaseline = false
        wasSatisfied = false
        lastInterfaceKey = ""
    }

    private func handlePath(_ path: NWPath) {
        if path.status != .satisfied {
            // 网络中断中: 记录状态, 等待恢复后再处理
            wasSatisfied = false
            return
        }

        let key = Self.interfaceKey(path)

        // 首次建立基线, 不触发重建(避免启动即重启)
        if !hasBaseline {
            hasBaseline = true
            lastInterfaceKey = key
            wasSatisfied = true
            return
        }

        // 触发条件:
        //  1) 可用接口集合变化(如 Wi-Fi <-> 有线切换)
        //  2) 从"不可用"恢复到"可用"(如切换 Wi-Fi 热点: en0 先 down 再 up)
        //  3) 其他 satisfied 路径更新：同一 Wi-Fi 网卡(en0)切换 SSID/网关时，availableInterfaces
        //     可能不变，但默认路由已经变化。这里也去抖后交给 V2rayLaunch 做运行模式与时间窗口判断。
        let interfaceChanged = key != lastInterfaceKey
        let recovered = !wasSatisfied

        lastInterfaceKey = key
        wasSatisfied = true

        logger.info("NetworkMonitor: path update (interfaceChanged=\(interfaceChanged), recovered=\(recovered)), schedule rebuild probe")
        scheduleRebuild()
    }

    private func scheduleRebuild() {
        debounceTask?.cancel()
        debounceTask = Task {
            // 去抖: 等待网络切换的多次抖动平息
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            if Task.isCancelled { return }
            await V2rayLaunch.shared.rebuildAfterNetworkChange(reason: "network change")
        }
    }

    /// 用可用接口的 类型+名称 组合作为标识, 判断接口集合是否变化
    private static func interfaceKey(_ path: NWPath) -> String {
        path.availableInterfaces
            .map { "\($0.type):\($0.name)" }
            .sorted()
            .joined(separator: ",")
    }
}

