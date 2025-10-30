//
//  CoreView.swift
//  V2rayU
//
//  Created by yanue on 2025/7/20.
//

import SwiftUI
import Foundation

struct CoreView: View {
    @State private var xrayCoreVersion: String = "Unknown"
    @State private var xrayCorePath: String = AppHomePath + "/xray-core"
    @State private var isLoading: Bool = false
    @State private var versions: [GithubRelease] = []
    @State private var version: GithubRelease?
    @State private var errorMsg: String = ""
    @State private var showDownloadDialog = false
    @State private var is_end: Bool = false
    @State private var showAlert = false
    
    var body: some View {
        VStack(spacing: 8) {
            // 顶部标题行
            HStack {
                Image(systemName: "crown")
                    .resizable()
                    .frame(width: 28, height: 28)
                    .foregroundColor(.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    // 标题
                    Text(String(localized: .CoreSettingsTitle))
                        .font(.title)
                        .fontWeight(.bold)
                    Text(String(localized: .CoreSettingsSubtitle))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button(action: { checkVersions() }) {
                    Label(String(localized: .CheckLatestVersion), systemImage: "arrow.triangle.2.circlepath")
                }
                .buttonStyle(.borderedProminent)
                .disabled(isLoading)
            }

            Spacer(minLength: 6)

            // 本地路径部分
            Section {
                HStack {
                    Text(String(localized: .LocalCoreDirectory))
                        .font(.headline)
                    Spacer()
                }
                Divider()
                HStack {
                    Text(String(localized: .FileDirectory))
                    Text("\(xrayCorePath)")
                    Spacer()
                }
            }

            Spacer(minLength: 6)

            // 本地版本信息
            Section {
                HStack {
                    Text(String(localized: .LocalCoreVersionDetail))
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

            // GitHub 最新版本列表
            List {
                if !versions.isEmpty {
                    Section(header: Text(String(localized: .GithubLatestVersion))) {
                        ForEach(versions, id: \.self) { version in
                            HStack {
                                Text(version.tagName)
                                    .font(.title3)
                                Text("\(version.formattedPublishedAt)")
                                    .font(.callout)
                                Spacer()
                                Button(action: {
                                    downloadAndReplace(version: version)
                                }) {
                                    Text(String(localized: .DownloadAndReplace))
                                }
                                .disabled(isLoading)
                            }
                        }
                    }
                }
            }
            .listStyle(PlainListStyle())

            // 下载弹窗
            if showDownloadDialog {
                DownloadView(
                    version: version!,
                    onDownloadSuccess: { filePath in
                        self.onDownloadSuccess(filePath: filePath)
                    },
                    onDownloadFail: { err in
                        self.onDownloadFail(err: err)
                    },
                    closeDownloadDialog: closeDownloadDialog
                )
            }

        }
        .onAppear {
            loadCoreVersions()
            checkVersions()
        }
        // 弹窗提示
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text(String(localized: .DownloadHint)),
                message: Text(errorMsg),
                dismissButton: .default(Text(String(localized: .Confirm)))
            )
        }
    }

    // MARK: - 加载本地 core 版本
    private func loadCoreVersions() {
        xrayCoreVersion = getCoreVersion()
    }

    // MARK: - 检查 GitHub 最新版本
    func checkVersions() {
        guard let url = URL(string: "https://api.github.com/repos/XTLS/Xray-core/releases?per_page=20") else {
            return
        }
        isLoading = true

        let checkTask = URLSession.shared.dataTask(with: url) { data, _, error in
            DispatchQueue.main.async {
                self.isLoading = false
            }
            if let error = error {
                logger.info("Error fetching release: \(error)")
                return
            }

            guard let data = data else {
                logger.info("No data returned")
                return
            }

            do {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let data: [GithubRelease] = try decoder.decode([GithubRelease].self, from: data)
                let sortedData = data.sorted { $0.publishedAt > $1.publishedAt }
                DispatchQueue.main.async {
                    self.versions = sortedData
                }
            } catch {
                // 可能请求太频繁了
                do {
                    let decoder = JSONDecoder()
                    let data: GithubError = try decoder.decode(GithubError.self, from: data)
                    DispatchQueue.main.async {
                        self.errorMsg = "Check failed: \(data.message)\n\(data.documentationUrl)"
                    }
                } catch {
                    logger.info("Error decoding JSON: \(error)")
                    DispatchQueue.main.async {
                        self.errorMsg = "Check failed: \(error)"
                    }
                }
            }
        }
        checkTask.resume()
    }

    private func onDownloadSuccess(filePath: String) {
        self.downloadDone(zipFile: filePath)
        self.showAlert = true
        self.isLoading = false
        self.is_end = true
    }

    private func onDownloadFail(err: String) {
        self.isLoading = false
        self.is_end = true
        self.errorMsg = ""
    }

    // MARK: - 下载并替换
    private func downloadAndReplace(version: GithubRelease) {
        self.version = version
        isLoading = true
        showDownloadDialog = true
        is_end = true
        errorMsg = ""
    }

    // MARK: - 关闭下载面板
    private func closeDownloadDialog() {
        self.showDownloadDialog = false
    }

    // MARK: - 备份核心文件
    private func backupCore() {
        let backupPath = v2rayCorePath + ".bak"
        if FileManager.default.fileExists(atPath: v2rayCorePath) {
            try? FileManager.default.removeItem(atPath: backupPath)
            try? FileManager.default.copyItem(atPath: v2rayCorePath, toPath: backupPath)
        }
    }

    // MARK: - 还原备份
    private func recoverCore(_ msg: String){
        let backupPath = v2rayCorePath + ".bak"
        if FileManager.default.fileExists(atPath: backupPath) {
            try? FileManager.default.removeItem(atPath: v2rayCorePath)
            try? FileManager.default.copyItem(atPath: backupPath, toPath: v2rayCorePath)
        }
        self.errorMsg = msg
    }

    // MARK: - 下载完成后进行替换
    private func downloadDone(zipFile: String) {
        let destPath = AppHomePath + "/xray-core"
        let backupPath = destPath + ".bak"

        self.backupCore()

        do {
            // 解压文件
            let msg = try runCommand(at: "/usr/bin/unzip", with: ["-o", zipFile, "-d", destPath])
            // 设置执行权限
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: destPath)
            // 重启
            Task { await V2rayLaunch.shared.restart() }
            self.errorMsg = String(localized: .ReplaceSuccess) + "\n" + msg
        } catch {
            self.recoverCore(String(localized: .OperationFailed) + ": \(error.localizedDescription)")
        }
        try? FileManager.default.removeItem(atPath: backupPath)
        try? FileManager.default.removeItem(atPath: zipFile)
    }
}
