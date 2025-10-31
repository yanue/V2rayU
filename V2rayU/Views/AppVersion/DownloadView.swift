//
//  DownloadView.swift
//  V2rayU
//
//  Created by yanue on 2025/10/30.
//

import SwiftUI

struct DownloadView: View {
    @StateObject private var manager = DownloadManager()
    
    var version: GithubRelease
    var onDownloadSuccess: (String) -> Void
    var onDownloadFail: (String) -> Void
    var closeDownloadDialog: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "arrow.down.circle.fill")
                    .foregroundColor(.accentColor)
                    .font(.title2)
                VStack(alignment: .leading) {
                    Text("\(String(localized: .Downloading)) \(manager.downloadingVersion)")
                        .font(.headline)
                    Text(manager.downloadingUrl)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer()
                Button {
                    openInBrowser(manager.downloadingUrl)
                } label: {
                    Label(String(localized: .OpenInBrowser), systemImage: "safari")
                }
                .buttonStyle(.bordered)
            }

            VStack(alignment: .leading) {
                HStack {
                    Text(String(format: "%.1f%%", manager.progress * 100))
                        .font(.headline)
                        .frame(width: 60, alignment: .leading)
                    Text(String(localized: .DownloadedStatus,
                                arguments: manager.downloadedSize,
                                manager.totalSize))
                        .font(.callout)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(manager.speed)
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }

                ProgressView(value: manager.progress)
                    .progressViewStyle(.linear)
                    .frame(height: 10)
                    .tint(.accentColor)

                HStack {
                    if !manager.errorMessage.isEmpty {
                        Text(manager.errorMessage)
                            .foregroundColor(.red)
                    } else {
                        Text(String(localized: .Downloading))
                            .foregroundColor(.green)
                    }
                    Spacer()
                    if manager.isFinished {
                        Button(action: { closeDownloadDialog() }) {
                            Label(String(localized: .Close), systemImage: "xmark.circle")
                        }
                        .buttonStyle(.borderedProminent)
                    } else {
                        Button(action: { manager.cancelTask() }) {
                            Label(String(localized: .CancelDownload), systemImage: "xmark.circle")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
        }
        .onAppear {
            onAppear()
        }
    }
    
    private func onAppear(){
        // 在这里把父级的回调传给 manager
        manager.setCallback(
            onSuccess: { path in
                // 先更新自己 UI
                self.onDownloadSuccess(path) // 再传给父级
            },
            onError: { message in
                // 先更新自己 UI
                self.onDownloadFail(message) // 再传给父级
            }
        )
        // 开始下载
        startDownload()
    }

    private func startDownload() {
        let asset = version.getDownloadAsset()
        logger.info("startDownload-asset: name=\(asset.name),url=\(asset.browserDownloadUrl)")
        manager.startDownload(
            from: asset.browserDownloadUrl,
            version: version.tagName,
            totalSize: Int64(asset.size),
            timeout: 10
        )
    }

    private func openInBrowser(_ urlStr: String) {
        guard let url = URL(string: urlStr) else { return }
        NSWorkspace.shared.open(url)
    }
}
