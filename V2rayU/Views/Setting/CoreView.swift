//
//  CoreView.swift
//  V2rayU
//
//  Created by yanue on 2025/7/20.
//

import SwiftUI

struct CoreView: View {
    @State private var xrayCoreVersion: String = "Unknown"
    @State private var xrayCorePath: String = AppHomePath + "/xray-core"
    @State private var isLoading: Bool = false
    @State private var versions: [GithubRelease] = []
    @State private var errorMsg: String? = nil
    @State private var showDownloadDialog = false
    @State private var downloadingVersion: String = ""
    @State private var downloadingUrl: String = ""
    @State private var downloadProgress: Double = 0.0
    @State private var downloadSpeed: String = "0.0 KB/s"
    @State private var downloadSize: String = "0.0 MB"
    @State private var downloadTargetSize: String = "0.0 MB"
    @State private var is_end: Bool = false
    @State private var downloadDelegate: DownloadDelegate? = nil
    @State private var showAlert = false

    var body: some View {
        VStack(spacing: 8) {
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
                .disabled(isLoading)
            }
            
            Spacer(minLength: 6)

            Section {
                HStack {
                    Text("本地 Xray Core 目录")
                        .font(.headline)
                    Spacer()
                }
                Divider()
                HStack {
                    Text("文件目录: ")
                    Text("\(xrayCorePath)")
                    Spacer()
                }
            }
            
            Spacer(minLength: 6)

            Section {
                HStack {
                    Text("本地 Xray Core 版本明细")
                        .font(.headline)
                    Spacer()
                }
                Divider()
                HStack {
                    Text(getArch())
                    Text(xrayCoreVersion)
                    Spacer()
                }
            }
            
            Spacer(minLength: 6)

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
            
            if showDownloadDialog {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "arrow.down.circle.fill")
                            .foregroundColor(.accentColor)
                            .font(.title2)
                        VStack(alignment: .leading) {
                            Text("正在下载: \(downloadingVersion)")
                                .font(.headline)
                            Text(downloadingUrl)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        Spacer()
                        Button(action: {
                            openInBrowser(downloadingUrl)
                        }) {
                            Label("浏览器打开", systemImage: "safari")
                        }
                        .buttonStyle(.bordered)
                    }
                    VStack(alignment: .leading) {
                        HStack {
                            Text(String(format: "%.1f%%", downloadProgress * 100))
                                .font(.headline)
                                .frame(width: 60, alignment: .leading)
                            Text("已下载: \(downloadSize) / 总大小: \(downloadTargetSize)")
                                .font(.callout)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(downloadSpeed)
                                .font(.subheadline)
                                .foregroundColor(.blue)
                        }
                        ProgressView(value: downloadProgress)
                            .progressViewStyle(LinearProgressViewStyle())
                            .frame(height: 10)
                            .accentColor(.accentColor)
                        HStack {
                            if self.errorMsg != nil {
                                Text(self.errorMsg!)
                                    .foregroundColor(.red)
                            }
                            Spacer()
                            if is_end {
                                Button(action: {
                                    closeDownloadDialog()
                                }) {
                                    Label("关闭", systemImage: "xmark.circle")
                                        .font(.body)
                                }
                                .buttonStyle(.borderedProminent)
                            } else {
                                Button(action: {
                                    cancelDownload()
                                }) {
                                    Label("取消下载", systemImage: "xmark.circle")
                                        .font(.body)
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        }
                    }
                }
                .padding() // 1. 内边距
                .background() // 2. 然后背景
                .clipShape(RoundedRectangle(cornerRadius: 8)) // 3. 内圆角
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                        .shadow(color: Color.primary.opacity(0.1), radius: 1, x: 0, y: 1)
                ) // 4. 添加边框和阴影
            }

        }.onAppear {
            loadCoreVersions()
            checkVersions()
        }
        .alert(isPresented: $showAlert) {
            Alert(title: Text("下载提示"), message: Text(errorMsg ?? ""), dismissButton: .default(Text("确定")))
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
        showDownloadDialog = true
        is_end = false
        errorMsg = nil
        downloadingVersion = version.tagName
        downloadProgress = 0.0
        downloadSpeed = "0.0 KB/s"
        downloadSize = ""
        downloadTargetSize = ""

        let asset = version.getDownloadAsset()
        print("downloadAndReplace: \(asset)")
        guard let url = URL(string: asset.browserDownloadUrl) else {
            errorMsg = "下载地址错误: \(asset.browserDownloadUrl)"
            isLoading = false
            downloadingVersion = ""
            return
        }
        downloadingUrl = asset.browserDownloadUrl
        downloadTargetSize = formatByte(Double(asset.size))
        
        let config = getProxyUrlSessionConfigure()

        let delegate = DownloadDelegate(
            timeout: 10,
            onProgress: { progress, speed, _downloadSize in
                DispatchQueue.main.async {
                    self.downloadSpeed = speed
                    self.downloadProgress = progress
                    self.downloadSize = _downloadSize
                }
            },
            onSuccess: { filePath in
                self.downloadDone(zipFile: filePath)
                self.showAlert = true
                self.isLoading = false
                self.is_end = true
                self.downloadingVersion = ""
                self.downloadDelegate = nil
            },
            onError: { msg in
                self.isLoading = false
                self.is_end = true
                self.downloadingVersion = ""
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
        is_end =  true
        downloadDelegate?.cancelTask()
        isLoading = false
        downloadingVersion = ""
        errorMsg = "下载已取消"
    }
    
    private func closeDownloadDialog() {
        self.showDownloadDialog = false
    }
    
    private func backupCore() {
        let backupPath = v2rayCorePath + ".bak"
        // 备份当前文件
        if FileManager.default.fileExists(atPath: v2rayCorePath) {
            try? FileManager.default.removeItem(atPath: backupPath)
            try? FileManager.default.copyItem(atPath: v2rayCorePath, toPath: backupPath)
        }
    }
    
    private func recoverCore(_ msg: String){
        let backupPath = v2rayCorePath + ".bak"
        // 恢复备份
        if FileManager.default.fileExists(atPath: backupPath) {
            try? FileManager.default.removeItem(atPath: v2rayCorePath)
            try? FileManager.default.copyItem(atPath: backupPath, toPath: v2rayCorePath)
        }
        self.errorMsg = msg
    }
    
    private func downloadDone(zipFile: String) {
        print("downloadDone", zipFile)
        let destPath = AppHomePath + "/xray-core"
        let backupPath = destPath + ".bak"

        // 备份 core
        self.backupCore()
        
        do {
            // 确保解压目录存在
            let msg = try runCommand(at: "/usr/bin/unzip", with: ["-o", zipFile, "-d", destPath] )
            
            // 设置权限
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: destPath)
            
            // 重启v2ray
            V2rayLaunch.restartV2ray()
            
            self.errorMsg = "替换成功！\n\(msg)"
        } catch {
            // 恢复备份
            self.recoverCore("操作失败: \(error.localizedDescription)")
        }
        
        // 清理临时文件和备份
        try? FileManager.default.removeItem(atPath: backupPath)
        try? FileManager.default.removeItem(atPath: zipFile)
    }
}
