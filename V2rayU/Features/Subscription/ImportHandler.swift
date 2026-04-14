//
// Created by yanue on 2018/11/22.
// Copyright (c) 2018 yanue. All rights reserved.
//

import Cocoa
import CoreGraphics
import CoreImage

func importUri(url: String) {
    let urls = url.split(separator: "\n")

    for url in urls {
        let uri = url.trimmingCharacters(in: .whitespaces)

        if uri.count == 0 {
            noticeTip(title: "import server fail", informativeText: "import error: uri not found")
            continue
        }

        let importUri = ImportUri(share_uri: uri)

        if let profile = importUri.doImport() {
            // 保存到数据库
            ProfileStore.shared.insert(profile)
            continue
        } else {
            noticeTip(title: "import server fail", informativeText: importUri.error)
        }
    }
}

func supportProtocol(uri: String) -> Bool {
    if uri.hasPrefix("ss://") || uri.hasPrefix("ssr://") || uri.hasPrefix("vmess://") || uri.hasPrefix("vless://") || uri.hasPrefix("trojan://") {
        return true
    }
    return false
}

// MARK: - V2ray JSON Config Import

/// 从 V2ray/Xray JSON 配置文本解析服务器
/// 支持 outbounds 中的 vmess/vless/trojan/shadowsocks 协议
/// - Parameter json: JSON 配置字符串
/// - Returns: 解析后的 ProfileEntity，失败返回 nil
func importFromJson(json: String) -> ProfileEntity? {
    guard let data = json.data(using: .utf8) else {
        return nil
    }

    do {
        guard let jsonObj = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let outbounds = jsonObj["outbounds"] as? [[String: Any]] else {
            return nil
        }

        // 找到第一个代理协议的 outbound（跳过 freedom/blackhole/dns 等）
        let proxyProtocols = Set(["vmess", "vless", "trojan", "shadowsocks"])
        guard let proxyOutbound = outbounds.first(where: {
            guard let proto = $0["protocol"] as? String else { return false }
            return proxyProtocols.contains(proto.lowercased())
        }),
        let protocolStr = proxyOutbound["protocol"] as? String else {
            return nil
        }

        return parseOutboundToProfile(protocolStr: protocolStr, outbound: proxyOutbound)
    } catch {
        logger.error("importFromJson error: \(error)")
        return nil
    }
}

/// 解析 outbound 配置到 ProfileEntity
private func parseOutboundToProfile(protocolStr: String, outbound: [String: Any]) -> ProfileEntity? {
    var profile = ProfileEntity()

    switch protocolStr.lowercased() {
    case "vmess":
        profile.protocol = .vmess
        if let settings = outbound["settings"] as? [String: Any],
           let vmess = settings["vnext"] as? [[String: Any]],
           let first = vmess.first {
            profile.address = first["address"] as? String ?? ""
            profile.port = first["port"] as? Int ?? 0
            if let users = first["users"] as? [[String: Any]],
               let firstUser = users.first {
                profile.password = firstUser["id"] as? String ?? ""
                profile.alterId = firstUser["alterId"] as? Int ?? 0
                profile.encryption = firstUser["security"] as? String ?? "auto"
            }
        }

    case "vless":
        profile.protocol = .vless
        if let settings = outbound["settings"] as? [String: Any],
           let vnext = settings["vnext"] as? [[String: Any]],
           let first = vnext.first {
            profile.address = first["address"] as? String ?? ""
            profile.port = first["port"] as? Int ?? 0
            if let users = first["users"] as? [[String: Any]],
               let firstUser = users.first {
                profile.password = firstUser["id"] as? String ?? ""
                profile.flow = firstUser["flow"] as? String ?? ""
                profile.encryption = firstUser["encryption"] as? String ?? "none"
            }
        }

    case "trojan":
        profile.protocol = .trojan
        if let settings = outbound["settings"] as? [String: Any],
           let servers = settings["servers"] as? [[String: Any]],
           let first = servers.first {
            profile.address = first["address"] as? String ?? ""
            profile.port = first["port"] as? Int ?? 0
            profile.password = first["password"] as? String ?? ""
        }

    case "shadowsocks":
        profile.protocol = .shadowsocks
        if let settings = outbound["settings"] as? [String: Any],
           let servers = settings["servers"] as? [[String: Any]],
           let first = servers.first {
            profile.address = first["address"] as? String ?? ""
            profile.port = first["port"] as? Int ?? 0
            profile.password = first["password"] as? String ?? ""
            profile.encryption = first["method"] as? String ?? ""
        }

    default:
        return nil
    }

    // 解析传输设置
    if let streamSettings = outbound["streamSettings"] as? [String: Any] {
        parseStreamSettings(streamSettings, into: &profile)
    }

    // 生成 remark
    if profile.remark.isEmpty {
        profile.remark = "\(profile.address):\(profile.port)"
    }

    return profile
}

/// 解析流传输设置
private func parseStreamSettings(_ streamSettings: [String: Any], into profile: inout ProfileEntity) {
    if let network = streamSettings["network"] as? String {
        switch network {
        case "tcp": profile.network = .tcp
        case "kcp", "mkcp": profile.network = .kcp
        case "ws", "websocket": profile.network = .ws
        case "h2", "http": profile.network = .h2
        case "grpc": profile.network = .grpc
        case "quic": profile.network = .quic
        case "xhttp": profile.network = .xhttp
        default: profile.network = .tcp
        }
    }

    if let security = streamSettings["security"] as? String {
        switch security.lowercased() {
        case "tls":
            profile.security = .tls
            if let tlsSettings = streamSettings["tlsSettings"] as? [String: Any] {
                profile.sni = tlsSettings["serverName"] as? String ?? ""
                profile.allowInsecure = tlsSettings["allowInsecure"] as? Bool ?? true
                if let alpn = tlsSettings["alpn"] as? [String] {
                    profile.alpn = V2rayStreamAlpn(rawValue: alpn.first ?? "h2,http/1.1") ?? .h2h1
                }
                if let fingerprint = tlsSettings["fingerprint"] as? String {
                    profile.fingerprint = V2rayStreamFingerprint(rawValue: fingerprint) ?? .chrome
                }
            }

        case "reality":
            profile.security = .reality
            if let realitySettings = streamSettings["realitySettings"] as? [String: Any] {
                profile.sni = realitySettings["serverName"] as? String ?? ""
                profile.publicKey = realitySettings["publicKey"] as? String ?? ""
                profile.shortId = realitySettings["shortId"] as? String ?? ""
                profile.spiderX = realitySettings["spiderX"] as? String ?? ""
                if let fingerprint = realitySettings["fingerprint"] as? String {
                    profile.fingerprint = V2rayStreamFingerprint(rawValue: fingerprint) ?? .chrome
                }
            }

        default:
            profile.security = .none
        }
    }
}

class ImportUri {
    var isValid: Bool = false
    var error: String = ""
    var remark: String = ""
    private var share_uri: String = ""

    init(share_uri: String) {
        self.share_uri = share_uri
    }

    func doImport() -> ProfileEntity? {
        var url = URL(string: share_uri)
        if url == nil {
            // 标准url不支持非url-encoded
            let aUri = self.share_uri.split(separator: "#")
            url = URL(string: String(aUri[0]))
            if url == nil {
                self.error = "invalid url"
                return nil
            }
            if aUri.count > 1 {
                self.remark = String(aUri[1]).urlDecoded()
            }
        }

        // 定义变量
        var uriHandler: BaseShareUri?

        // 根据 URI 前缀选择对应处理类
        if share_uri.hasPrefix("trojan://") {
            uriHandler = TrojanUri()
        } else if share_uri.hasPrefix("vmess://") {
            uriHandler = VmessUri()
        } else if share_uri.hasPrefix("vless://") {
            uriHandler = VlessUri()
        } else if share_uri.hasPrefix("ss://") {
            uriHandler = ShadowsocksUri()
        } else if share_uri.hasPrefix("ssr://") {
            uriHandler = ShadowsocksRUri()
        }

        // 解析 URI
        if let handler = uriHandler {
            let parseError = handler.parse(url: url!)
            if let error = parseError {
                // 如果解析失败，返回 nil
                self.error = error.localizedDescription
                return nil
            }
            // 解析成功返回 ProfileModel
            var profile = handler.getProfile()
            // 原始分享链接保存下来(用于比较是否订阅是否有变化)
            profile.shareUri = share_uri
            if self.remark.count > 0 {
                profile.remark = self.remark
            }
            return profile
        } else {
            self.error = "unsupported protocol"
        }

        return nil
    }

}
