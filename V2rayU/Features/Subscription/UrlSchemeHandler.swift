//
//  UrlSchemeHandler.swift
//  V2rayU
//
//  处理 URL Scheme 拉起:
//  - 分享链接 (vmess:// ss:// vless:// trojan:// hysteria2:// ...) 确认后导入节点
//  - 机场"一键导入"链接 (clash://install-config?url=  v2rayu://install-config?url=  sing-box://import-remote-profile?url=) 添加订阅
//

import AppKit
import Foundation

struct SubscriptionImportRequest: Equatable {
    var url: String
    var name: String
}

enum UrlSchemeHandler {
    /// 识别订阅导入链接, 不是就返回 nil
    static func parseSubscriptionImport(_ url: URL) -> SubscriptionImportRequest? {
        guard let scheme = url.scheme?.lowercased() else { return nil }
        let hostPath = ((url.host ?? "") + url.path).lowercased()
        let known: [String: Set<String>] = [
            "clash": ["install-config"],
            "clashmeta": ["install-config"],
            "v2rayu": ["install-config", "install-sub", "add-subscription"],
            "sing-box": ["import-remote-profile"],
        ]
        guard let actions = known[scheme], actions.contains(hostPath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))) else {
            return nil
        }
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        func query(_ name: String) -> String? {
            items.first { $0.name.lowercased() == name }?.value?.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard let subUrl = rawUrlParam(url) ?? query("url"), !subUrl.isEmpty,
              let parsed = URL(string: subUrl), let subScheme = parsed.scheme?.lowercased(), ["http", "https"].contains(subScheme) else {
            return nil
        }
        var name = rawNameParam(url) ?? query("name") ?? ""
        if name.isEmpty, let fragment = url.fragment?.removingPercentEncoding, !fragment.isEmpty {
            name = fragment
        }
        if name.isEmpty { name = parsed.host ?? "subscription" }
        return SubscriptionImportRequest(url: subUrl, name: name)
    }

    /// 有的面板 url 参数没编码: clash://install-config?url=https://x/sub?token=a&flag=clash
    /// 按 queryItems 拆会在里面的 & 处截断, 丢掉 flag 等参数。url 值没编码时 (直接以 http 开头),
    /// 把 url= 后面整段都当订阅地址, 只认末尾的 &name= 作为名字。
    private static func splitRawUrl(_ url: URL) -> (url: String, name: String?)? {
        guard let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.percentEncodedQuery else { return nil }
        let start: String.Index
        if query.lowercased().hasPrefix("url=") {
            start = query.index(query.startIndex, offsetBy: 4)
        } else if let r = query.range(of: "&url=", options: .caseInsensitive) {
            start = r.upperBound
        } else {
            return nil
        }
        var value = String(query[start...])
        guard value.lowercased().hasPrefix("http://") || value.lowercased().hasPrefix("https://") else { return nil }
        var name: String?
        if let r = value.range(of: "&name=", options: [.caseInsensitive, .backwards]) {
            name = String(value[r.upperBound...]).removingPercentEncoding
            value = String(value[..<r.lowerBound])
        }
        return (value, name)
    }

    private static func rawUrlParam(_ url: URL) -> String? { splitRawUrl(url)?.url }
    private static func rawNameParam(_ url: URL) -> String? { splitRawUrl(url)?.name }

    @MainActor
    static func handle(_ urls: [URL]) {
        for url in urls {
            if let request = parseSubscriptionImport(url) {
                confirmAndAddSubscription(request)
            } else if supportProtocol(uri: url.absoluteString) {
                confirmAndImportServer(url.absoluteString)
            } else {
                logger.info("url scheme not handled: \(url.absoluteString)")
                noticeTip(title: "URL", informativeText: "unsupported: \(url.absoluteString.prefix(80))")
            }
        }
    }

    /// 外部链接拉起导入节点, 同样先确认: 不然网页一个链接就能塞进一个别人控制的节点
    @MainActor
    private static func confirmAndImportServer(_ uri: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = String(localized: .ImportServersTitle)
        alert.informativeText = uri.count > 120 ? String(uri.prefix(120)) + "…" : uri
        alert.addButton(withTitle: String(localized: .ImportServers))
        alert.addButton(withTitle: String(localized: .Cancel))
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        importUri(url: uri)
        NavigationState.shared.mainTab = .server
        MainWindowManager.shared.openMainWindow()
    }

    /// 外部链接拉起加订阅, 先让用户确认, 免得网页随便一个链接就往里塞
    @MainActor
    private static func confirmAndAddSubscription(_ request: SubscriptionImportRequest) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = String(localized: .AddSubscription)
        alert.informativeText = "\(request.name)\n\(request.url)"
        alert.addButton(withTitle: String(localized: .Add))
        alert.addButton(withTitle: String(localized: .Cancel))
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        // 同一地址已存在就只同步, 不重复加
        let existing = SubscriptionStore.shared.fetchAll().first { $0.url == request.url }
        let sub = existing ?? SubscriptionEntity(remark: request.name, url: request.url)
        if existing == nil { sub.upsert() }
        Task {
            await SubscriptionHandler.shared.syncOne(item: sub)
        }
        NavigationState.shared.mainTab = .subscription
        MainWindowManager.shared.openMainWindow()
    }
}
