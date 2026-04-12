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
    @Published var currentPage: Int = 0

    let pageSize: Int = 5

    private let service: GithubServiceProtocol

    init(service: GithubServiceProtocol = GithubService()) {
        self.service = service
    }

    var totalPages: Int {
        guard !versions.isEmpty else { return 1 }
        return max(1, (versions.count + pageSize - 1) / pageSize)
    }

    var pagedVersions: [GithubRelease] {
        let start = currentPage * pageSize
        let end = min(start + pageSize, versions.count)
        guard start < versions.count else { return [] }
        return Array(versions[start..<end])
    }

    func goToPreviousPage() {
        if currentPage > 0 {
            currentPage -= 1
        }
    }

    func goToNextPage() {
        if currentPage < totalPages - 1 {
            currentPage += 1
        }
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
                    self.currentPage = 0
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
            let script = AppBinRoot + "/update-xray.sh"
            let msg = try runCommand(at: "/usr/bin/sudo", with: ["-n", script, filePath])
            Task { await V2rayLaunch.shared.restart() }
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
