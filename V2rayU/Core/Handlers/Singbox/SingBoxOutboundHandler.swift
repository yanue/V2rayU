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
            tls: buildTLS(),
            transport: buildTransport()
        )
    }

    private func buildVless() -> SingboxOutbound {
        return SingboxOutbound(
            type: "vless",
            tag: "proxy",
            server: profile.address,
            server_port: profile.port,
            uuid: profile.password, // vless 用 id
            flow: profile.flow,
            tls: buildTLS(),
            transport: buildTransport()
        )
    }

    private func buildVmess() -> SingboxOutbound {
        return SingboxOutbound(
            type: "vmess",
            tag: "proxy",
            server: profile.address,
            server_port: profile.port,
            uuid: profile.password, // vmess 用 id
            tls: buildTLS(),
            transport: buildTransport()
        )
    }

    private func buildShadowsocks() -> SingboxOutbound {
        return SingboxOutbound(
            type: "shadowsocks",
            tag: "proxy",
            server: profile.address,
            server_port: profile.port,
            password: profile.password,
            method: profile.encryption,
            tls: buildTLS(),
            transport: buildTransport()
        )
    }

    private func buildSocks() -> SingboxOutbound {
        return SingboxOutbound(
            type: "socks",
            tag: "proxy",
            server: profile.address,
            server_port: profile.port,
            tls: buildTLS(),
            transport: buildTransport()
        )
    }
    
    private func buildTLS() -> TLSConfig? {
        guard profile.security == .tls || profile.security == .reality else { return nil }
        
        var tls = TLSConfig(
            enabled: true,
            server_name: profile.sni.isEmpty ? profile.address : profile.sni,
            insecure: profile.allowInsecure,
            alpn: profile.entity.getAlpn(),
            utls: UTLSConfig(
                enabled: true,
                fingerprint: profile.fingerprint.rawValue
            ),
            reality: nil
        )
        
        if profile.security == .reality {
            tls.reality = RealityConfig(
                enabled: true,
                public_key: profile.publicKey,
                short_id: profile.shortId.isEmpty ? nil : profile.shortId,
                spider_x: profile.spiderX.isEmpty ? nil : profile.spiderX
            )
        }
        
        return tls
    }

    // Transport
    private func buildTransport() -> TransportConfig? {
        switch profile.network {
        case .tcp: // tcp不支持配置
            return nil
            
        case .ws:
            return TransportConfig(
                type: "ws",
                path: profile.path.isEmpty ? nil : profile.path,
                headers: profile.host.isEmpty ? nil : ["Host": profile.host]
            )
            
        case .h2:
            return TransportConfig(
                type: "http",
                path: profile.path.isEmpty ? nil : profile.path,
                headers: profile.host.isEmpty ? nil : ["Host": profile.host]
            )
            
        case .grpc:
            return TransportConfig(
                type: "grpc",
                service_name: profile.path.isEmpty ? nil : profile.path
            )
            
        case .xhttp:
            return TransportConfig(
                type: "xhttp",
                path: profile.path.isEmpty ? nil : profile.path,
                headers: profile.host.isEmpty ? nil : ["Host": profile.host],
            )
            
        case .quic:
            return TransportConfig(
                type: "quic",
                path: profile.path.isEmpty ? nil : profile.path // key
            )
            
        case .kcp:
            return TransportConfig(
                type: "kcp",
                path: profile.path.isEmpty ? nil : profile.path // seed
            )
            
        case .domainsocket:
            return TransportConfig(type: "domainsocket")
            
        default:
            return nil
        }
    }

}
