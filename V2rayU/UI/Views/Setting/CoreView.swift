//
//  CoreView.swift
//  V2rayU
//
//  Created by yanue on 2025/7/20.
//

import SwiftUI
import Foundation

struct CoreView: View {
    @StateObject private var vm = CoreViewModel()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text(String(localized: .LocalCoreVersionDetail))
                    .font(.headline)
                LocalCoreFilesView()
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(String(localized: .CoreVersionList))
                        .font(.headline)
                    Spacer()
                    
                    Button(action: { vm.checkVersions(reset: true) }) {
                        Label(String(localized: .CoreCheckLatestVersion),
                              systemImage: "arrow.triangle.2.circlepath")
                    }
                    .buttonStyle(.borderedProminent)
                    .focusable(false)
                    .disabled(vm.isLoading)
                    
                    if vm.versions.count >= vm.perPage {
                        Button(action: { vm.loadPreviousPage() }) {
                            Image(systemName: "chevron.left")
                        }
                        .disabled(vm.currentPage <= 1 || vm.isLoading)
                        
                        
                        Button(action: { vm.loadNextPage() }) {
                            Image(systemName: "chevron.right")
                        }
                        .disabled(!vm.hasMorePages || vm.isLoading)
                    }
                }
                
                if vm.isLoading && vm.versions.isEmpty {
                    HStack {
                        Spacer()
                        ProgressView(String(localized: .CheckingForUpdates))
                        Spacer()
                    }
                    .padding()
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 6) {
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
                                        Text(String(localized: .DownloadAndReplace))
                                    }
                                    .disabled(vm.isLoading)
                                    .buttonStyle(.bordered)
                                }
                                .padding(.vertical, 4)
                                .padding(.horizontal, 8)
                                .background(Color.secondary.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                        }
                    }
                    .frame(minHeight: 100, maxHeight: 300)
                }
            }

            Divider()

            if vm.showDownloadDialog, let version = vm.selectedVersion {
                DownloadView(
                    version: version,
                    downloadedBtn : String(localized: .ReplaceCore),
                    onDownloadSuccess: { filePath in
                        vm.onDownloadSuccess(filePath: filePath)
                    },
                    onDownloadFail: { err in
                        vm.onDownloadFail(err: err)
                    }
                )
                .padding()
                .background()
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                )
            }
        }
        .padding()
        .onAppear {
            vm.loadCoreVersions()
            vm.checkVersions(reset: true)
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
        let version = getCoreShortVersion()
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
