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
let langStr = Locale.current.identifier
let isMainland = langStr == "zh-CN" || langStr == "zh" || langStr == "zh-Hans" || langStr == "zh-Hant"

// 手动实现检查版本下载更新 UI.
// 基于 SwiftUI + NSWindowController 实现
// 参考 UI: Sparkle(https://github.com/sparkle-project/Sparkle)
// 基于 https://github.com/yanue/V2rayU/releases 进行版本检查

@MainActor
let V2rayUpdater = AppCheckController()

// AppCheckController - 检查新版本页面

class AppCheckController: NSWindowController {
    // Declare the contentView as a property to avoid using self before super.init
    private var contentView: NSHostingView<ContentView>!
    var bindData = BindData()

    // Initialize the view and window
    init() {
        // Initialize the content view with a placeholder closure
        let contentView = NSHostingView(rootView: ContentView(
            bindData: bindData,
            closeWindow: {}
        ))

        // Create the window with specified dimensions and styles
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
                              styleMask: [.titled, .closable, .resizable],
                              backing: .buffered, defer: false)
        window.title = "Check V2rayU"
        window.contentView = contentView

        // Call the super init with the created window
        super.init(window: window)

        // Update the contentView with the actual closure after super.init
        contentView.rootView = ContentView(
            bindData: bindData,
            closeWindow: closeWindow
        )
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func windowDidLoad() {
        super.windowDidLoad()
    }

    func checkForUpdates(showWindow: Bool = false) {
        if showWindow {
            DispatchQueue.main.async {
                self.window?.orderFrontRegardless()
                self.window?.center()
                self.window?.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
            }
        } else {
            // close window
            DispatchQueue.main.async {
                self.window?.close()
            }
        }
        guard let url = URL(string: "https://api.github.com/repos/yanue/V2rayU/releases") else {
            return
        }
        logger.info("checkForUpdates: \(url)")
        let checkTask = URLSession.shared.dataTask(with: url) { data, _, error in
            if let error = error {
                logger.info("Error fetching release: \(error)")
                return
            }

            guard let data = data else {
                logger.info("No data returned")
                return
            }

            logger.info("checkForUpdates: \n \(data)")

            do {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601 // 解析日期

                // try decode data
                let data: [GithubRelease] = try decoder.decode([GithubRelease].self, from: data)

                // 按日期倒序排序
                let sortedData = data.sorted { $0.publishedAt > $1.publishedAt }

                // 取第一个
                if let release = sortedData.first {
                    logger.info("release: \(release.tagName)")
                    DispatchQueue.main.async {
                        let releaseVersion = release.tagName.replacingOccurrences(of: "v", with: "").replacingOccurrences(of: "V", with: "").trimmingCharacters(in: .whitespaces) // v4.1.0 => 4.1.0
                        // get old version
                        let appVer = appVersion.versionToInt()
                        let releaseVer = releaseVersion.versionToInt()

                        // new version is bigger than old version
                        if appVer.lexicographicallyPrecedes(releaseVer) {
                            // 点击菜单栏检查新版本,不过滤
                            if !showWindow {
                                // 如果用户选择跳过版本更新, 则不显示新版本详情页面
                                if let skipVersion = UserDefaults.standard.string(forKey: "skipAppVersion") {
                                    if skipVersion == release.tagName {
                                        logger.info("Skip version: \(skipVersion)")
                                        return
                                    }
                                }
                            }
                            // 显示新版本详情页面
                            let versionController = AppVersionController()
                            versionController.show(release: release)
                            // close window
                            self.closeWindow()
                        } else {
                            var title = "You are up to date!"
                            var toast = "V2rayU \(appVersion) is currently the newest version available."
                            if isMainland {
                                title = "当前已经是最新版了"
                                toast = "V2rayU \(appVersion) 已经是当前最新版了."
                            }
                            // open dialog
                            alertDialog(title: title, message: toast)
                            // close window
                            self.closeWindow()
                        }
                    }
                }
            } catch {
                // 可能请求太频繁了
                do {
                    let decoder = JSONDecoder()

                    // try decode data
                    let data: GithubError = try decoder.decode(GithubError.self, from: data)
                    DispatchQueue.main.async {
                        // update progress text
                        self.bindData.progressText = "Check failed: \(error)"
                        var title = "Check failed!"
                        if isMainland {
                            title = "检查失败"
                        }
                        var toast = "\(data.message)\n\(data.documentationUrl)"
                        // open dialog
                        alertDialog(title: title, message: toast)
                        // sleep 2s
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                            // close window
                            self.closeWindow()
                        }
                    }
                } catch {
                    logger.info("Error decoding JSON: \(error)")
                    DispatchQueue.main.async {
                        // update progress text
                        self.bindData.progressText = "Check failed: \(error)"
                        var title = "Check failed!"
                        var toast = "\(error)"
                        if isMainland {
                            title = "检查失败"
                            toast = "\(error)"
                        }
                        // open dialog
                        alertDialog(title: title, message: toast)
                        // sleep 2s
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                            // close window
                            self.closeWindow()
                        }
                    }
                }
            }
        }
        checkTask.resume()
    }

    func closeWindow() {
        DispatchQueue.main.async {
            self.window?.close()
        }
    }

    class BindData: ObservableObject {
        @Published var progressText = "check for updates..."
    }

    struct ContentView: View {
        @ObservedObject var bindData: BindData

        var closeWindow: () -> Void

        var body: some View {
            VStack(spacing: 20) {
                HStack {
                    Image("V2rayU")
                        .resizable()
                        .frame(width: 64, height: 64)
                        .cornerRadius(8)

                    Spacer()

                    VStack {
                        HStack {
                            ProgressView(bindData.progressText).progressViewStyle(LinearProgressViewStyle()).padding(.horizontal)
                        }

                        HStack {
                            Spacer()
                            Button(action: {
                                closeWindow()
                            }) {
                                Text("Cancel").font(.body)
                            }
                            .padding(.trailing, 20)
                        }
                    }
                }
                .padding()
            }
        }
    }
}

// AppVersionController - 新版本详情页面

class AppVersionController: NSWindowController {
    var bindData = BindData()
    private var contentView: NSHostingView<ContentView>!
    private var release: GithubRelease!

    init() {
        let contentView = NSHostingView(rootView: ContentView(
            bindData: bindData,
            skipAction: { logger.info("Skip action") },
            installAction: { logger.info("Install action") }
        ))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 500, height: 300),
                              styleMask: [.titled, .closable, .resizable],
                              backing: .buffered, defer: false)
        window.title = "V2rayU Update"
        window.contentView = contentView

        super.init(window: window)

        // Update the contentView with the actual closure after super.init
        contentView.rootView = ContentView(
            bindData: bindData,
            skipAction: skipAction,
            installAction: installAction
        )
    }

    func show(release: GithubRelease) {
        DispatchQueue.main.async {
            self.release = release
            if !isMainland {
                self.bindData.title = "A new version of V2rayU is available!"
                if release.prerelease {
                    self.bindData.description = "V2rayU \(release.tagName) preview is now available, you have \(appVersion). Would you like to download it now?"
                } else {
                    self.bindData.description = "V2rayU \(release.tagName) is now available, you have \(appVersion). Would you like to download it now?"
                }
                self.bindData.releaseNotes = release.name + "\n" + release.body
            } else {
                self.bindData.title = "V2rayU 有新版本上线了！"
                if release.prerelease {
                    self.bindData.description = "V2rayU 已上线 \(release.tagName) 预览版,您有的版本 \(appVersion) —,需要立即下载吗？"
                } else {
                    self.bindData.description = "V2rayU 已上线 \(release.tagName),您有的版本 \(appVersion) —,需要立即下载吗？"
                }
                self.bindData.releaseNotes = release.name + "\n" + release.body
                self.bindData.releaseNodesTitle = "更新日志"
                self.bindData.skipVersion = "跳过此版本"
                self.bindData.installUpdate = "安装此版本"
            }
            // bring window to front
            self.window?.orderFrontRegardless()
            // center position
            self.window?.center()
            // make window key
            self.window?.makeKeyAndOrderFront(nil)
            // activate app
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func windowDidLoad() {
        super.windowDidLoad()
    }

    // 安装新版本
    func installAction() {
        DispatchQueue.main.async {
            // 显示下载页面
            let downloadController = AppDownloadController()
            downloadController.show(release: self.release)
            // 关闭窗口
            self.window?.close()
        }
    }

    func skipAction() {
        logger.info("Skip action")
        DispatchQueue.main.async {
            // UserDefaults 记录是否跳过版本更新
            UserDefaults.standard.set(self.release.tagName, forKey: "skipAppVersion")
            // 关闭窗口
            self.window?.close()
        }
    }

    class BindData: ObservableObject {
        @Published var title = "A new version of V2rayU App is available!"
        @Published var description = ""
        @Published var releaseNotes = ""
        @Published var releaseNodesTitle = "Release Notes:"
        @Published var skipVersion = "Skip This Version!"
        @Published var installUpdate = "Install Update!"
    }

    struct ContentView: View {
        @ObservedObject var bindData: BindData
        var skipAction: () -> Void
        var installAction: () -> Void

        var body: some View {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 10) {
                    // use AppIcon.appiconset to Image
                    Image("V2rayU")
                        .resizable()
                        .frame(width: 64, height: 64)
                        .padding(.top, 20)
                        .padding(.leading, 20)

                    VStack(alignment: .leading, spacing: 5) {
                        Text(bindData.title)
                            .font(.headline)
                            .padding(.top, 20)

                        Text(bindData.description)
                            .padding(.trailing, 20)

                        Text(bindData.releaseNodesTitle)
                            .font(.headline)
                            .bold()
                            .padding(.top, 20)

                        HStack {
                            // 文字可选中
                            TextEditor(text: $bindData.releaseNotes)
                                .lineSpacing(6) // 行间距
                                .frame(height: 120)
                                .border(Color.gray, width: 1) // 黑色边框，宽度为 2
                                .fixedSize(horizontal: false, vertical: true)

                            Spacer(minLength: 20) // 右边 margin 40
                        }

                        HStack {
                            Button(bindData.skipVersion) {
                                skipAction()
                            }

                            Spacer()

                            Button(bindData.installUpdate) {
                                installAction()
                            }
                            .padding(.trailing, 20)
                            .keyboardShortcut(.defaultAction)
                        }
                        .padding(.top, 20)
                        .padding(.bottom, 20)
                    }
                }
            }
            .frame(width: 500, height: 300)
        }
    }
}

// AppDownloadController - 下载安装页面

class AppDownloadController: NSWindowController, URLSessionDownloadDelegate {
    private var contentView: NSHostingView<ContentView>!
    var bindData = BindData()
    private var downloadTask: URLSessionDownloadTask?
    private var destinationURL: URL?

    init() {
        let contentView = NSHostingView(rootView: ContentView(
            bindData: bindData,
            cancelDownload: {},
            doInstall: {}
        ))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
                              styleMask: [.titled, .closable, .resizable],
                              backing: .buffered, defer: false)
        window.title = "Download V2rayU"
        window.contentView = contentView
        super.init(window: window)

        // Update the contentView with the actual closure after super.init
        contentView.rootView = ContentView(
            bindData: bindData,
            cancelDownload: cancelDownload,
            doInstall: doInstall
        )
        self.contentView = contentView
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func windowDidLoad() {
        super.windowDidLoad()
    }

    func show(release: GithubRelease) {
        DispatchQueue.main.async {
            self.window?.orderFrontRegardless()
            self.window?.center()
            self.window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
        download(release: release)
    }

    func download(release: GithubRelease) {
        DispatchQueue.main.async {
            if let asset = release.assets.first {
                self.bindData.dmgUrl = asset.browserDownloadUrl
                logger.info("download: \(self.bindData.dmgUrl)")
                self.startDownload()
            } else {
                self.bindData.progressText = "No dmg asset found"
                return
            }
        }
    }

    private func startDownload() {
        guard let url = URL(string: bindData.dmgUrl) else {
            DispatchQueue.main.async {
                self.bindData.isDownloading = true
                self.bindData.progressText = "Invalid dmg url"
            }
            return
        }
        DispatchQueue.main.async {
            self.bindData.isDownloading = true
            self.bindData.progress = 0.0
            self.bindData.progressText = "Downloading..."
        }
        let urlSession = URLSession(configuration: .default, delegate: self, delegateQueue: OperationQueue())
        downloadTask = urlSession.downloadTask(with: url)
        downloadTask?.resume()
    }

    private func cancelDownload() {
        DispatchQueue.main.async {
            self.bindData.isDownloading = false
            self.bindData.progress = 0.0
            self.bindData.progressText = "Download canceled"
            self.downloadTask?.cancel()
            logger.info("Download canceled")
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.window?.close()
        }
    }

    func doInstall() {
        DispatchQueue.main.async {
            if let destinationURL = self.destinationURL {
                // open downloaded dmg
                NSWorkspace.shared.open(destinationURL)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    // close window
                    self.window?.close()
                    NSApplication.shared.terminate(self)
                }
            }
        }

        logger.info("Installing V2rayU: \(String(describing: destinationURL))")
    }

    // ---------------------- ui 相关 --------------------------------

    // MARK: - 下载进度数据

    class BindData: ObservableObject {
        @Published var progressText = "Downloading..."
        @Published var dmgUrl: String = ""
        @Published var progress: Float = 0.0
        @Published var isDownloading: Bool = false
    }

    // MARK: - 下载进度视图

    struct ContentView: View {
        @ObservedObject var bindData: BindData
        var cancelDownload: () -> Void
        var doInstall: () -> Void

        var body: some View {
            VStack(spacing: 20) {
                VStack(spacing: 20) {
                    HStack {
                        Image("V2rayU")
                            .resizable()
                            .frame(width: 64, height: 64)
                            .cornerRadius(8)

                        Spacer()

                        VStack {
                            HStack {
                                ProgressView(value: bindData.progress, total: 100) {
                                    Text(bindData.progressText)
                                }
                            }

                            HStack {
                                Spacer()
                                if bindData.isDownloading {
                                    Button(action: {
                                        cancelDownload()
                                    }) {
                                        Text("Cancel").font(.body)
                                    }
                                } else {
                                    Button(action: {
                                        doInstall()
                                    }) {
                                        Text("Install V2rayU").font(.body)
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
            .padding()
        }
    }

    // ---------------------- 下载相关 --------------------------------

    // MARK: - URLSessionDownloadDelegate

    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        let fileManager = FileManager.default
        let downloadsDirectory = fileManager.urls(for: .downloadsDirectory, in: .userDomainMask).first!
        let destUrl = downloadsDirectory.appendingPathComponent(downloadTask.response?.suggestedFilename ?? "V2rayU-macOS.dmg")

        do {
            logger.info("destinationURL: \(destUrl)")
            if fileManager.fileExists(atPath: destUrl.path) {
                logger.info("Download file already exists: \(destUrl.path) \(location)")
                DispatchQueue.main.async {
                    self.bindData.isDownloading = false
                    self.bindData.progress = 100.0
                    self.bindData.progressText = "Download Completed"
                    self.destinationURL = destUrl
                }
                return
            }

            try fileManager.moveItem(at: location, to: destUrl)

            DispatchQueue.main.async {
                self.bindData.isDownloading = false
                self.bindData.progress = 100.0
                self.bindData.progressText = "Download Completed"
                self.destinationURL = destUrl
            }

            logger.info("Download finished: \(destUrl)")
        } catch {
            DispatchQueue.main.async {
                self.bindData.isDownloading = false
                self.bindData.progressText = "File move error: \(error.localizedDescription)"
                self.destinationURL = destUrl
                var title = "Download failed!"
                var toast = "\(error)"
                if isMainland {
                    title = "移动文件失败"
                    toast = "\(error)"
                }
                // Ensure alertDialog function displays an alert to the user
                alertDialog(title: title, message: toast)
            }
            logger.info("File move error: \(error.localizedDescription)")
        }
    }

    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        DispatchQueue.main.async {
            self.bindData.progress = Float(totalBytesWritten) / Float(totalBytesExpectedToWrite) * 100
        }
    }

    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            DispatchQueue.main.async {
                self.bindData.isDownloading = false
                self.bindData.progressText = "Download Failed: \(error.localizedDescription)"
            }
            var title = "Download failed!"
            var toast = "\(error)"
            if isMainland {
                title = "下载文件失败"
                toast = "\(error)"
            }
            // open dialog
            alertDialog(title: title, message: toast)
            logger.info("Download error: \(error.localizedDescription)")
        }
    }
}
