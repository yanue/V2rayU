//
//  AboutView.swift
//  V2rayU
//
//  Created by yanue on 2025/8/2.
//

import SwiftUI
struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var appVersion = getAppVersion()
    @State private var appBuild = getAppBuild()
    @State private var coreVersion = getCoreVersion()

    // 相关文件路径列表
    private var fileLocations: [String] {
        [
            "~/.V2rayU/",
            "~/Library/Preferences/net.yanue.V2rayU.plist",
            "~/Library/Application Support/net.yanue.V2rayU/",
            "~/Library/Caches/net.yanue.V2rayU/",
            "~/Library/HTTPStorages/net.yanue.V2rayU/",
        ]
    }

    // 开源库 链接
    private var openSources: [String] {
        [
            "https://github.com/groue/GRDB.swift",
            "https://github.com/swhitty/FlyingFox.git",
            "https://github.com/jpsim/Yams.git",
            "https://github.com/sindresorhus/KeyboardShortcuts.git",
            "https://github.com/SwiftyBeaver/SwiftyBeaver.git",
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image("V2rayU")
                    .resizable()
                    .frame(width: 32, height: 32)
                    .foregroundColor(.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text("About")
                        .font(.title)
                        .fontWeight(.bold)
                    HStack {
                        Text("Version \(appVersion) (Build \(appBuild))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("\(coreVersion)")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                }
            }
            Divider()

            HStack(spacing: 20) {
                Text("V2rayU is a macOS GUI client for Xray-Core. Supports Vmess, Vless, Trojan, Shadowsocks, and more protocols.")
                    .font(.body)
                    .foregroundColor(.primary)
            }

            // 开源地址
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("开源地址")
                        .font(.headline)
                    Text("(遵循 GNU GPL v3.0 许可协议)")
                        .font(.caption)
                    Spacer()
                }
                HStack(spacing: 24) {
                    Button(action: { openLink(url: "https://github.com/yanue/V2rayU.git") }) {
                        Image(systemName: "link")
                            .foregroundColor(.gray)
                        Text("https://github.com/yanue/V2rayU.git")
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("在浏览器中打开")
                    .font(.callout)
                    .underline()

                    Spacer()

                    Link("问题反馈", destination: URL(string: "https://github.com/yanue/V2rayU/issues")!)
                        .foregroundColor(.blue)
                }
            }

            // 相关文件位置
            VStack(alignment: .leading) {
                HStack {
                    Text("相关文件位置")
                        .font(.headline)
                    Text("(点击路径可在 Finder 打开)")
                        .font(.caption)
                    Spacer()
                }
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(fileLocations, id: \ .self) { path in
                        Button(action: { openInFinder(path: path) }) {
                            HStack(spacing: 6) {
                                Image(systemName: "folder")
                                    .foregroundColor(.gray)
                                Text(path)
                                    .foregroundColor(.blue)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        .help("在 Finder 中打开")
                        .font(.callout)
                        .underline()
                    }
                }
            }

            // 开源库引用
            VStack(alignment: .leading) {
                HStack {
                    Text("引用开源库")
                        .font(.headline)
                    Text("(有用到且不限于以下)")
                        .font(.caption)
                    Spacer()
                }
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(openSources, id: \ .self) { url in
                        Button(action: { openLink(url: url) }) {
                            Image(systemName: "link")
                                .foregroundColor(.gray)
                            Text(url)
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .help("在浏览器中打开")
                        .font(.callout)
                        .underline()
                    }
                }
            }

            // 版权信息
            HStack {
                Text("Copyright © 2018-2025 yanue")
                    .font(.subheadline)
                Text("All rights reserved.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }

    // 打开 Finder 方法
    private func openInFinder(path: String) {
        let expandedPath = (path as NSString).expandingTildeInPath
        let url = URL(fileURLWithPath: expandedPath)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    private func openLink(url: String) {
        if let url = URL(string: url) {
            NSWorkspace.shared.open(url)
        } else {
            print("Invalid URL: \(url)")
        }
    }
}
