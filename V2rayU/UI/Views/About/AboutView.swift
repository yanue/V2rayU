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
    
    // 相关文件路径列表
    private let fileLocations: [String] = [
        "~/.V2rayU/",
        "~/Library/Preferences/net.yanue.V2rayU.plist",
        "~/Library/Application Support/net.yanue.V2rayU/",
        "~/Library/Caches/net.yanue.V2rayU/",
        "~/Library/HTTPStorages/net.yanue.V2rayU/"
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
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                
                // Header
                HStack {
                    Image("V2rayU")
                        .resizable()
                        .frame(width: 32, height: 32)
                        .foregroundColor(.accentColor)
                    VStack(alignment: .leading, spacing: 2) {
                        localized(.About)
                            .font(.title)
                            .fontWeight(.bold)
                        HStack {
                            Text("\(String(localized: .Version)) \(appVersion) (\(String(localized: .Build)) \(appBuild))")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text(coreVersion)
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Divider()
                
                Text(String(localized: .AboutSubHead))
                    .font(.body)
                    .foregroundColor(.primary)
                
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
                    ForEach(fileLocations, id: \.self) { path in
                        Button(action: { openInFinder(path: path) }) {
                            HStack(spacing: 6) {
                                Image(systemName: "folder")
                                    .foregroundColor(.gray)
                                Text(path)
                                    .foregroundColor(.blue)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
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
        .onAppear {
            // 避免初始化时阻塞 UI
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
        .help(String(localized: .OpenInBrowser))
        .font(.callout)
        .underline()
    }
    
    // MARK: - Actions
    private func openInFinder(path: String) {
        let expandedPath = (path as NSString).expandingTildeInPath
        let url = URL(fileURLWithPath: expandedPath)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
    
    private func openLink(url: String) {
        if let url = URL(string: url) {
            NSWorkspace.shared.open(url)
        }
    }
}
