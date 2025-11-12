//
//  AppVersionController.swift
//  V2rayU
//
//  Created by yanue on 2025/10/31.
//

import ServiceManagement
import SwiftUI

// 手动实现检查版本下载更新 UI.
// 基于 SwiftUI + NSWindowController 实现
// 参考 UI: Sparkle(https://github.com/sparkle-project/Sparkle)
// 基于 https://github.com/yanue/V2rayU/releases 进行版本检查

enum UpdateStage {
    case checking
    case versionAvailable
    case downloading
}

class AppVersionController: NSWindowController {
    private var hostingView: NSHostingView<AppVersionView>!
    private var vm = AppVersionViewModel()
    private let service = GithubService()

    override init(window: NSWindow?) {
        let view = AppVersionView(vm: vm)
        hostingView = NSHostingView(rootView: view)

        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 500, height: 300),
                              styleMask: [.titled, .closable, .resizable],
                              backing: .buffered, defer: false)
        window.title = "V2rayU Update"
        window.contentView = hostingView

        super.init(window: window)

        vm.onClose = { [weak self] in
            self?.closeWindow()
        }
        vm.onSkip = { [weak self] in
            self?.skipVersion()
        }
        vm.onInstall = { [weak self] filePath in
            self?.doInstall(filePath: filePath )
        }
        vm.onDownload = { [weak self] in
            self?.startDownload()
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    func showWindow() {
        guard let window = window else { return }
        // 更新win title
        window.title = String(localized: .V2rayUUpdateTitle)
        // 1. 确保在主线程
        DispatchQueue.main.async {

            // 2 激活应用
            NSApp.activate(ignoringOtherApps: true)
            
            // 3. 再显示窗口
            window.center()
            window.makeKeyAndOrderFront(nil)
        }
    }

    func closeWindow(){
        window?.close()
    }

    func checkForUpdates(showWindow: Bool) {
        logger.info("checkForUpdates: \(showWindow)")
        // 设置stage
        vm.stage = .checking
        vm.checkError = nil
        if showWindow {
            self.showWindow()
        } else {
            self.closeWindow()
        }
        
        // 开始检查
        Task { [service] in
            //
            do {
                let releases = try await service.fetchReleases(repo: "yanue/V2rayU")
                if let release = releases.first {
                    logger.info("checkForUpdates-lateast: release=\(release.tagName) body=\(release.body)")
                    let releaseVersion = release.tagName.replacingOccurrences(of: "v", with: "").replacingOccurrences(of: "V", with: "").trimmingCharacters(in: .whitespaces) // v4.1.0 => 4.1.0
                    // get old version
                    let appVer = appVersion.versionToInt()
                    let releaseVer = releaseVersion.versionToInt()

                    // new version is bigger than old version
                    if appVer.lexicographicallyPrecedes(releaseVer) {
                        // 如果用户选择跳过版本更新, 则不显示新版本详情页面
                        if let skipVersion = UserDefaults.standard.string(forKey: "skipAppVersion") {
                            if skipVersion == release.tagName {
                                // 后台检查时,过滤不显示窗口
                                if !showWindow {
                                    logger.info("checkForUpdates-Skip: release=\(release.tagName) skipVersion=\(skipVersion)")
                                    return
                                }
                            }
                        }
                        await MainActor.run {
                            // 新版本
                            vm.title = String(localized: .NewVersionTip, arguments: release.tagName)
                            vm.description = release.name
                            vm.releaseNotes = release.body
                            vm.selectedRelease = release
                            vm.stage = .versionAvailable
                            logger.info("checkForUpdates-newVersion: release=\(release.tagName) body=\(release.body)")
                            
                            // 有新版本, 显示窗口
                            self.showWindow()
                        }
                    } else {
                        await MainActor.run {
                            vm.checkError = String(localized: .AlreadyLastestToast,arguments: appVersion)
                            if showWindow {
                                let title = String(localized: .AlreadyLastestVersion)
                                let toast = String(localized: .AlreadyLastestToast,arguments: appVersion)
                                alertDialog(title: title,message:toast)
                            }
                        }
                        logger.info("checkForUpdates-no need: release=\(release.tagName) body=\(release.body)")
                    }
                } else {
                    logger.info("checkForUpdates-no found: No releases found")
                    await MainActor.run {
                        vm.checkError = "No releases found"
                    }
                }
            } catch {
                logger.info("checkForUpdates-error: \(error.localizedDescription)")
                await MainActor.run {
                    vm.checkError = error.localizedDescription
                }
            }
        }
    }

    private func skipVersion() {
        if let tag = vm.selectedRelease?.tagName {
            UserDefaults.standard.set(tag, forKey: "skipAppVersion")
        }
        self.closeWindow()
    }

    private func startDownload() {
        vm.stage = .downloading
    }
    
    private func doInstall(filePath: String) {
        NSWorkspace.shared.open(URL(fileURLWithPath: filePath))
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            // close window
            self.window?.close()
            NSApplication.shared.terminate(self)
        }
    }
}
