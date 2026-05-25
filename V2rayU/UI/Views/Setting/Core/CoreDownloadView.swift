//
//  CoreDownloadView.swift
//  V2rayU
//
//  Created by yanue on 2026/5/25.
//

import SwiftUI

/// Tab 3: 核心下载 — xray / sing-box 子页面
struct CoreDownloadView: View {
    @ObservedObject var vm: CoreViewModel

    @State private var coreTab: CoreUpdateKind = .xray
    @State private var hasLoaded: Set<CoreUpdateKind> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            coreSwitcher

            currentVersionCard

            Divider()

            pageControls

            if vm.showDownloadDialog, let version = vm.selectedVersion, vm.activeDownloadKind == coreTab {
                downloadDialog(version: version)
                    .transition(.opacity)
            }

            versionList
        }
        .padding(16)
        .onAppear { ensureLoaded(coreTab) }
        .onChange(of: coreTab) { _, newValue in ensureLoaded(newValue) }
    }

    // MARK: - 头部

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "arrow.down.app")
                .font(.title3)
                .foregroundColor(.accentColor)
            Text(String(localized: .CoreTabDownload))
                .font(.headline)
            Spacer()
        }
    }

    // MARK: - 切换 core

    private var coreSwitcher: some View {
        Picker("", selection: $coreTab) {
            ForEach(CoreUpdateKind.allCases) { kind in
                Text(kind.displayName).tag(kind)
            }
        }
        .pickerStyle(.segmented)
        .focusable(false)
        .frame(maxWidth: 360)
    }

    // MARK: - 当前版本卡片

    private var currentVersionCard: some View {
        HStack(spacing: 10) {
            Image(systemName: "terminal")
                .foregroundColor(.accentColor)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(coreTab.displayName)  ·  \(coreTab.binaryName)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("\(String(localized: .CoreDownloadCurrent)): v\(currentVersionText)")
                    .font(.caption.monospaced())
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button(action: openCoreDirectory) {
                Label(String(localized: .FileDirectory), systemImage: "folder")
            }
            .buttonStyle(.bordered)
            .focusable(false)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var currentVersionText: String {
        switch coreTab {
        case .xray: return vm.xrayCoreVersion
        case .singbox: return vm.singboxCoreVersion
        }
    }

    private func openCoreDirectory() {
        NSWorkspace.shared.open(URL(fileURLWithPath: coreTab.coreDirectory))
    }

    // MARK: - 分页控制

    private var pageControls: some View {
        let ch = vm.channel(coreTab)
        return HStack {
            Text(String(localized: .AvailableVersions))
                .font(.headline)

            Text(String(localized: .PageIndicator, arguments: ch.currentPage))
                .font(.caption.monospaced())
                .foregroundColor(.secondary)

            Spacer()

            Button(action: { vm.refresh(for: coreTab) }) {
                Label(String(localized: .Refresh), systemImage: "arrow.triangle.2.circlepath")
            }
            .buttonStyle(.borderedProminent)
            .focusable(false)
            .disabled(ch.isLoading)

            Button(action: { vm.goToPreviousPage(for: coreTab) }) {
                Label(String(localized: .PreviousPage), systemImage: "chevron.left")
            }
            .buttonStyle(.bordered)
            .focusable(false)
            .disabled(ch.currentPage <= 1 || ch.isLoading)

            Button(action: { vm.goToNextPage(for: coreTab) }) {
                Label(String(localized: .NextPage), systemImage: "chevron.right")
            }
            .buttonStyle(.bordered)
            .focusable(false)
            .disabled(!ch.hasMorePages || ch.isLoading)

            if ch.isLoading {
                ProgressView()
                    .controlSize(.small)
            }
        }
    }

    // MARK: - 下载对话框 (内嵌)

    @ViewBuilder
    private func downloadDialog(version: GithubRelease) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("\(coreTab.displayName)  ·  \(version.tagName)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                Button(action: { vm.closeDownloadDialog() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .focusable(false)
            }
            .padding(.bottom, 6)

            DownloadView(
                version: version,
                downloadedBtn: String(localized: .ReplaceCore),
                assetResolver: { [coreTab] release in
                    switch coreTab {
                    case .xray: return release.getDownloadAsset()
                    case .singbox: return release.getSingboxDownloadAsset()
                    }
                },
                onDownloadSuccess: { filePath in vm.onDownloadSuccess(filePath: filePath) },
                onDownloadFail: { err in vm.onDownloadFail(err: err) }
            )
        }
        .padding()
        .background(Color.secondary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
        )
    }

    // MARK: - 版本列表

    @ViewBuilder
    private var versionList: some View {
        let ch = vm.channel(coreTab)
        if ch.versions.isEmpty {
            ZStack {
                if ch.isLoading {
                    ProgressView()
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "tray")
                            .font(.title)
                            .foregroundColor(.secondary)
                        Text(String(localized: .CoreRulesEmpty))
                            .font(.callout)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 220)
        } else {
            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(ch.versions, id: \.self) { version in
                        versionRow(version)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    @ViewBuilder
    private func versionRow(_ version: GithubRelease) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(version.tagName)
                        .font(.title3)
                        .fontWeight(.medium)
                    if version.prerelease {
                        Badge(text: "pre-release", color: .orange)
                    }
                }
                Text(version.formattedPublishedAt)
                    .font(.caption.monospaced())
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button(action: { vm.downloadAndReplace(version: version, for: coreTab) }) {
                Label(String(localized: .UpdateCore), systemImage: "arrow.down.circle")
            }
            .buttonStyle(.bordered)
            .focusable(false)
            .disabled(vm.channel(coreTab).isLoading || vm.showDownloadDialog)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(Color.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - 数据加载

    private func ensureLoaded(_ kind: CoreUpdateKind) {
        guard !hasLoaded.contains(kind) else { return }
        hasLoaded.insert(kind)
        vm.fetchPage(1, for: kind)
    }
}

// MARK: - 共享徽章 (与 rules 视图共用样式但本文件内复用)

private struct Badge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.vertical, 2)
            .padding(.horizontal, 6)
            .background(color.opacity(0.18))
            .foregroundColor(color)
            .clipShape(Capsule())
    }
}
