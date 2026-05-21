//
//  CoreViewModel.swift
//  V2rayU
//
//  Created by yanue on 2025/10/31.
//

import SwiftUI

@MainActor
final class CoreViewModel: ObservableObject {
    struct CapabilityRulesDisplayItem {
        let title: String
        let source: String
        let reviewedVersion: String
        let capabilityCount: Int
        let path: String?
    }

    @Published var xrayCoreVersion: String = "Unknown"
    @Published var xrayCorePath: String = V2rayU.xrayCorePath
    @Published var isLoading = false
    @Published var isUpdatingCapabilityRules = false
    @Published var versions: [GithubRelease] = []
    @Published var selectedVersion: GithubRelease?
    @Published var errorMsg: String = ""
    @Published var showDownloadDialog = false
    @Published var showAlert = false
    @Published var currentPage: Int = 1
    @Published var hasMorePages: Bool = true
    @Published var capabilityRulesBaseURL: String = UserDefaults.get(forKey: .capabilityRulesBaseURL, defaultValue: defaultCapabilityRulesBaseURL)
    @Published var xrayCapabilityRulesStatus: CapabilityRulesDisplayItem?
    @Published var singboxCapabilityRulesStatus: CapabilityRulesDisplayItem?
    @Published var coreSelections: [V2rayProtocolOutbound: ProfileCoreSelection] = CoreSelectionDefaults.loadAll()

    let perPage: Int = 20
    let coreSelectionProtocols = CoreSelectionDefaults.editableProtocols

    private let service: GithubServiceProtocol

    init(service: GithubServiceProtocol = GithubService()) {
        self.service = service
    }

    func loadCoreVersions() {
        xrayCoreVersion = getCoreVersion(refresh: true)
        loadCapabilityRulesStatus()
    }

    func saveCapabilityRulesBaseURL() {
        let trimmed = capabilityRulesBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolved = trimmed.isEmpty ? defaultCapabilityRulesBaseURL : trimmed
        capabilityRulesBaseURL = resolved
        UserDefaults.set(forKey: .capabilityRulesBaseURL, value: resolved)
    }

    func loadCapabilityRulesStatus() {
        xrayCapabilityRulesStatus = makeDisplayItem(from: CapabilityRulesLoader.status(core: .xray), title: String(localized: .XrayCapabilityRulesStatus))
        singboxCapabilityRulesStatus = makeDisplayItem(from: CapabilityRulesLoader.status(core: .singbox), title: String(localized: .SingboxCapabilityRulesStatus))
    }

    func coreSelection(for protocol: V2rayProtocolOutbound) -> ProfileCoreSelection {
        coreSelections[`protocol`] ?? .auto
    }

    func setCoreSelection(_ selection: ProfileCoreSelection, for protocol: V2rayProtocolOutbound) {
        coreSelections[`protocol`] = selection
        CoreSelectionDefaults.setSelection(selection, for: `protocol`)
    }

    func updateCapabilityRules() {
        guard !isUpdatingCapabilityRules else { return }

        let trimmed = capabilityRulesBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let baseURL = trimmed.isEmpty ? defaultCapabilityRulesBaseURL : trimmed
        capabilityRulesBaseURL = baseURL

        saveCapabilityRulesBaseURL()
        isUpdatingCapabilityRules = true

        Task {
            do {
                let script = AppBinRoot + "/update-capability-rules.sh"
                let msg = try await Task.detached(priority: .userInitiated) {
                    try runCommand(at: script, with: ["--base-url", baseURL])
                }.value
                loadCapabilityRulesStatus()
                errorMsg = String(localized: .CapabilityRulesUpdateSuccess) + "\n" + msg
            } catch {
                errorMsg = String(localized: .OperationFailed, arguments: error.localizedDescription)
            }
            isUpdatingCapabilityRules = false
            showAlert = true
        }
    }

    func openCapabilityRulesDirectory() {
        openInFinder(path: CapabilityRulesLoader.overrideDirectoryPath())
    }

    func fetchPage(_ page: Int) {
        guard !isLoading else { return }
        isLoading = true
        let service = service
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

    func refresh() {
        guard currentPage > 1 else { return }
        fetchPage(currentPage)
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
            // 更新当前core版本
            clearCoreVersionCache()
            xrayCoreVersion = getCoreVersion(refresh: true)
            // 更新 AppMenu 菜单栏中显示的 Xray-core 版本
            AppMenuManager.shared.refreshAllMenus()
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

    private func makeDisplayItem(from snapshot: CapabilityRulesStatusSnapshot, title: String) -> CapabilityRulesDisplayItem {
        CapabilityRulesDisplayItem(
            title: title,
            source: sourceText(for: snapshot.sourceKind),
            reviewedVersion: snapshot.latestReviewedVersion ?? "-",
            capabilityCount: snapshot.capabilityCount,
            path: snapshot.path
        )
    }

    private func sourceText(for sourceKind: CapabilityRulesSourceKind) -> String {
        switch sourceKind {
        case .overrideFile:
            return String(localized: .CapabilityRulesSourceOverride)
        case .bundledFile:
            return String(localized: .CapabilityRulesSourceBundle)
        case .swiftFallback:
            return String(localized: .CapabilityRulesSourceSwift)
        case .unavailable:
            return String(localized: .CapabilityRulesSourceUnavailable)
        }
    }
}
