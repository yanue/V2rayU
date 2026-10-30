//
//  QuickRouting.swift
//  V2rayU
//
//  快捷分流: 把某个域名 / IP 一键加进当前路由的直连 / 代理 / 拦截列表, 立即生效
//

import Foundation

enum QuickRuleTarget: String, CaseIterable {
    case direct
    case proxy
    case block

    var label: LanguageLabel {
        switch self {
        case .direct: return .Direct
        case .proxy: return .Proxy
        case .block: return .Block
        }
    }
}

enum QuickRouting {
    /// 去掉端口 / 方括号, 小写; 空、localhost、本机地址返回 nil
    static func normalizeHost(_ raw: String) -> String? {
        var host = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if host.hasPrefix("[") {
            // [v6]:port
            if let end = host.firstIndex(of: "]") {
                host = String(host[host.index(after: host.startIndex)..<end])
            }
        } else if host.filter({ $0 == ":" }).count == 1, let colon = host.firstIndex(of: ":") {
            // host:port (只有一个冒号, 纯 v6 地址有多个冒号不动)
            host = String(host[..<colon])
        }
        host = host.trimmingCharacters(in: CharacterSet(charactersIn: "."))
        guard !host.isEmpty, host != "localhost", !host.hasPrefix("127."), host != "::1",
              !host.contains(where: { $0.isWhitespace || $0 == "/" }) else { return nil }
        guard isIp(str: host) || isIPv6Literal(host) || isDomain(str: host) else { return nil }
        return host
    }

    /// 写进路由列表的那一行: 域名用 domain: 前缀 (xray 按后缀匹配, sing-box 转 domain_suffix), IP 原样
    static func ruleLine(host: String) -> String {
        (isIp(str: host) || isIPv6Literal(host)) ? host : "domain:\(host)"
    }

    /// 从三个列表里去掉同一条规则, 再加到目标列表末尾; 内容没变返回 false
    /// 同一个主机的各种写法 (example.com / domain:example.com / full:example.com) 都算同一条
    static func sameHost(_ a: String, _ b: String) -> Bool {
        func bare(_ s: String) -> String {
            var v = s.lowercased()
            for prefix in ["domain:", "full:"] where v.hasPrefix(prefix) { v = String(v.dropFirst(prefix.count)) }
            return v
        }
        return bare(a) == bare(b)
    }

    @discardableResult
    static func apply(line: String, target: QuickRuleTarget, entity: inout RoutingEntity) -> Bool {
        func strip(_ text: String) -> [String] {
            text.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty && !sameHost($0, line) }
        }
        var direct = strip(entity.direct)
        var proxy = strip(entity.proxy)
        var block = strip(entity.block)
        switch target {
        case .direct: direct.append(line)
        case .proxy: proxy.append(line)
        case .block: block.append(line)
        }
        let newDirect = direct.joined(separator: "\n")
        let newProxy = proxy.joined(separator: "\n")
        let newBlock = block.joined(separator: "\n")
        let changed = newDirect != entity.direct.trimmingCharacters(in: .whitespacesAndNewlines)
            || newProxy != entity.proxy.trimmingCharacters(in: .whitespacesAndNewlines)
            || newBlock != entity.block.trimmingCharacters(in: .whitespacesAndNewlines)
        entity.direct = newDirect
        entity.proxy = newProxy
        entity.block = newBlock
        return changed
    }

    /// 加到当前使用的路由并重载核心
    @MainActor
    static func add(host rawHost: String, target: QuickRuleTarget) {
        guard let host = normalizeHost(rawHost) else {
            noticeTip(title: String(localized: .QuickRouting), informativeText: "invalid host: \(rawHost)")
            return
        }
        let manager = RoutingManager()
        var entity = manager.getRunningEntity()
        let line = ruleLine(host: host)
        apply(line: line, target: target, entity: &entity)
        manager.saveAndReloadIfNeeded(entity)
        noticeTip(title: String(localized: target.label), informativeText: "\(host) → \(entity.remark)")
    }
}
