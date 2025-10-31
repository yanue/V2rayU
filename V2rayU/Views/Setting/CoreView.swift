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
        VStack(spacing: 8) {
            // 顶部标题行
            HStack {
                Image(systemName: "crown")
                    .resizable()
                    .frame(width: 28, height: 28)
                    .foregroundColor(.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: .CoreSettingsTitle))
                        .font(.title)
                        .fontWeight(.bold)
                    Text(String(localized: .CoreSettingsSubtitle))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button(action: { vm.checkVersions() }) {
                    Label(String(localized: .CheckLatestVersion),
                          systemImage: "arrow.triangle.2.circlepath")
                }
                .buttonStyle(.borderedProminent)
                .disabled(vm.isLoading)
            }

            Spacer(minLength: 6)

            // 本地路径部分
            Section {
                HStack {
                    Text(String(localized: .LocalCoreDirectory))
                        .font(.headline)
                    Spacer()
                }
                Divider()
                HStack {
                    Text(String(localized: .FileDirectory))
                    Text("\(vm.xrayCorePath)")
                    Spacer()
                }
            }

            Spacer(minLength: 6)

            // 本地版本信息
            Section {
                HStack {
                    Text(String(localized: .LocalCoreVersionDetail))
                        .font(.headline)
                    Spacer()
                }
                Divider()
                HStack {
                    Text(getArch())
                    Text(vm.xrayCoreVersion)
                    Spacer()
                }
            }

            Spacer(minLength: 6)

            // GitHub 最新版本列表
            List {
                if !vm.versions.isEmpty {
                    Section(header: Text(String(localized: .GithubLatestVersion))) {
                        ForEach(vm.versions, id: \.self) { version in
                            HStack {
                                Text(version.tagName)
                                    .font(.title3)
                                Text("\(version.formattedPublishedAt)")
                                    .font(.callout)
                                Spacer()
                                Button(action: {
                                    vm.downloadAndReplace(version: version)
                                }) {
                                    Text(String(localized: .DownloadAndReplace))
                                }
                                .disabled(vm.isLoading)
                            }
                        }
                    }
                }
            }
            .listStyle(PlainListStyle())

            // 下载弹窗
            if vm.showDownloadDialog, let version = vm.selectedVersion {
                DownloadView(
                    version: version,
                    onDownloadSuccess: { filePath in
                        vm.onDownloadSuccess(filePath: filePath)
                    },
                    onDownloadFail: { err in
                        vm.onDownloadFail(err: err)
                    },
                    closeDownloadDialog: vm.closeDownloadDialog
                )
                .padding()
                .background()
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                        .shadow(color: Color.primary.opacity(0.1), radius: 1, x: 0, y: 1)
                )
            }
        }
        .onAppear {
            vm.loadCoreVersions()
            vm.checkVersions()
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
