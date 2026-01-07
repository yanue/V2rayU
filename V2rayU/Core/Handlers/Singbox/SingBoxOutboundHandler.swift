//
//  SingBoxOutboundHandler.swift
//  V2rayU
//
//  Created by yanue on 2026/1/7.
//


import Foundation

class SingboxOutboundHandler {
    private var profile: ProfileModel

    init(from profile: ProfileModel) {
        self.profile = profile
    }

    func getOutbound() -> SingboxOutbound {
        switch profile.protocol {
        case .trojan:
            return buildTrojan()
        case .vless:
            return buildVless()
        case .vmess:
            return buildVmess()
        case .shadowsocks:
            return buildShadowsocks()
        case .socks:
            return buildSocks()
        case .freedom:
            return SingboxOutbound(type: "direct", tag: "direct")
        case .blackhole:
            return SingboxOutbound(type: "block", tag: "block")
        case .http, .dns:
            // http 和 dns 不支持作为 outbound 使用，返回一个默认的 direct 出站
            return SingboxOutbound(type: "direct", tag: "direct")
        }
    }

    private func buildTrojan() -> SingboxOutbound {
        return SingboxOutbound(
            type: "trojan",
            tag: "proxy",
            server: profile.address,
            server_port: profile.port,
            password: profile.password,
            tls: buildTLS()
        )
    }

    private func buildVless() -> SingboxOutbound {
        return SingboxOutbound(
            type: "vless",
            tag: "proxy",
            server: profile.address,
            server_port: profile.port,
            password: profile.password, // vless 用 id
            tls: buildTLS()
        )
    }

    private func buildVmess() -> SingboxOutbound {
        return SingboxOutbound(
            type: "vmess",
            tag: "proxy",
            server: profile.address,
            server_port: profile.port,
            password: profile.password, // vmess 用 id
            tls: buildTLS()
        )
    }

    private func buildShadowsocks() -> SingboxOutbound {
        return SingboxOutbound(
            type: "shadowsocks",
            tag: "proxy",
            server: profile.address,
            server_port: profile.port,
            password: profile.password,
            domain_resolver: "default-dns"
        )
    }

    private func buildSocks() -> SingboxOutbound {
        return SingboxOutbound(
            type: "socks",
            tag: "proxy",
            server: profile.address,
            server_port: profile.port
        )
    }

    private func buildTLS() -> TLSConfig? {
        guard profile.security == .tls || profile.security == .reality else { return nil }
        var alpn = profile.alpn.rawValue.isEmpty ? [] : [profile.alpn.rawValue]
        if self.profile.network == .h2{
            if alpn.isEmpty {
            }
        }
        alpn = ["http/1.1"]

        return TLSConfig(
            enabled: true,
            server_name: profile.sni.isEmpty ? profile.address : profile.sni,
            insecure: profile.allowInsecure,
            alpn: alpn,
            utls: UTLSConfig(enabled: true, fingerprint: profile.fingerprint.rawValue)
        )
    }
}
