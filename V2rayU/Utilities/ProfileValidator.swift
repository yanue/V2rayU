//
//  ProfileValidator.swift
//  V2rayU
//
//  启动核心前检查节点必填项 (#1694)。
//  缺 UUID / 密码 / 地址或端口越界时核心会直接启动失败（日志里是 failed to build outbound handler 等）,
//  用户只看到"已启动但不能上网"。这里提前拦下并提示具体是哪个服务器缺了什么。
//

import Foundation

enum ProfileValidator {
    enum Problem: Equatable {
        case missingUUID
        case missingPassword
        case missingAddress
        case invalidPort(Int)
    }

    struct Failure: Equatable {
        let profile: ProfileEntity
        let problem: Problem
    }

    /// 检查单个节点, 没问题返回 nil
    static func problem(of profile: ProfileEntity) -> Problem? {
        switch profile.protocol {
        case .freedom, .blackhole, .dns:
            // 本地出站, 不需要服务器
            return nil
        default:
            break
        }
        if profile.address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .missingAddress
        }
        if !(1 ... 65535).contains(profile.port) {
            return .invalidPort(profile.port)
        }
        // vmess/vless 的 UUID(id) 和其他协议的密码都存在 password 字段
        let secret = profile.password.trimmingCharacters(in: .whitespacesAndNewlines)
        switch profile.protocol {
        case .vmess, .vless:
            return secret.isEmpty ? .missingUUID : nil
        case .shadowsocks:
            // method 为 none/plain 时不需要密码
            let method = profile.encryption.lowercased()
            if method == "none" || method == "plain" { return nil }
            return secret.isEmpty ? .missingPassword : nil
        case .trojan, .hysteria2, .anytls:
            return secret.isEmpty ? .missingPassword : nil
        default:
            // socks/http/naive 的认证是可选的
            return nil
        }
    }

    /// 返回第一个有问题的节点
    static func firstFailure(in profiles: [ProfileEntity]) -> Failure? {
        for profile in profiles {
            if let problem = problem(of: profile) {
                return Failure(profile: profile, problem: problem)
            }
        }
        return nil
    }

    /// 提示文案里显示的服务器名: 备注为空时用 地址:端口
    static func displayName(of profile: ProfileEntity) -> String {
        let remark = profile.remark.trimmingCharacters(in: .whitespacesAndNewlines)
        if !remark.isEmpty { return remark }
        let address = profile.address.trimmingCharacters(in: .whitespacesAndNewlines)
        return address.isEmpty ? profile.protocol.rawValue : "\(address):\(profile.port)"
    }

    @MainActor
    static func message(for failure: Failure) -> String {
        let name = displayName(of: failure.profile)
        switch failure.problem {
        case .missingUUID:
            return String(localized: .ProfileMissingFieldFormat, arguments: name, String(localized: .ProfileFieldUUID))
        case .missingPassword:
            return String(localized: .ProfileMissingFieldFormat, arguments: name, String(localized: .ProfileFieldPassword))
        case .missingAddress:
            return String(localized: .ProfileMissingFieldFormat, arguments: name, String(localized: .ProfileFieldAddress))
        case .invalidPort(let port):
            return String(localized: .ProfileInvalidPortFormat, arguments: name, port)
        }
    }

    /// 启动前调用: 有节点缺必填项时弹窗提示并返回 false（不启动核心）
    static func ensureLaunchable(_ profiles: [ProfileEntity]) async -> Bool {
        guard let failure = firstFailure(in: profiles) else { return true }
        logger.error("start aborted: profile \(failure.profile.remark) invalid: \(String(describing: failure.problem))")
        let (title, message) = await MainActor.run {
            (String(localized: .StartFailed), message(for: failure))
        }
        await showAlert(title: title, message: message)
        return false
    }
}
