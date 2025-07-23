//
//  CoreView.swift
//  V2rayU
//
//  Created by yanue on 2025/7/20.
//

import SwiftUI

struct CoreView: View {
    @State private var xrayCoreVersion: String = "Unknown"
    @State private var isLoading: Bool = false
    @State private var versions: [GithubRelease] = []
    @State private var errorMsg: String? = nil
    @State private var downloadingVersion: String? = nil
    @State private var downloadingUrl: String? = nil
    @State private var downloadProgress: Double = 0.0
    @State private var downloadSpeed: String = "0.0 KB/s"
    @State private var downloadSize: String = "0.0 MB"
    @State private var downloadDelegate: DownloadDelegate? = nil

    var body: some View {
        VStack {
            HStack {
                Image(systemName: "crown")
                    .resizable()
                    .frame(width: 28, height: 28)
                    .foregroundColor(.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Core Settings")
                        .font(.title)
                        .fontWeight(.bold)
                    Text("Manage your core versions")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button(action: { checkVersions() }) {
                    Label("检查最新版本", systemImage: "arrow.triangle.2.circlepath")
                }
                .buttonStyle(.borderedProminent)
                .padding()
                .disabled(isLoading)
            }
            .padding()
            Section {
                HStack {
                    Text("本地 Xray Core 版本明细")
                        .font(.headline)
                    Spacer()
                }
                Divider()
                HStack {
                    Text("arm64: ")
                    Text(xrayCoreVersion)
                    Spacer()
                }
            }

            List {
                if !versions.isEmpty {
                    Section(header: Text("GitHub 最新版本")) {
                        ForEach(versions, id: \ .self) { version in
                            HStack {
                                Text(version.tagName)
                                    .font(.title3)
                                Text("\(version.formattedPublishedAt)")
                                    .font(.callout)
                                Spacer()
                                Button(action: {
                                    downloadAndReplace(version: version)
                                }) {
                                    Text("下载并替换")
                                }
                                .disabled(isLoading)
                            }
                        }
                    }
                }
            }
            .listStyle(PlainListStyle())
            if let errorMsg = errorMsg {
                Text(errorMsg)
                    .foregroundColor(.red)
                    .padding(.bottom, 4)
            }
            if let downloadingUrl = downloadingUrl {
                HStack {
                    Text("下载地址")
                    Text(downloadingUrl)
                    Button(action: {
                        openInBrowser(downloadingUrl)
                    }) {
                        Text("浏览器打开")
                    }
                }
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(String(format: "%.1f%%", downloadProgress * 100))
                            .font(.headline)
                        Spacer()
                        Text(downloadSpeed)
                            .font(.subheadline)
                        Text(downloadSize)
                            .font(.callout)
                    }
                    ProgressView(value: downloadProgress)
                        .progressViewStyle(LinearProgressViewStyle())
                        .frame(height: 8)
                    HStack {
                        Spacer()
                        Button(action: {
                            cancelDownload()
                        }) {
                            Text("取消下载").font(.body)
                        }
                        .buttonStyle(.bordered)
                    }
                }.padding(.horizontal)
            }

        }.onAppear {
            loadCoreVersions()
            checkVersions()
        }
    }

    private func loadCoreVersions() {
        xrayCoreVersion = getCoreVersion()
    }

    func checkVersions() {
        guard let url = URL(string: "https://api.github.com/repos/XTLS/Xray-core/releases?per_page=20") else {
            return
        }
        isLoading = true

        print("checkForUpdates: \(url)")
        let checkTask = URLSession.shared.dataTask(with: url) { data, _, error in
            DispatchQueue.main.async {
                self.isLoading = false
            }
            if let error = error {
                print("Error fetching release: \(error)")
                return
            }

            guard let data = data else {
                print("No data returned")
                return
            }

            print("checkForUpdates: \n \(data)")

            do {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601 // 解析日期

                // try decode data
                let data: [GithubRelease] = try decoder.decode([GithubRelease].self, from: data)

                // 按日期倒序排序
                let sortedData = data.sorted { $0.publishedAt > $1.publishedAt }
                DispatchQueue.main.async {
                    self.versions = sortedData
                }
            } catch {
                // 可能请求太频繁了
                do {
                    let decoder = JSONDecoder()
                    // try decode data
                    let data: GithubError = try decoder.decode(GithubError.self, from: data)
                    DispatchQueue.main.async {
                        // update progress text
                        self.errorMsg = "Check failed: \(data.message)\n\(data.documentationUrl)"
                    }
                } catch {
                    print("Error decoding JSON: \(error)")
                    DispatchQueue.main.async {
                        self.errorMsg = "Check failed: \(error)"
                    }
                }
            }
        }
        checkTask.resume()
    }

    private func downloadAndReplace(version: GithubRelease) {
        isLoading = true
        errorMsg = nil
        downloadingVersion = version.tagName
        downloadProgress = 0.0
        downloadSpeed = "0.0 KB/s"
        downloadSize = ""

        let asset = version.getDownloadAsset()
        let arch = getArch()
        print("downloadAndReplace: \(asset)")
        guard let url = URL(string: asset.browserDownloadUrl) else {
            errorMsg = "下载地址错误: \(asset.browserDownloadUrl)"
            isLoading = false
            downloadingVersion = nil
            return
        }
        downloadingUrl = asset.browserDownloadUrl
        downloadSize = formatByte(Double(asset.size))
        let destPath = v2rayCorePath
        let backupPath = destPath + ".bak"
        let unzipDir = AppHomePath + "/unzip_tmp_\(arch)"
        if FileManager.default.fileExists(atPath: destPath) {
            try? FileManager.default.removeItem(atPath: backupPath)
            try? FileManager.default.copyItem(atPath: destPath, toPath: backupPath)
        }
        let config = getProxyUrlSessionConfigure()

        let delegate = DownloadDelegate(
            timeout: 10,
            onProgress: { progress, speed in
                DispatchQueue.main.async {
                    self.downloadSpeed = speed
                    self.downloadProgress = progress
                }
            },
            onSuccess: { location in
                // 解压 zip
                do {
                    try? FileManager.default.createDirectory(atPath: unzipDir, withIntermediateDirectories: true)
                    let process = Process()
                    process.launchPath = "/usr/bin/unzip"
                    process.arguments = [location.path, "-d", unzipDir]
                    process.launch()
                    process.waitUntilExit()
                    let newCorePath = unzipDir + "/xray"
                    if FileManager.default.fileExists(atPath: newCorePath) {
                        do {
                            try FileManager.default.removeItem(atPath: destPath)
                            try FileManager.default.copyItem(atPath: newCorePath, toPath: destPath)
                            try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: destPath)
                            self.errorMsg = "替换成功！"
                            self.loadCoreVersions()
                        } catch {
                            self.errorMsg = "替换失败: \(error.localizedDescription)"
                            // 恢复备份
                            if FileManager.default.fileExists(atPath: backupPath) {
                                try? FileManager.default.removeItem(atPath: destPath)
                                try? FileManager.default.copyItem(atPath: backupPath, toPath: destPath)
                            }
                        }
                    } else {
                        self.errorMsg = "解压失败，未找到 xray 文件"
                        // 恢复备份
                        if FileManager.default.fileExists(atPath: backupPath) {
                            try? FileManager.default.removeItem(atPath: destPath)
                            try? FileManager.default.copyItem(atPath: backupPath, toPath: destPath)
                        }
                    }
                    // 清理临时文件
                    try? FileManager.default.removeItem(atPath: unzipDir)
                    try? FileManager.default.removeItem(atPath: location.path)
                } catch {
                    self.errorMsg = "下载后处理失败: \(error.localizedDescription)"
                }
                self.isLoading = false
                self.downloadingVersion = nil
                self.downloadDelegate = nil
            },
            onError: { msg in
                self.isLoading = false
                self.downloadingVersion = nil
                self.errorMsg = msg
                self.downloadDelegate = nil
            }
        )
        downloadDelegate = delegate
        let session = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
        let task = session.downloadTask(with: url)
        delegate.startTimeout(downloadTask: task)
        task.resume()
    }

    func openInBrowser(_ urlStr: String) {
        guard let url = URL(string: urlStr) else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    private func cancelDownload() {
        downloadDelegate?.cancelTask()
        isLoading = false
        downloadingVersion = nil
        downloadingUrl = nil
        errorMsg = "下载已取消"
    }
}
