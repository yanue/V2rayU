//
//  CoreView.swift
//  V2rayU
//
//  Created by yanue on 2025/7/20.
//

import Foundation
import SwiftUI

struct CoreView: View {
    @StateObject private var vm = CoreViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text(String(localized: .LocalCoreVersionDetail))
                    .font(.headline)
                LocalCoreFilesView(viewModel: vm)
            }

            Divider()

            // MARK: - Pagination Controls

            HStack {
                Text(String(localized: .AvailableVersions))
                    .font(.headline)

                Spacer()

                Button(action: { vm.goToPreviousPage() }) {
                    Label(String(localized: .PreviousPage), systemImage: "chevron.left")
                }
                .disabled(vm.currentPage <= 1 || vm.isLoading)
                .buttonStyle(.bordered)
                .focusable(false)

                Text(String(localized: .PageIndicator, arguments: vm.currentPage))
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .frame(minWidth: 60, alignment: .center)

                Button(action: { vm.goToNextPage() }) {
                    Label(String(localized: .NextPage), systemImage: "chevron.right")
                }
                .disabled(!vm.hasMorePages || vm.isLoading)
                .buttonStyle(.bordered)
                .focusable(false)
            }
            .padding(.top, 4)

            // MARK: - Download Dialog

            if vm.showDownloadDialog, let version = vm.selectedVersion {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Spacer()
                        Button(action: { vm.closeDownloadDialog() }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        .focusable(false)
                    }
                    DownloadView(
                        version: version,
                        downloadedBtn: String(localized: .ReplaceCore),
                        onDownloadSuccess: { filePath in
                            vm.onDownloadSuccess(filePath: filePath)
                        },
                        onDownloadFail: { err in
                            vm.onDownloadFail(err: err)
                        }
                    )
                }
                .padding()
                .background()
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                )
            }

            // MARK: - 可滚动区域（下载 + 版本列表）

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // MARK: - Available Versions

                    if !vm.versions.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                VStack(alignment: .leading, spacing: 6) {
                                    ForEach(vm.versions, id: \.self) { version in
                                        HStack {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(version.tagName)
                                                    .font(.title3)
                                                    .fontWeight(.medium)
                                                Text(version.formattedPublishedAt)
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                            Spacer()
                                            Button(action: {
                                                vm.downloadAndReplace(version: version)
                                            }) {
                                                Label(String(localized: .UpdateCore), systemImage: "arrow.down.circle")
                                            }
                                            .disabled(vm.isLoading || vm.showDownloadDialog)
                                            .buttonStyle(.bordered)
                                        }
                                        .padding(.vertical, 4)
                                        .padding(.horizontal, 8)
                                        .background(Color.secondary.opacity(0.08))
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .onAppear {
            vm.loadCoreVersions()
            vm.fetchPage(1)
        }
        .alert(isPresented: $vm.showAlert) {
            Alert(
                title: Text(String(localized: .DownloadHint)),
                message: Text(vm.errorMsg),
                dismissButton: .default(Text(String(localized: .Confirm)))
            )
        }
    }
}

struct LocalCoreFilesView: View {
    private let corePath = V2rayU.xrayCorePath

    @ObservedObject var viewModel: CoreViewModel

    var body: some View {
        HStack {
            Image(systemName: "terminal")
                .foregroundColor(.accentColor)
            Text(displayName)
                .font(.system(.body, design: .monospaced))
            Spacer()
            Button(action: { openDirectory() }) {
                Image(systemName: "folder")
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 4)
    }

    private var displayName: String {
        let fileName = xrayFileName
        let version = viewModel.xrayCoreVersion
        return "\(fileName) (v\(version))"
    }

    private var xrayFileName: String {
        #if arch(arm64)
            return "xray-arm64"
        #else
            return "xray-64"
        #endif
    }

    private func openDirectory() {
        NSWorkspace.shared.open(URL(fileURLWithPath: corePath))
    }
}
