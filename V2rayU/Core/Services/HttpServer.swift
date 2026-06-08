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
    private var currentPort: UInt16?
    private var currentAddress: String?

    func restart() async {
        logger.info("Restarting LocalHttpServer")
        await stop()
        try? await Task.sleep(nanoseconds: 200_000_000)
        await start()
    }

    func start() async {
        let pacPort = getPacPort()
        let listenAddress = getListenAddress()
        logger.info("pacPort: \(pacPort), listenAddress: \(listenAddress)")

        if httpServer != nil, currentPort == pacPort, currentAddress == listenAddress {
            logger.info("LocalHttpServer already running at \(listenAddress):\(pacPort)")
            return
        }

        if httpServer != nil {
            await stop()
            try? await Task.sleep(nanoseconds: 200_000_000)
        }

        if isPortOpen(pacPort) {
            let title = await String(localized: .PortInUse)
            let toast = await "\(pacPort) " + String(localized: .PortInUseTip)
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
            server = try HTTPServer(address: .inet(ip4: listenAddress, port: UInt16(pacPort)))
        } catch {
            logger.info("Failed to create HTTP server: \(error)")
            return
        }
        
        // 最简单的目录映射(其他方式不能正常使用)
        await server.appendRoute("GET /*") { request in
            let path = request.path
            let requestedPath = path == "/" ? "/index.html" : path
            let relativePath = requestedPath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))

            // 安全过滤：规范化路径，防止 ../ 目录遍历攻击
            let baseURL = URL(fileURLWithPath: AppHomePath, isDirectory: true).resolvingSymlinksInPath().standardized
            let resolvedURL = baseURL.appendingPathComponent(relativePath).resolvingSymlinksInPath().standardized

            // 确保解析后的路径仍在 AppHomePath 下
            let basePath = baseURL.path
            guard resolvedURL.path == basePath || resolvedURL.path.hasPrefix(basePath + "/") else {
                logger.warning("Path traversal attempt blocked: \(path)")
                return HTTPResponse(statusCode: .forbidden)
            }

            let filePath = resolvedURL.path
            logger.info("Requested: \(path) \(filePath)")

            if FileManager.default.fileExists(atPath: filePath),
               let data = try? Data(contentsOf: URL(fileURLWithPath: filePath)) {
                return HTTPResponse(statusCode: .ok, body: data)
            }
            return HTTPResponse(statusCode: .notFound)
        }
        
        httpServer = server
        currentPort = pacPort
        currentAddress = listenAddress
        Task {
            do {
                logger.info("FlyingFox HTTPServer starting at \(listenAddress):\(pacPort)")
                try await server.run()
                logger.info("FlyingFox HTTPServer stopped at \(listenAddress):\(pacPort)")
            } catch {
                logger.info("FlyingFox HTTPServer run error: \(error)")
            }
            await self.clearIfCurrent(server)
        }
    }

    private func clearIfCurrent(_ server: HTTPServer) {
        guard httpServer === server else { return }
        httpServer = nil
        currentPort = nil
        currentAddress = nil
    }

    func stop() async {
        await httpServer?.stop()
        httpServer = nil
        currentPort = nil
        currentAddress = nil
    }
}
