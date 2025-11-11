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
    @Published var xrayCorePath: String = AppHomePath + "/xray-core"
    @Published var isLoading = false
    @Published var versions: [GithubRelease] = []
    @Published var selectedVersion: GithubRelease?
    @Published var errorMsg: String = ""
    @Published var showDownloadDialog = false
    @Published var showAlert = false
    
    private let service: GithubServiceProtocol
    private let coreManager = CoreManager()

    init(service: GithubServiceProtocol = GithubService()) {
        self.service = service
    }

    func loadCoreVersions() {
        xrayCoreVersion = getCoreVersion()
    }
    
    func checkVersions() {
        Task { [service] in
            do {
                let releases = try await service.fetchReleases(repo: "XTLS/Xray-core")
                await MainActor.run {
                    self.versions = releases
                }
            } catch {
                await MainActor.run {
                    self.errorMsg = "Check failed: \(error.localizedDescription)"
                }
            }
        }
    }

    func downloadAndReplace(version: GithubRelease) {
        selectedVersion = version
        showDownloadDialog = true
        isLoading = true
    }

    func onDownloadSuccess(filePath: String) {
        do {
            let msg = try coreManager.replaceWithDownloaded(zipFile: filePath)
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
