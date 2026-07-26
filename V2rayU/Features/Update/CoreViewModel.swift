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

    // MARK: - 兼容版本自动下载（独立于下载页分页状态）
    enum CompatibilityAutoDownload: Equatable {
        case idle
        case searching
        case found(GithubRelease, CoreUpdateKind)
        case error(String, CoreUpdateKind)
    }
    @Published var compatibilityAutoDownload: CompatibilityAutoDownload = .idle
    private(set) var compatibilityMinVersion: String?
    private(set) var compatibilityMaxVersion: String?

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
        // 注意: 不能在后台 dispatch 之前 clear cache —— 此时 AppMenu.updateMenuTitles()
        // 可能在主线程调用 getCoreShortVersion()，cache 为空会触发 shell() 阻塞主线程。
        // getCoreVersion(refresh: true) 本身会绕过 cache 并重新写入，无需提前 clear。
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let xrayVer = getCoreVersion(refresh: true)
            let singboxVer = getSingboxVersion(refresh: true)
            DispatchQueue.main.async {
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
        compatibilityMinVersion = minVersion
        compatibilityMaxVersion = decision.maximumCompatibleVersion
        await searchCompatibilityVersion(kind: kind)
    }

    func downloadMinimumVersion(for resolved: CombinedConfigResolved) async {
        let kind: CoreUpdateKind = resolved.coreType == .XrayCore ? .xray : .singbox
        // 组合配置没有精确的最小版本, 导航到下载页由用户选择
    }

    func retryCompatibilitySearch() {
        guard case .error(_, let kind) = compatibilityAutoDownload else { return }
        Task { await searchCompatibilityVersion(kind: kind) }
    }

    func dismissCompatibilityBanner() {
        compatibilityAutoDownload = .idle
    }

    /// 独立分页搜索兼容版本，不依赖下载页的 fetchPage 逻辑
    private func searchCompatibilityVersion(kind: CoreUpdateKind) async {
        guard let minVersion = compatibilityMinVersion else { return }
        let maxVersion = compatibilityMaxVersion

        compatibilityAutoDownload = .searching
        let perPage = 50
        var page = 1
        let maxPages = 10

        do {
            while page <= maxPages {
                let releases = try await service.fetchReleases(repo: kind.repo, page: page, perPage: perPage)
                let candidates = releases.filter { !$0.prerelease }

                let match: GithubRelease?
                switch kind {
                case .xray:
                    guard let min = XrayVersion(minVersion) else { return }
                    let upper = maxVersion.flatMap { XrayVersion($0) }
                    match = candidates.first { release in
                        guard let v = XrayVersion(release.tagName) else { return false }
                        if let upper, v >= upper { return false }
                        return v >= min
                    }
                case .singbox:
                    guard let min = SingboxVersion(minVersion) else { return }
                    let upper = maxVersion.flatMap { SingboxVersion($0) }
                    match = candidates.first { release in
                        guard let v = SingboxVersion(release.tagName) else { return false }
                        if let upper, v >= upper { return false }
                        return v >= min
                    }
                }

                if let release = match {
                    compatibilityAutoDownload = .found(release, kind)
                    return
                }

                if releases.count < perPage { break }
                page += 1
            }

            let msg: String
            if let maxVersion {
                msg = String(format: String(localized: "NoCompatibleVersionFoundRange"), kind.displayName, minVersion, maxVersion)
            } else {
                msg = String(format: String(localized: "NoCompatibleVersionFound"), kind.displayName, minVersion)
            }
            compatibilityAutoDownload = .error(msg, kind)
        } catch {
            let msg = String(localized: .OperationFailed, arguments: error.localizedDescription)
            compatibilityAutoDownload = .error(msg, kind)
        }
    }

    func startCompatibilityDownload() {
        guard case .found(let release, let kind) = compatibilityAutoDownload else { return }
        downloadAndReplace(version: release, for: kind)
    }

    // MARK: - 下载 / 替换

    func downloadAndReplace(version: GithubRelease, for kind: CoreUpdateKind) {
        if hasActiveDownload {
            showDownloadDialog = true
            return
        }

        // [Fix] 清除上一次下载/取消/失败残留的 errorMsg 和 showAlert，
        // 否则用户取消后再次点击下载时，旧的错误弹窗会干扰本次操作。
        errorMsg = ""
        showAlert = false
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
        // [Fix] #1679 — 核心下载完成后，先停再替换再启动（stop → replace → start）。
        //
        // 原流程: 直接在核心运行时替换二进制文件，然后 fire-and-forget 调用 restart()。
        //   问题: TUN 模式下 TUN 守护进程以 root LaunchDaemon 运行 sing-box，
        //         替换时旧进程仍在执行，可能导致新版本不生效或版本信息缺失。
        //
        // 新流程:
        //   1) 记录 wasRunning（stop 会将 running 置 false，必须先记录）
        //   2) stop() 停止核心 + TUN 守护进程，确保无进程占用二进制
        //   3) 执行 sudo update-*.sh 替换二进制
        //   4) 刷新版本信息
        //   5) 若之前在运行，调用 start() 重新拉起核心 + TUN
        //
        // 使用 Task.detached 而非 DispatchQueue.global().async，因为步骤 2/4/5 均需
        // await actor 方法（V2rayLaunch.shared），DispatchQueue 闭包不支持 async。
        Task.detached { [weak self] in
            // 1. 先记录运行状态（stop 会将 running 置 false，必须在 stop 之前读取）
            let wasRunning = await V2rayLaunch.shared.isRunning

            // 2. 停止核心 + TUN，确保没有进程正在使用待替换的二进制
            await V2rayLaunch.shared.stop()

            // 3. 执行替换脚本（阻塞 I/O，以 root 权限运行）
            var resultMessage: String?
            var resultError: Error?
            do {
                let script = AppBinRoot + "/" + kind.updateScriptName
                let msg = try runCommand(at: "/usr/bin/sudo", with: ["-n", script, filePath])
                resultMessage = msg
            } catch {
                resultError = error
            }

            // 4. 刷新版本信息（阻塞 I/O，从新二进制读取版本号）
            var freshXrayVersion: String?
            var freshSingboxVersion: String?
            switch kind {
            case .xray:
                freshXrayVersion = getCoreVersion(refresh: true)
            case .singbox:
                freshSingboxVersion = getSingboxVersion(refresh: true)
            }

            // 5. 重新启动核心（仅在替换前处于运行状态时）
            if wasRunning {
                await V2rayLaunch.shared.start()
            }

            // 5. 回到主线程更新 UI
            await MainActor.run { [weak self] in
                guard let self else { return }
                if let error = resultError {
                    self.errorMsg = error.localizedDescription
                } else {
                    if let ver = freshXrayVersion { self.xrayCoreVersion = ver }
                    if let ver = freshSingboxVersion { self.singboxCoreVersion = ver }
                    AppMenuManager.shared.refreshAllMenus()
                    self.errorMsg = String(localized: .ReplaceSuccess) + "\n" + (resultMessage ?? "")
                }
                self.showAlert = true
                self.showDownloadDialog = false
                self.activeDownloadKind = nil
            }
        }
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
