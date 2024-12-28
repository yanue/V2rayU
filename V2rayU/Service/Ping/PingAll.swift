//
//  PingAll.swift
//  V2rayU
//
//  Created by yanue on 2024/12/27.
//

import Foundation
import Combine

actor PingAll {
    static var shared = PingAll()

    private(set) var inPing: Bool = false
    private let maxConcurrentTasks = 30
    private var cancellables = Set<AnyCancellable>()

    func run()  {
        guard !inPing else {
            NSLog("Ping is already running.")
            return
        }
        inPing = true
        
        killAllPing()

        let items = ProfileViewModel.all()
        guard !items.isEmpty else {
            NSLog("No items to ping.")
            return
        }

        NSLog("Ping started.")
        // 开始执行异步任务
        self.pingTaskGroup(items: items)
    }

    private func pingTaskGroup(items: [ProfileModel]) {
        // 使用 Combine 处理多个异步任务
        items.publisher.flatMap(maxPublishers: .max(self.maxConcurrentTasks)) { item in
            Future<Void, Error> { promise in
                Task {
                    do {
                        try await self.pingEachServer(item: item)
                        promise(.success(()))
                    } catch {
                        promise(.failure(error))
                    }
                }
            }
        }
        .collect()
        .sink(receiveCompletion: { completion in
            switch completion {
            case .finished:
                NSLog("All tasks completed")
            case let .failure(error):
                NSLog("Error: \(error)")
            }
            self.inPing = false
            killAllPing()
//            self.refreshMenu()
        }, receiveValue: { _ in })
        .store(in: &cancellables)
    }

    private func pingEachServer(item: ProfileModel) async throws {
        let ping = PingServer(uuid: item.uuid)
        try await ping.doPing()
    }
}

actor PingServer {
    private var uuid: String = ""
    private var item: ProfileModel = ProfileModel()
    private var process: Process = Process()
    private var jsonFile: String = ""
    private var bindPort: UInt16 = 0
    
    init(uuid: String)  {
        self.uuid = uuid
    }
    
    func doPing() async throws {
        // 必须初始化替换
        guard let item = ProfileViewModel.fetchOne(uuid: uuid) else {
            throw NSError(domain: "PingServerError", code: 404, userInfo: [NSLocalizedDescriptionKey: "Item not found"])
        }
        // 替换当前的 item
        self.item = item
        
        self.bindPort = getRandomPort()
        self.jsonFile = "\(AppHomePath)/.\(item.uuid).json"
        
        self.createV2rayJsonFileForPing()

        // 启动 v2ray 进程
        try await launchProcess()
        try await Task.sleep(nanoseconds: 2 * 1_000_000_000) // Wait for 2 seconds
        // ping
        try await ping()
        // 释放
        self.terminate()
    }

    private func ping() async throws {
        let ping = Ping()
        let pingTime = try await ping.doPing(bindPort: self.bindPort)
        print("Ping success, time: \(pingTime)ms")
        // 更新 speed
        ProfileViewModel.update_speed(uuid: self.item.uuid, speed: pingTime)
    }
    
    private func terminate() {
        NSLog("ping end: \(item.remark) - \(item.speed)")
        do {
            if self.process.isRunning {
                self.process.interrupt()
                self.process.terminate()
                self.process.waitUntilExit()
            }
            try FileManager.default.removeItem(at: URL(fileURLWithPath: jsonFile))
        } catch {
            NSLog("remove ping config error: \(error)")
        }
    }
    
    private func createV2rayJsonFileForPing() {
        let vCfg = V2rayConfigHandler()
        let jsonText = vCfg.toJSON(item: item, ping:true)
        do {
            try jsonText.write(to: URL(fileURLWithPath: jsonFile), atomically: true, encoding: .utf8)
        } catch {
            NSLog("Failed to write JSON file: \(error)")
        }
    }

    private func createProcess(command: String) -> Process {
        let process = Process()
        process.launchPath = "/bin/bash"
        process.arguments = ["-c", command]
        process.terminationHandler = { _process in
            if _process.terminationStatus != EXIT_SUCCESS {
                _process.terminate()
                _process.waitUntilExit()
            }
        }
        return process
    }

    private func launchProcess() async throws {
        let pingCmd = "cd \(AppHomePath) && ./v2ray-core/v2ray run -config \(jsonFile)"
        self.process = createProcess(command: pingCmd)
        self.process.launch()
    }
}

