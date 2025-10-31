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

@MainActor
let V2rayUpdater = AppVersionController()


enum UpdateStage {
    case checking
    case versionAvailable
    case downloading
}

@MainActor
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
            self?.window?.close()
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
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        
        // 1. 切回常规模式（显示 Dock 图标、主菜单）
        NSApp.setActivationPolicy(.regular)
        // 2. 激活应用，确保接收键盘事件
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func closeWindow(){
        window?.close()
    }

    func checkForUpdates(showWindow: Bool) {
        if showWindow {
            self.showWindow()
        } else {
            self.closeWindow()
        }
        // 开始检查
        Task { [service] in
            vm.stage = .checking
            do {
                let releases = try await service.fetchReleases(repo: "yanue/V2rayU")
                if let latest = releases.first {
                    vm.title = "A new version (\(latest.tagName)) is available!"
                    vm.description = latest.name
                    vm.releaseNotes = latest.body
                    vm.selectedRelease = latest
                    vm.stage = .versionAvailable
                } else {
                    vm.progressText = "No releases found"
                }
            } catch {
                vm.progressText = "Error: \(error.localizedDescription)"
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
