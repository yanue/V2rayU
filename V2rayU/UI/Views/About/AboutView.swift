//
//  AboutView.swift
//  V2rayU
//
//  Created by yanue on 2025/8/2.
//

import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var appVersion: String = ""
    @State private var appBuild: String = ""
    @State private var coreVersion: String = ""
    @State private var year: Int = Calendar.current.component(.year, from: Date())
    
    // 相关文件路径列表: (路径, 说明)
    private let fileLocations: [(path: String, desc: String)] = [
        // 用户数据
        ("~/.V2rayU/", "config, logs, database"),
        // 系统二进制 (root:wheel)
        ("/usr/local/v2rayu/", "xray-core, sing-box, V2rayUTool"),
        // LaunchAgent (用户进程)
        ("~/Library/LaunchAgents/yanue.v2rayu.sing-box.plist", "sing-box agent"),
        ("~/Library/LaunchAgents/yanue.v2rayu.xray-core.plist", "xray-core agent"),
        // LaunchDaemon (root 进程)
        ("/Library/LaunchDaemons/yanue.v2rayu.tun-helper.plist", "tun daemon"),
        // 权限配置
        ("/private/etc/sudoers.d/v2rayu-sudoer", "sudoers rules"),
        // App 偏好设置与缓存
        ("~/Library/Preferences/net.yanue.V2rayU.plist", "preferences"),
        ("~/Library/Application Support/net.yanue.V2rayU/", "app support"),
        ("~/Library/Caches/net.yanue.V2rayU/", "caches"),
        ("~/Library/HTTPStorages/net.yanue.V2rayU/", "http storages"),
    ]
    
    // 开源库 链接
    private let openSources: [String] = [
        "https://github.com/groue/GRDB.swift",
        "https://github.com/swhitty/FlyingFox.git",
        "https://github.com/jpsim/Yams.git",
        "https://github.com/sindresorhus/KeyboardShortcuts.git",
        "https://github.com/SwiftyBeaver/SwiftyBeaver.git"
    ]
    
    var body: some View {
        VStack {
            PageHeader(
                icon: "info.circle",
                title: String(localized: .About),
                subtitle: "\(String(localized: .Version)) \(appVersion) (\(String(localized: .Build)) \(appBuild))"
            )

            Spacer()
            VStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(String(localized: .AboutSubHead))
                            .font(.body)
                            .foregroundColor(.primary)
                        
                        Text(String(localized: .AboutAppIntroduction))
                            .font(.callout)
                            .foregroundColor(.secondary)
                            .padding(.bottom, 8)
                        
                        // 开源地址
                        sectionHeader(title: String(localized: .OpenSourceProject), subtitle: String(localized: .OpenSourceLicense))
                        HStack(spacing: 24) {
                            linkButton("https://github.com/yanue/V2rayU.git")
                            Spacer()
                            Link(String(localized: .GithubIssues),
                                 destination: URL(string: "https://github.com/yanue/V2rayU/issues")!)
                                .foregroundColor(.blue)
                        }
                        
                        // 相关文件位置
                        sectionHeader(title: String(localized: .RelatedFileLocations), subtitle: String(localized: .ClickAndOpenInFinder))
                        LazyVStack(alignment: .leading, spacing: 8) {
                            ForEach(fileLocations, id: \.path) { item in
                                Button(action: { openInFinder(path: item.path) }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "folder")
                                            .foregroundColor(.gray)
                                        Text(item.path)
                                            .foregroundColor(.blue)
                                        Text("(\(item.desc))")
                                            .foregroundColor(.secondary)
                                            .font(.caption)
                                    }
                                }
                                .buttonStyle(PlainButtonStyle())
                                .focusable(false)
                                .help(String(localized: .OpenInFinder))
                                .font(.callout)
                                .underline()
                            }
                        }
                        
                        // 开源库引用
                        sectionHeader(title: String(localized: .OpenSourceLibraries), subtitle: String(localized: .UsedButNotLimitedTo))
                        LazyVStack(alignment: .leading, spacing: 8) {
                            ForEach(openSources, id: \.self) { url in
                                linkButton(url)
                            }
                        }
                        
                        // 版权信息
                        HStack {
                            Text("Copyright © 2018-\(year) yanue")
                                .font(.subheadline)
                            Text("All rights reserved.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                }
            }
            .background(.ultraThinMaterial)
            .border(Color.gray.opacity(0.1), width: 1)
            .cornerRadius(8)
            Spacer()
        }
        .padding(8)
        .onAppear {
            appVersion = getAppVersion()
            appBuild = getAppBuild()
            
            DispatchQueue.global().async {
                let version = getCoreVersion()
                DispatchQueue.main.async {
                    coreVersion = version
                }
            }
        }
    }
    
    // MARK: - Helper Views
    private func sectionHeader(title: String, subtitle: String) -> some View {
        HStack {
            Text(title).font(.headline)
            Text("(\(subtitle))").font(.caption)
            Spacer()
        }
    }
    
    private func linkButton(_ url: String) -> some View {
        Button(action: { openLink(url: url) }) {
            Image(systemName: "link")
                .foregroundColor(.gray)
            Text(url)
                .foregroundColor(.blue)
        }
        .buttonStyle(PlainButtonStyle())
        .focusable(false)
        .help(String(localized: .OpenInBrowser))
        .font(.callout)
        .underline()
    }
    
    // MARK: - Actions
    private func openLink(url: String) {
        if let url = URL(string: url) {
            NSWorkspace.shared.open(url)
        }
    }
}
