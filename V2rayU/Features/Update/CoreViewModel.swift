//
//  CoreViewModel.swift
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
    @Published var currentPage: Int = 1
    @Published var hasMorePages: Bool = true

    let perPage: Int = 5

    private let service: GithubServiceProtocol

    init(service: GithubServiceProtocol = GithubService()) {
        self.service = service
    }

    func loadCoreVersions() {
        xrayCoreVersion = getCoreVersion()
    }

    func fetchPage(_ page: Int) {
        guard !isLoading else { return }
        isLoading = true
        Task {
            do {
                let releases = try await service.fetchReleases(repo: "XTLS/Xray-core", page: page, perPage: perPage)
                self.versions = releases
                self.currentPage = page
                self.hasMorePages = releases.count >= perPage
            } catch {
                self.errorMsg = String(localized: .OperationFailed, arguments: error.localizedDescription)
                self.showAlert = true
            }
            self.isLoading = false
        }
    }

    func goToPreviousPage() {
        guard currentPage > 1 else { return }
        fetchPage(currentPage - 1)
    }

    func goToNextPage() {
        guard hasMorePages else { return }
        fetchPage(currentPage + 1)
    }

    func downloadAndReplace(version: GithubRelease) {
        selectedVersion = version
        showDownloadDialog = true
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
        showDownloadDialog = false
    }

    func onDownloadFail(err: String) {
        errorMsg = err
        showAlert = true
        showDownloadDialog = false
    }

    func closeDownloadDialog() {
        showDownloadDialog = false
    }
}
