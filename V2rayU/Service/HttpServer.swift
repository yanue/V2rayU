//
//  HttpServer.swift
//  V2rayU
//
//  Created by yanue on 2025/7/28.
//
import Cocoa
import FlyingFox

// 兼容旧调用
func startHttpServer() {
    Task {
        await LocalHttpServer.shared.start()
    }
}

actor LocalHttpServer {
    static let shared = LocalHttpServer()

    private var httpServer: HTTPServer?

    func start() async {
        // 停止已有服务
        await stop()
        let pacPort = getPacPort()
        if isPortOpen(port: pacPort) {
            var toast = "pac port \(pacPort) has been used, please replace from advance setting"
            var title = "Port is already in use"
            if isMainland {
                toast = "pac端口 \(pacPort) 已被使用, 请更换"
                title = "端口已被占用"
            }
            alertDialog(title: title, message: toast)
            DispatchQueue.main.async {
                showDock(state: true)
            }
            return
        }
        // only listens on localhost 8080
//        let server = HTTPServer(address: .loopback(port: 8080))
        let server = HTTPServer(address: .inet(port: UInt16(pacPort)))
        // 静态文件目录映射，subPath 用 URL 路径前缀，serverPath 用绝对路径
        print("AppHomePath",AppHomePath)
        await server.appendRoute("GET /*", to: .directory(subPath: "/", serverPath: AppHomePath))
        await server.appendRoute("GET /pac/*", to: .directory(subPath: "/pac", serverPath: AppHomePath + "/pac"))
        await server.appendRoute("GET /proxy.js", to: .file(named: AppHomePath + "/proxy.js"))
        await server.appendRoute("GET /config.json", to: .file(named: AppHomePath + "/config.json"))
        httpServer = server
        Task {
            do {
                try await server.run()
                print("FlyingFox HTTPServer started at port: \(pacPort)")
            } catch {
                print("FlyingFox HTTPServer start error: \(error)")
            }
        }
    }

    func stop() async {
        await httpServer?.stop()
        httpServer = nil
    }
}
