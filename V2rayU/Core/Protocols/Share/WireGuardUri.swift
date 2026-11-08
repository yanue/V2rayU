import Foundation

// WireGuard (Xray-core wireguard outbound / Sing-Box wireguard endpoint)
// 字段复用: 地址/端口存对端 endpoint, password 存本地私钥, publicKey 存对端公钥, 其余存在 extra (WireGuardConfig)
class WireGuardUri: BaseShareUri {
    private var profile: ProfileEntity

    init() {
        profile = ProfileEntity(protocol: .wireguard)
    }

    required init(from model: ProfileEntity) {
        profile = model
    }

    func getProfile() -> ProfileEntity {
        return profile
    }

    // wireguard://privateKey@host:port?publickey=...&address=172.16.0.2/32,fd01::2/128&reserved=1,2,3&mtu=1280&presharedkey=...#remark
    func encode() -> String {
        let wg = profile.getWireGuardConfig()
        var uri = URLComponents()
        uri.scheme = "wireguard"
        uri.user = profile.password
        // IPv6 必须加方括号, 否则 URL 生成失败(nil)
        uri.host = profile.address.contains(":") ? "[\(profile.address)]" : profile.address
        uri.port = profile.port

        var queryItems = [
            URLQueryItem(name: "publickey", value: profile.publicKey),
            URLQueryItem(name: "address", value: wg.localAddress),
            URLQueryItem(name: "mtu", value: String(wg.mtu)),
        ]
        if !wg.reserved.isEmpty {
            queryItems.append(URLQueryItem(name: "reserved", value: wg.reserved))
        }
        if !wg.preSharedKey.isEmpty {
            queryItems.append(URLQueryItem(name: "presharedkey", value: wg.preSharedKey))
        }
        uri.queryItems = queryItems
        // 密钥是 base64, "+" 在查询串里会被当成空格, 需要转义
        uri.percentEncodedQuery = uri.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")

        return (uri.url?.absoluteString ?? "") + "#" + profile.remark.urlEncoded()
    }

    func parse(url: URL) -> Error? {
        guard let host = url.host, !host.isEmpty else {
            return NSError(domain: "WireGuardUriError", code: 1001, userInfo: [NSLocalizedDescriptionKey: "Missing host"])
        }
        guard let port = url.port else {
            return NSError(domain: "WireGuardUriError", code: 1002, userInfo: [NSLocalizedDescriptionKey: "Missing port"])
        }
        // URL.user 已经解码过, 不能再解一次
        guard let privateKey = url.user, !privateKey.isEmpty else {
            return NSError(domain: "WireGuardUriError", code: 1003, userInfo: [NSLocalizedDescriptionKey: "Missing private key"])
        }

        let query = url.queryParams()
        let publicKey = query.getString(forKey: "publickey", defaultValue: query.getString(forKey: "publicKey", defaultValue: ""))
        guard !publicKey.isEmpty else {
            return NSError(domain: "WireGuardUriError", code: 1004, userInfo: [NSLocalizedDescriptionKey: "Missing public key"])
        }

        logger.info("Parsed WireGuard URI: \(host):\(port)")

        profile.protocol = .wireguard
        profile.address = host.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
        profile.port = port
        profile.password = privateKey
        profile.publicKey = publicKey
        profile.network = .tcp
        profile.security = .none

        var wg = ProfileEntity.WireGuardConfig()
        wg.localAddress = Self.joinList(Self.localAddresses(query.getString(forKey: "address", defaultValue: query.getString(forKey: "ip", defaultValue: ""))))
        wg.preSharedKey = query.getString(forKey: "presharedkey", defaultValue: query.getString(forKey: "preSharedKey", defaultValue: ""))
        wg.reserved = Self.normalizedReserved(query.getString(forKey: "reserved", defaultValue: ""))
        wg.mtu = Int(query.getString(forKey: "mtu", defaultValue: "")) ?? wg.mtu
        profile.setWireGuardConfig(wg)

        if let fragment = url.fragment, !fragment.isEmpty {
            profile.remark = fragment.urlDecoded()
        }
        if profile.remark.isEmpty {
            profile.remark = "wireguard"
        }

        return nil
    }

    // MARK: - Helpers

    /// 逗号分隔的列表, 去掉空白和空项
    static func splitList(_ value: String) -> [String] {
        value.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }

    /// 本地地址补上前缀长度: sing-box endpoint 的 address 必须是 CIDR, Clash 常写成 ip: 172.16.0.2
    static func localAddresses(_ value: String) -> [String] {
        splitList(value).map { address in
            if address.contains("/") { return address }
            return address.contains(":") ? "\(address)/128" : "\(address)/32"
        }
    }

    static func joinList(_ values: [String]) -> String {
        values.joined(separator: ",")
    }

    /// reserved 支持 "1,2,3" 或 base64 (3 字节) 两种写法, 统一成 "1,2,3"; 无法识别返回空
    static func normalizedReserved(_ value: String) -> String {
        parseReserved(value).map { $0.map(String.init).joined(separator: ",") } ?? ""
    }

    static func parseReserved(_ value: String) -> [Int]? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let parts = splitList(trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "[]")))
        let numbers = parts.compactMap { Int($0) }
        if numbers.count == 3, numbers.count == parts.count, numbers.allSatisfy({ (0 ... 255).contains($0) }) {
            return numbers
        }
        if let data = Data(base64Encoded: trimmed), data.count == 3 {
            return data.map { Int($0) }
        }
        return nil
    }

    /// host:port, IPv6 加方括号
    static func endpoint(host: String, port: Int) -> String {
        host.contains(":") ? "[\(host)]:\(port)" : "\(host):\(port)"
    }

    static func host(ofEndpoint endpoint: String) -> String {
        if endpoint.hasPrefix("["), let end = endpoint.firstIndex(of: "]") {
            return String(endpoint[endpoint.index(after: endpoint.startIndex) ..< end])
        }
        guard let colon = endpoint.lastIndex(of: ":") else { return endpoint }
        return String(endpoint[..<colon])
    }
}
