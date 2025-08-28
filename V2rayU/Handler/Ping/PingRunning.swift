//
//  PingRunning.swift
//  V2rayU
//
//  Created by yanue on 2024/12/27.
//

import Foundation

actor PingRunning {
    static let shared = PingRunning()
    
    private let maxRetries = 3
    private let maxFailures = 3
    
    private var failureCount = 0
    private var isExecuting = false
    private var item: ProfileModel = ProfileModel()

    /// 开始 Ping 流程
    func startPing(item: ProfileModel) async throws {
        guard !isExecuting else {
            logger.info("Ping task is already running.")
            return
        }
        NotificationCenter.default.post(name: NOTIFY_UPDATE_Ping, object: "开始单节点 Ping: \(item.remark)")
        // 睡眠
        try await Task.sleep(nanoseconds: 2 * 1_000_000_000) // Wait for 2 seconds
        // 替换
        self.item = item
        // 控制
        isExecuting = true
        defer { isExecuting = false }

        var retries = 0
        var success = false
        let ping = Ping()
        let port = getHttpProxyPort()
        while retries < maxRetries && !success {
            do {
                let pingTime = try await ping.doPing(bindPort: port)
                logger.info("Ping success, time: \(pingTime)ms")
                NotificationCenter.default.post(name: NOTIFY_UPDATE_Ping, object: "Ping 成功: \(item.remark) - \(pingTime)ms")
                resetFailureCount()
                success = true
            } catch {
                retries += 1
                NotificationCenter.default.post(name: NOTIFY_UPDATE_Ping, object: "Ping 失败: \(item.remark) - 第\(retries)次: \(error.localizedDescription)")
                logger.info("Ping failed (\(retries)/\(maxRetries)): \(error)")
            }
        }

        if !success {
            await handleFailure()
        } else {
            NotificationCenter.default.post(name: NOTIFY_UPDATE_Ping, object: "完成单节点 Ping: \(item.remark)")
        }
    }

    private func updateSpeed(pingTime: Int) {
        // 更新 speed
        ProfileViewModel.update_speed(uuid: self.item.uuid, speed: pingTime)
    }
    
    /// 重置失败计数
    private func resetFailureCount() {
        failureCount = 0
    }

    /// 处理失败逻辑
    private func handleFailure() async {
        // 更新 ping 结果
        self.updateSpeed(pingTime: -1)
        failureCount += 1
        if failureCount >= maxFailures {
            failureCount = 0
            logger.info("Ping failed \(maxFailures) times, switching to backup...")
            await switchServer()
        }
    }

    /// 切换到备用服务器
    private func switchServer() async {
        // 实现切换逻辑，比如更新 AppState.shared.pingURL 或其他参数
        await chooseNewServer(uuid: self.item.uuid)
    }
}

func chooseNewServer(uuid: String) async {
    guard UserDefaults.getBool(forKey: .autoSelectFastestServer) else {
        logger.info(" - choose new server: disabled")
        return
    }
    
    let serverList = ProfileViewModel.all()
    guard serverList.count > 1 else {
        return
    }

    var pingedSvrs = [String: Int]()
    var allSvrs = [String]()
    
    for svr in serverList where svr.uuid !=  uuid {
        allSvrs.append(svr.uuid)
        if svr.speed != -1 {
            pingedSvrs[svr.uuid] = svr.speed
        }
    }

    let newSvrName: String
    if let fastestSvr = pingedSvrs.sorted(by: { $0.value < $1.value }).first {
        newSvrName = fastestSvr.key
    } else if let randomSvr = allSvrs.randomElement() {
        newSvrName = randomSvr
    } else {
        return
    }

    logger.info(" - choose new server: \(newSvrName)")
    UserDefaults.set(forKey: .runningProfile, value: newSvrName)
    V2rayLaunch.restartV2ray()
}
