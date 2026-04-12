//
//  CoreView.swift
//  V2rayU
//
//  Created by yanue on 2025/10/31.
//

import SwiftUI

@MainActor
final class CoreViewModel: ObservableObject {
    @Published var xrayCoreVersion: String = "Unknown"
    @Published var xrayCorePath: String = V2rayU.xrayCorePath
    @Published var isLoading = false
    @Published var versions: [GithubRelease] = []
    @Published var selectedVersion: GithubRelease?
    @Published var errorMsg: String = ""
    @Published var showDownloadDialog = false
    @Published var showAlert = false
    
    @Published var currentPage = 1
    @Published var hasMorePages = true
    let perPage = 10
    
    private let service: GithubServiceProtocol

    init(service: GithubServiceProtocol = GithubService()) {
        self.service = service
    }

    func loadCoreVersions() {
        xrayCoreVersion = getCoreShortVersion()
    }
    
    func checkVersions(reset: Bool = false) {
        guard !isLoading else { return }
        
        if reset {
            currentPage = 1
            versions = []
            hasMorePages = true
        }
        
        isLoading = true
        Task { [service] in
            do {
                let releases = try await service.fetchReleases(repo: "XTLS/Xray-core", page: currentPage, perPage: perPage)
                await MainActor.run {
                    if self.currentPage == 1 {
                        self.versions = releases
                    } else {
                        self.versions.append(contentsOf: releases)
                    }
                    self.hasMorePages = releases.count == self.perPage
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMsg = "Check failed: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
    
    func loadNextPage() {
        guard hasMorePages, !isLoading else { return }
        currentPage += 1
        checkVersions()
    }
    
    func loadPreviousPage() {
        guard currentPage > 1, !isLoading else { return }
        currentPage -= 1
        checkVersions()
    }

    func downloadAndReplace(version: GithubRelease) {
        selectedVersion = version
        showDownloadDialog = true
        isLoading = true
    }

    func onDownloadSuccess(filePath: String) {
        do {
            let script = AppBinRoot + "/update-xray.sh"
            let msg = try runCommand(at: "/usr/bin/sudo", with: ["-n", script, filePath])
            Task { await V2rayLaunch.shared.restart() }
            // 更新当前core版本
            xrayCoreVersion = getCoreVersion()
            // 更新 AppMenu 菜单栏中显示的 Xray-core 版本
            AppMenuManager.shared.refreshAllMenus()
            errorMsg = String(localized: .ReplaceSuccess) + "\n" + msg
        } catch {
            errorMsg = error.localizedDescription
        }
        showAlert = true
        isLoading = false
        showDownloadDialog = false
    }

    func onDownloadFail(err: String) {
        errorMsg = err
        showAlert = true
        isLoading = false
        showDownloadDialog = false
    }

    func closeDownloadDialog() {
        showDownloadDialog = false
    }
}
