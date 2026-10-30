import Foundation
import Network
import Testing
@testable import V2rayU

/// 本机起一个只会回固定 HTTP 响应的小服务, 伪造机场订阅接口
final class MockSubscriptionServer: @unchecked Sendable {
    private let listener: NWListener
    private let queue = DispatchQueue(label: "mock-sub-server")
    private var connections: [NWConnection] = []
    private let lock = NSLock()
    private var _userInfoHeader: String?
    var port: UInt16 { listener.port?.rawValue ?? 0 }
    let body = "ss://YWVzLTI1Ni1nY206cGFzc3dvcmQ=@1.2.3.4:8388#mock-node\n"

    var userInfoHeader: String? {
        get { lock.lock(); defer { lock.unlock() }; return _userInfoHeader }
        set { lock.lock(); _userInfoHeader = newValue; lock.unlock() }
    }

    init() throws {
        let params = NWParameters.tcp
        params.requiredInterfaceType = .loopback
        listener = try NWListener(using: params, on: .any)
        let ready = DispatchSemaphore(value: 0)
        listener.stateUpdateHandler = { state in
            if case .ready = state { ready.signal() }
            if case .failed = state { ready.signal() }
        }
        listener.newConnectionHandler = { [weak self] conn in self?.accept(conn) }
        listener.start(queue: queue)
        _ = ready.wait(timeout: .now() + 5)
    }

    var url: String { "http://127.0.0.1:\(port)/sub" }

    private func accept(_ conn: NWConnection) {
        lock.lock(); connections.append(conn); lock.unlock()
        conn.start(queue: queue)
        // 读到请求头结束就回响应, 不解析请求内容
        conn.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] _, _, _, _ in
            guard let self else { return }
            let data = self.body.data(using: .utf8)!
            var head = "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: \(data.count)\r\nConnection: close\r\n"
            if let v = self.userInfoHeader { head += "Subscription-Userinfo: \(v)\r\n" }
            head += "\r\n"
            conn.send(content: head.data(using: .utf8)! + data, completion: .contentProcessed { _ in
                conn.cancel()
            })
        }
    }

    func stop() {
        listener.cancel()
        lock.lock(); connections.forEach { $0.cancel() }; connections.removeAll(); lock.unlock()
    }
}

/// 验证 subscription-userinfo 从下载到写库的完整链路
struct SubscriptionUserInfoIntegrationTests {
    @Test func syncStoresUserInfoAndClearsWhenHeaderMissing() async throws {
        let server = try MockSubscriptionServer()
        defer { server.stop() }
        try #require(server.port != 0)

        let sub = SubscriptionEntity(uuid: "test-userinfo-\(UUID().uuidString)", remark: "userinfo-mock",
                                     url: server.url, enable: false)
        #expect(SubscriptionStore.shared.upsert(sub))
        defer {
            let profiles = ProfileStore.shared.getGroupProfiles(subid: sub.uuid).map(\.uuid)
            if !profiles.isEmpty { ProfileStore.shared.delete(uuids: profiles) }
            SubscriptionStore.shared.delete(uuid: sub.uuid)
        }

        // 带头: 解析出用量并写库
        server.userInfoHeader = "upload=1073741824; download=3221225472; total=107374182400; expire=1900000000"
        let result = try await SubscriptionHandler.shared.dlFromUrl(url: sub.url, sub: sub, useProxy: false)
        #expect(result.configType == "normal")
        #expect(result.userInfo == SubscriptionUserInfo(upload: 1073741824, download: 3221225472, total: 107374182400, expire: 1900000000))
        #expect(ProfileStore.shared.getGroupProfiles(subid: sub.uuid).count == 1)

        SubscriptionEntity.markSynced(uuid: sub.uuid, configType: result.configType, userInfo: result.userInfo)
        let stored = try #require(SubscriptionStore.shared.fetchOne(uuid: sub.uuid))
        #expect(stored.userInfo == result.userInfo)
        #expect(stored.configType == "normal")
        #expect(stored.userInfo.usedRatio.map { abs($0 - 0.04) < 0.001 } == true)
        #expect(stored.userInfo.trafficText == "\(SubscriptionUserInfo.formatBytes(4294967296)) / \(SubscriptionUserInfo.formatBytes(107374182400))")

        // 不带头: 旧用量清零
        server.userInfoHeader = nil
        let result2 = try await SubscriptionHandler.shared.dlFromUrl(url: sub.url, sub: sub, useProxy: false)
        #expect(result2.userInfo == nil)
        SubscriptionEntity.markSynced(uuid: sub.uuid, configType: result2.configType, userInfo: result2.userInfo)
        let cleared = try #require(SubscriptionStore.shared.fetchOne(uuid: sub.uuid))
        #expect(cleared.userInfo.isEmpty)
    }
}
