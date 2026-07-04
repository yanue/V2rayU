//
//  CoreViewModel.swift
//  V2rayU
//
//  Created by yanue on 2025/10/31.
//

import SwiftUI

/// Setting / Core 页面下需要拉取或更新的核心类别
enum CoreUpdateKind: String, CaseIterable, Identifiable, Hashable {
    case xray
    case singbox = "sing-box"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .xray: return "Xray-core"
        case .singbox: return "Sing-box"
        }
    }

    var repo: String {
        switch self {
        case .xray: return "XTLS/Xray-core"
        case .singbox: return "SagerNet/sing-box"
        }
    }

    var updateScriptName: String {
        switch self {
        case .xray: return "update-xray.sh"
        case .singbox: return "update-singbox.sh"
        }
    }

    var coreDirectory: String {
        switch self {
        case .xray: return AppBinRoot + "/bin/xray-core"
        case .singbox: return AppBinRoot + "/bin/sing-box"
        }
    }

    var binaryName: String {
        switch self {
        case .xray:
            #if arch(arm64)
                return "xray-arm64"
            #else
                return "xray-64"
            #endif
        case .singbox:
            #if arch(arm64)
                return "sing-box-arm64"
            #else
                return "sing-box-64"
            #endif
        }
    }

    var capabilityCore: CapabilityRulesCore {
        switch self {
        case .xray: return .xray
        case .singbox: return .singbox
        }
    }
}

@MainActor
final class CoreViewModel: ObservableObject {
    static let shared = CoreViewModel()

    struct CapabilityRulesDisplayItem {
        let title: String
        let source: String
        let reviewedVersion: String
        let capabilityCount: Int
        let path: String?
    }

    struct CoreUpdateChannel {
        var versions: [GithubRelease] = []
        var currentPage: Int = 1
        var hasMorePages: Bool = true
        var isLoading: Bool = false
    }

    // MARK: - 本地版本/状态 (共享)
    @Published var xrayCoreVersion: String = "Unknown"
    @Published var singboxCoreVersion: String = "Unknown"

    // MARK: - 共享提示 / 弹窗
    @Published var errorMsg: String = ""
    @Published var showAlert = false

    // MARK: - Capability Rules
    @Published var isUpdatingCapabilityRules = false
    @Published var capabilityRulesBaseURL: String = UserDefaults.get(forKey: .capabilityRulesBaseURL, defaultValue: defaultCapabilityRulesBaseURL)
    @Published var xrayCapabilityRulesStatus: CapabilityRulesDisplayItem?
    @Published var singboxCapabilityRulesStatus: CapabilityRulesDisplayItem?

    // MARK: - 默认核心选择
    @Published var coreSelections: [V2rayProtocolOutbound: ProfileCoreSelection] = CoreSelectionDefaults.loadAll()
    let coreSelectionProtocols = CoreSelectionDefaults.editableProtocols

    // MARK: - 下载状态
    @Published var channels: [CoreUpdateKind: CoreUpdateChannel] = [
        .xray: CoreUpdateChannel(),
        .singbox: CoreUpdateChannel(),
    ]
    @Published var selectedVersion: GithubRelease?
    @Published var activeDownloadKind: CoreUpdateKind?
    @Published var showDownloadDialog = false
    let downloadManager = DownloadViewModel()

    let perPage: Int = 20
    private let service: GithubServiceProtocol

    var hasActiveDownload: Bool {
        activeDownloadKind != nil && !downloadManager.isFinished
    }

    init(service: GithubServiceProtocol = GithubService()) {
        self.service = service
    }

    // MARK: - 加载本地状态

    func loadCoreVersions() {
        clearCoreVersionCache()
        clearSingboxVersionCache()

        Task.detached(priority: .utility) {
            let xrayVer = getCoreVersion(refresh: true)
            let singboxVer = getSingboxVersion(refresh: true)
            await MainActor.run { [weak self] in
                guard let self else { return }
                self.xrayCoreVersion = xrayVer
                self.singboxCoreVersion = singboxVer
                self.loadCapabilityRulesStatus()
            }
        }
    }

    // MARK: - Capability Rules

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

    func updateCapabilityRules() {
        guard !isUpdatingCapabilityRules else { return }

        let trimmed = capabilityRulesBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let baseURL = trimmed.isEmpty ? defaultCapabilityRulesBaseURL : trimmed
        capabilityRulesBaseURL = baseURL

        saveCapabilityRulesBaseURL()
        isUpdatingCapabilityRules = true

        Task {
            do {
                let result = try await CapabilityRulesLoader.updateFromRemote(baseURL: baseURL)
                loadCapabilityRulesStatus()
                errorMsg = String(localized: .CapabilityRulesUpdateSuccess) + "\n" + result.message
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

    /// 加载能力规则完整文档,用于"功能支持规则"明细列表
    func loadCapabilityRulesDocument(for kind: CoreUpdateKind) -> CapabilityRulesDocument? {
        CapabilityRulesLoader.load(core: kind.capabilityCore)
    }

    // MARK: - 默认核心选择

    func coreSelection(for protocol: V2rayProtocolOutbound) -> ProfileCoreSelection {
        coreSelections[`protocol`] ?? .auto
    }

    func setCoreSelection(_ selection: ProfileCoreSelection, for protocol: V2rayProtocolOutbound) {
        coreSelections[`protocol`] = selection
        CoreSelectionDefaults.setSelection(selection, for: `protocol`)
    }

    // MARK: - GitHub 拉取

    func channel(_ kind: CoreUpdateKind) -> CoreUpdateChannel {
        channels[kind] ?? CoreUpdateChannel()
    }

    func fetchPage(_ page: Int, for kind: CoreUpdateKind) {
        var ch = channel(kind)
        guard !ch.isLoading else { return }
        ch.isLoading = true
        channels[kind] = ch

        let service = service
        let repo = kind.repo
        let perPage = perPage
        Task {
            do {
                let releases = try await service.fetchReleases(repo: repo, page: page, perPage: perPage)
                var updated = self.channel(kind)
                updated.versions = releases
                updated.currentPage = page
                updated.hasMorePages = releases.count >= perPage
                updated.isLoading = false
                self.channels[kind] = updated
            } catch {
                var updated = self.channel(kind)
                updated.isLoading = false
                self.channels[kind] = updated
                self.errorMsg = String(localized: .OperationFailed, arguments: error.localizedDescription)
                self.showAlert = true
            }
        }
    }

    func refresh(for kind: CoreUpdateKind) {
        fetchPage(channel(kind).currentPage, for: kind)
    }

    func goToPreviousPage(for kind: CoreUpdateKind) {
        let ch = channel(kind)
        guard ch.currentPage > 1 else { return }
        fetchPage(ch.currentPage - 1, for: kind)
    }

    func goToNextPage(for kind: CoreUpdateKind) {
        let ch = channel(kind)
        guard ch.hasMorePages else { return }
        fetchPage(ch.currentPage + 1, for: kind)
    }

    // MARK: - 自动下载最小兼容版本

    func downloadMinimumVersion(for decision: XrayCoreCompatibilityDecision) async {
        let kind: CoreUpdateKind = decision.coreType == .XrayCore ? .xray : .singbox
        guard let minVersion = decision.minimumRequiredVersion else {
            // 没有版本信息就只导航到下载页
            return
        }
        await fetchAndDownload(minVersion: minVersion, kind: kind)
    }

    func downloadMinimumVersion(for resolved: CombinedConfigResolved) async {
        let kind: CoreUpdateKind = resolved.coreType == .XrayCore ? .xray : .singbox
        // 组合配置没有精确的最小版本, 导航到下载页由用户选择
    }

    private func fetchAndDownload(minVersion: String, kind: CoreUpdateKind) async {
        do {
            let releases = try await service.fetchReleases(repo: kind.repo, page: 1, perPage: 20)
            // 找到第一个 >= minVersion 的正式发布版(非 prerelease)
            let candidates = releases.filter { !$0.prerelease }
            let match: GithubRelease?
            switch kind {
            case .xray:
                guard let min = XrayVersion(minVersion) else { return }
                match = candidates.first { release in
                    guard let v = XrayVersion(release.tagName) else { return false }
                    return v >= min
                }
            case .singbox:
                guard let min = SingboxVersion(minVersion) else { return }
                match = candidates.first { release in
                    guard let v = SingboxVersion(release.tagName) else { return false }
                    return v >= min
                }
            }
            guard let release = match else {
                errorMsg = "未找到 \(kind.displayName) >= \(minVersion) 的发布版本"
                showAlert = true
                return
            }
            downloadAndReplace(version: release, for: kind)
        } catch {
            errorMsg = String(localized: .OperationFailed, arguments: error.localizedDescription)
            showAlert = true
        }
    }

    // MARK: - 下载 / 替换

    func downloadAndReplace(version: GithubRelease, for kind: CoreUpdateKind) {
        if hasActiveDownload {
            showDownloadDialog = true
            return
        }

        selectedVersion = version
        activeDownloadKind = kind
        showDownloadDialog = true

        let asset: GithubAsset
        switch kind {
        case .xray:
            asset = version.getDownloadAsset()
        case .singbox:
            asset = version.getSingboxDownloadAsset()
        }

        downloadManager.setCallback(
            onSuccess: { [weak self] filePath in
                self?.onDownloadSuccess(filePath: filePath)
            },
            onError: { [weak self] err in
                self?.onDownloadFail(err: err)
            }
        )
        logger.info("start core download: kind=\(kind.rawValue), version=\(version.tagName), asset=\(asset.name)")
        downloadManager.startDownload(
            from: asset.browserDownloadUrl,
            version: version.tagName,
            totalSize: Int64(asset.size),
            timeout: 10
        )
    }

    func onDownloadSuccess(filePath: String) {
        let kind = activeDownloadKind ?? .xray
        do {
            let script = AppBinRoot + "/" + kind.updateScriptName
            let msg = try runCommand(at: "/usr/bin/sudo", with: ["-n", script, filePath])
            Task { await V2rayLaunch.shared.restart() }
            switch kind {
            case .xray:
                clearCoreVersionCache()
                xrayCoreVersion = getCoreVersion(refresh: true)
            case .singbox:
                clearSingboxVersionCache()
                singboxCoreVersion = getSingboxVersion(refresh: true)
            }
            AppMenuManager.shared.refreshAllMenus()
            errorMsg = String(localized: .ReplaceSuccess) + "\n" + msg
        } catch {
            errorMsg = error.localizedDescription
        }
        showAlert = true
        showDownloadDialog = false
        activeDownloadKind = nil
    }

    func onDownloadFail(err: String) {
        errorMsg = err
        showAlert = true
        showDownloadDialog = false
        activeDownloadKind = nil
    }

    func closeDownloadDialog() {
        showDownloadDialog = false
    }

    /// 根据当前下载的核心选择 asset (xray 走默认匹配,sing-box 用 tar.gz/darwin 匹配)
    func resolveAsset(_ release: GithubRelease) -> GithubAsset {
        switch activeDownloadKind ?? .xray {
        case .xray: return release.getDownloadAsset()
        case .singbox: return release.getSingboxDownloadAsset()
        }
    }

    // MARK: - 私有

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
