import Foundation
import Network
@testable import V2rayU

// 延迟测试用的本机服务, 不访问外网

/// 轮询等待条件成立
func waitUntil(timeout: TimeInterval = 5, _ condition: @Sendable () async -> Bool) async -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if await condition() { return true }
        try? await Task.sleep(nanoseconds: 20_000_000)
    }
    return await condition()
}

/// 记录 RealtimeLatencyMonitor 发布的值
actor PublishRecorder {
    private(set) var values: [Int] = []

    func record(_ value: Int) {
        values.append(value)
    }
}

/// 本机最小 SOCKS5 服务(无认证, 仅 CONNECT): 记录请求的目标地址, 一律转发到 127.0.0.1 的同一端口。
/// 目标用不存在的域名(如 latency-test.invalid)即可验证域名是交给代理解析的。
final class LocalSOCKS5Server: @unchecked Sendable {
    private let listener: NWListener
    private let queue = DispatchQueue(label: "LatencyTests.LocalSOCKS5Server")
    private let lock = NSLock()
    private var hosts: [String] = []
    private var connections: [NWConnection] = []
    private var started = false
    private(set) var port: UInt16 = 0

    /// 每条隧道请求的目标主机(域名或 IP)
    var requestedHosts: [String] { lock.withLock { hosts } }

    private init() throws {
        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: .any)
        listener = try NWListener(using: parameters)
    }

    static func start() async throws -> LocalSOCKS5Server {
        let server = try LocalSOCKS5Server()
        let port: UInt16 = try await withCheckedThrowingContinuation { continuation in
            server.listener.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    guard server.markStarted() else { return }
                    continuation.resume(returning: server.listener.port?.rawValue ?? 0)
                case let .failed(error):
                    guard server.markStarted() else { return }
                    continuation.resume(throwing: error)
                default:
                    break
                }
            }
            server.listener.newConnectionHandler = { connection in
                server.track(connection)
                connection.start(queue: server.queue)
                server.handshake(connection)
            }
            server.listener.start(queue: server.queue)
        }
        server.port = port
        return server
    }

    /// 停止监听并断开已建立的隧道(模拟代理断开)
    func stop() {
        listener.cancel()
        for connection in lock.withLock({ connections }) {
            connection.cancel()
        }
    }

    private func track(_ connection: NWConnection) {
        lock.withLock { connections.append(connection) }
    }

    private func markStarted() -> Bool {
        lock.withLock {
            defer { started = true }
            return !started
        }
    }

    private func read(_ connection: NWConnection, _ count: Int, _ next: @escaping (Data) -> Void) {
        connection.receive(minimumIncompleteLength: count, maximumLength: count) { data, _, _, error in
            guard error == nil, let data, data.count == count else {
                connection.cancel()
                return
            }
            next(data)
        }
    }

    private func handshake(_ client: NWConnection) {
        // 问候: VER NMETHODS METHODS...
        read(client, 2) { head in
            self.read(client, Int(head[head.startIndex + 1])) { _ in
                client.send(content: Data([0x05, 0x00]), completion: .contentProcessed { _ in })
                // 请求: VER CMD RSV ATYP
                self.read(client, 4) { request in
                    switch request[request.startIndex + 3] {
                    case 0x01:
                        self.read(client, 6) { rest in
                            let host = rest.prefix(4).map(String.init).joined(separator: ".")
                            self.connect(client, host: host, portBytes: rest.suffix(2))
                        }
                    case 0x03:
                        self.read(client, 1) { length in
                            self.read(client, Int(length[length.startIndex]) + 2) { rest in
                                let host = String(decoding: rest.dropLast(2), as: UTF8.self)
                                self.connect(client, host: host, portBytes: rest.suffix(2))
                            }
                        }
                    default:
                        client.cancel()
                    }
                }
            }
        }
    }

    private func connect(_ client: NWConnection, host: String, portBytes: Data) {
        lock.withLock { hosts.append(host) }
        let bytes = Array(portBytes)
        let port = UInt16(bytes[0]) << 8 | UInt16(bytes[1])
        let upstream = NWConnection(host: "127.0.0.1", port: NWEndpoint.Port(rawValue: port)!, using: .tcp)
        track(upstream)
        upstream.stateUpdateHandler = { state in
            switch state {
            case .ready:
                client.send(content: Data([0x05, 0x00, 0x00, 0x01, 0, 0, 0, 0, 0, 0]), completion: .contentProcessed { _ in })
                self.pipe(from: client, to: upstream)
                self.pipe(from: upstream, to: client)
            case .failed, .cancelled:
                client.cancel()
            default:
                break
            }
        }
        upstream.start(queue: queue)
    }

    private func pipe(from source: NWConnection, to target: NWConnection) {
        source.receive(minimumIncompleteLength: 1, maximumLength: 65536) { data, _, isComplete, error in
            if let data, !data.isEmpty {
                target.send(content: data, completion: .contentProcessed { _ in })
            }
            if isComplete || error != nil {
                target.cancel()
                source.cancel()
                return
            }
            self.pipe(from: source, to: target)
        }
    }
}

/// 本机最小 HTTP/1.1 服务: 固定返回指定状态码, 支持 keep-alive, 统计连接数与请求数
final class LocalHTTPServer: @unchecked Sendable {
    private let listener: NWListener
    private let queue = DispatchQueue(label: "LatencyTests.LocalHTTPServer")
    /// 按请求顺序返回的状态码, 超出后沿用最后一个
    private let statuses: [Int]
    private let lock = NSLock()
    private var connections = 0
    private var requests = 0
    private var started = false
    private(set) var port: UInt16 = 0
    private(set) var url: URL = URL(string: "http://127.0.0.1")!

    /// 以指定域名访问本服务(经 SOCKS 时由代理解析)
    func url(host: String) -> URL {
        URL(string: "http://\(host):\(port)/generate_204")!
    }

    var connectionCount: Int { lock.withLock { connections } }
    var requestCount: Int { lock.withLock { requests } }

    private init(statuses: [Int]) throws {
        self.statuses = statuses
        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: .any)
        listener = try NWListener(using: parameters)
    }

    static func start(status: Int) async throws -> LocalHTTPServer {
        try await start(statuses: [status])
    }

    static func start(statuses: [Int]) async throws -> LocalHTTPServer {
        let server = try LocalHTTPServer(statuses: statuses)
        let port: UInt16 = try await withCheckedThrowingContinuation { continuation in
            server.listener.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    guard server.markStarted() else { return }
                    continuation.resume(returning: server.listener.port?.rawValue ?? 0)
                case let .failed(error):
                    guard server.markStarted() else { return }
                    continuation.resume(throwing: error)
                default:
                    break
                }
            }
            server.listener.newConnectionHandler = { connection in
                server.lock.withLock { server.connections += 1 }
                connection.start(queue: server.queue)
                server.receive(on: connection, buffer: Data())
            }
            server.listener.start(queue: server.queue)
        }
        server.port = port
        server.url = URL(string: "http://127.0.0.1:\(port)/generate_204")!
        return server
    }

    func stop() {
        listener.cancel()
    }

    /// 启动结果只回调一次
    private func markStarted() -> Bool {
        lock.withLock {
            defer { started = true }
            return !started
        }
    }

    private func receive(on connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            var buffer = buffer
            if let data { buffer.append(data) }
            let terminator = Data("\r\n\r\n".utf8)
            while let range = buffer.range(of: terminator) {
                buffer.removeSubrange(buffer.startIndex ..< range.upperBound)
                let index = self.lock.withLock { () -> Int in
                    defer { self.requests += 1 }
                    return self.requests
                }
                connection.send(content: self.response(status: self.statuses[min(index, self.statuses.count - 1)]), completion: .contentProcessed { _ in })
            }
            if isComplete || error != nil {
                connection.cancel()
                return
            }
            self.receive(on: connection, buffer: buffer)
        }
    }

    private func response(status: Int) -> Data {
        var head = "HTTP/1.1 \(status) Test\r\nContent-Length: 0\r\nConnection: keep-alive\r\n"
        if (300 ..< 400).contains(status) {
            head += "Location: http://127.0.0.1:1/\r\n"
        }
        return Data((head + "\r\n").utf8)
    }
}
