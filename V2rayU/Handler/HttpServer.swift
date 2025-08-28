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

    func restart() {
        logger.info("Restarting LocalHttpServer")
        Task {
            await stop()
            await start()
        }
    }
    
    func start() async {
        // 停止已有服务
        await stop()
        let pacPort = getPacPort()
        logger.info("pacPort", pacPort)

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
        
        // 创建 HTTP 服务器
        let server: HTTPServer
        do {
            // 绑定到所有网络接口，支持局域网访问
            server = try HTTPServer(address: .inet(ip4: getListenAddress(), port: UInt16(pacPort)))
        } catch {
            logger.info("Failed to create HTTP server: \(error)")
            return
        }
        
        // 最简单的目录映射(其他方式不能正常使用)
        await server.appendRoute("GET /*") { request in
            let path = request.path
            let filePath = AppHomePath + (path == "/" ? "/index.html" : path)

            logger.info("Requested: \(path) \(filePath)")

            if FileManager.default.fileExists(atPath: filePath),
               let data = try? Data(contentsOf: URL(fileURLWithPath: filePath)) {
                return HTTPResponse(statusCode: .ok, body: data)
            }
            return HTTPResponse(statusCode: .notFound)
        }
        
        httpServer = server
        Task {
            do {
                try await server.run()
                logger.info("FlyingFox HTTPServer started at port: \(pacPort)")
            } catch {
                alertDialog(title: "启动 http 失败", message: "\(error)")
                logger.info("FlyingFox HTTPServer start error: \(error)")
            }
        }
    }

    func stop() async {
        await httpServer?.stop()
        httpServer = nil
    }
}
