//
//  AppVersion.swift
//  V2rayU
//
//  Created by yanue on 2024/6/30.
//  Copyright © 2024 yanue. All rights reserved.
//
import ServiceManagement
import SwiftUI

let appVersion = getAppVersion()
let coreVersion = getCoreShortVersion()
let langStr = Locale.current.identifier
let isMainland = langStr == "zh-CN" || langStr == "zh" || langStr == "zh-Hans" || langStr == "zh-Hant"

// 手动实现检查版本下载更新 UI.
// 基于 SwiftUI + NSWindowController 实现
// 参考 UI: Sparkle(https://github.com/sparkle-project/Sparkle)
// 基于 https://github.com/yanue/V2rayU/releases 进行版本检查

@MainActor
let V2rayUpdater = AppCheckController()

// AppCheckController - 检查新版本页面

/// 🚀 控制器层 - 负责业务逻辑与窗口控制
class AppCheckController: NSWindowController {
    private var hostingView: NSHostingView<AppCheckView>!
    private var viewModel = AppCheckViewModel()

    override init(window: NSWindow?) {
        // 初始化 SwiftUI 界面
        let view = AppCheckView(viewModel: viewModel)
        hostingView = NSHostingView(rootView: view)

        // 创建 window
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 200),
                              styleMask: [.titled, .closable],
                              backing: .buffered,
                              defer: false)
        window.title = "Check V2rayU"
        window.contentView = hostingView

        super.init(window: window)

        // 绑定 ViewModel 回调
        viewModel.onClose = { [weak self] in self?.closeWindow() }
        viewModel.onCheckUpdates = { [weak self] in self?.performCheckForUpdates() }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// 显示窗口
    func showWindow() {
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// 关闭窗口
    func closeWindow() {
        window?.close()
    }

    /// 实际检查更新的逻辑方法（由 ViewModel 触发）
    private func performCheckForUpdates() {
        viewModel.progressText = "Checking for updates..."
        // TODO: 调用 Github API 检查更新
        // 更新完成后修改 viewModel.progressText 以驱动 UI
    }
}

/// 🚀 控制器层 - 负责响应用户动作与版本更新逻辑
class AppVersionController: NSWindowController {
    private var hostingView: NSHostingView<AppVersionView>!
    private var viewModel = AppVersionViewModel()

    private var release: GithubRelease?

    override init(window: NSWindow?) {
        let view = AppVersionView(viewModel: viewModel)
        hostingView = NSHostingView(rootView: view)

        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 500, height: 300),
                              styleMask: [.titled, .closable, .resizable],
                              backing: .buffered, defer: false)
        window.title = "V2rayU Update"
        window.contentView = hostingView

        super.init(window: window)

        // 绑定按钮回调
        viewModel.onSkip = { [weak self] in self?.skipVersion() }
        viewModel.onInstall = { [weak self] in self?.installUpdate() }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// 显示窗口并更新 release 信息
    func show(release: GithubRelease) {
        self.release = release
        // 更新 ViewModel
        DispatchQueue.main.async {
            self.viewModel.title = "A new version (\(release.tagName)) is available!"
            self.viewModel.description = release.name
            self.viewModel.releaseNotes = release.body
            self.window?.center()
            self.window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    /// 跳过版本逻辑
    private func skipVersion() {
        if let tag = release?.tagName {
            UserDefaults.standard.set(tag, forKey: "skipAppVersion")
        }
        window?.close()
    }

    /// 安装逻辑
    private func installUpdate() {
        guard let release = release else { return }
        let downloadController = AppDownloadController()
        downloadController.show(release: release)
        window?.close()
    }
}

/// 🚀 AppDownloadController - 控制下载、安装流程
class AppDownloadController: NSWindowController {
    private var hostingView: NSHostingView<AppDownloadView>!
    private var viewModel = AppDownloadViewModel()
    private var downloader = DownloadManager()

    private var downloadTask: URLSessionDownloadTask?
    private var destinationURL: URL?

    override init(window: NSWindow?) {
        let view = AppDownloadView(viewModel: viewModel)
        hostingView = NSHostingView(rootView: view)

        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 200),
                              styleMask: [.titled, .closable],
                              backing: .buffered, defer: false)
        window.title = "Download V2rayU"
        window.contentView = hostingView

        super.init(window: window)

        // 绑定回调
        viewModel.onCancel = { [weak self] in self?.cancelDownload() }
        viewModel.onInstall = { [weak self] in self?.installDownloadedFile() }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func show(release: GithubRelease) {
        self.window?.center()
        self.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        startDownload(for: release)
    }

    // MARK: - 下载逻辑
    private func startDownload(for release: GithubRelease) {
        guard let asset = release.assets.first,
              let url = URL(string: asset.browserDownloadUrl) else {
            viewModel.progressText = "Invalid download URL"
            return
        }

        viewModel.isDownloading = true
        viewModel.progress = 0.0
        viewModel.progressText = "Downloading..."

        let session = URLSession(configuration: .default, delegate: self, delegateQueue: OperationQueue())
        downloadTask = session.downloadTask(with: url)
        downloadTask?.resume()
    }

    private func cancelDownload() {
        downloadTask?.cancel()
        viewModel.isDownloading = false
        viewModel.progressText = "Download canceled"
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.window?.close()
        }
    }

    private func installDownloadedFile() {
        guard let url = destinationURL else { return }
        NSWorkspace.shared.open(url)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.window?.close()
            NSApplication.shared.terminate(self)
        }
    }

    // MARK: - URLSessionDownloadDelegate

    nonisolated func urlSession(_ session: URLSession,
                                downloadTask: URLSessionDownloadTask,
                                didWriteData bytesWritten: Int64,
                                totalBytesWritten: Int64,
                                totalBytesExpectedToWrite: Int64) {
        let percent = Float(totalBytesWritten) / Float(totalBytesExpectedToWrite) * 100
        DispatchQueue.main.async {
            self.viewModel.progress = percent
        }
    }

    nonisolated func urlSession(_ session: URLSession,
                                downloadTask: URLSessionDownloadTask,
                                didFinishDownloadingTo location: URL) {
        let fileManager = FileManager.default
        let downloadDir = fileManager.urls(for: .downloadsDirectory, in: .userDomainMask).first!
        let destUrl = downloadDir.appendingPathComponent(downloadTask.response?.suggestedFilename ?? "V2rayU.dmg")

        do {
            if fileManager.fileExists(atPath: destUrl.path) {
                try fileManager.removeItem(at: destUrl)
            }
            try fileManager.moveItem(at: location, to: destUrl)
            DispatchQueue.main.async {
                self.destinationURL = destUrl
                self.viewModel.isDownloading = false
                self.viewModel.progress = 100
                self.viewModel.progressText = "Download completed"
            }
        } catch {
            DispatchQueue.main.async {
                self.viewModel.progressText = "Download error: \(error.localizedDescription)"
                self.viewModel.isDownloading = false
            }
        }
    }
}
