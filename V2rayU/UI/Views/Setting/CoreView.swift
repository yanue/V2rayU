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

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text(String(localized: .LocalCoreDirectory))
                    .font(.headline)
                HStack {
                    Text(String(localized: .FileDirectory))
                    Text("\(vm.xrayCorePath)")
                    Spacer()
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text(String(localized: .LocalCoreVersionDetail))
                    .font(.headline)
                HStack {
                    Text(getArch())
                    Text(vm.xrayCoreVersion)
                    Spacer()
                }
            }

            Divider()

            if !vm.versions.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(String(localized: .GithubLatestVersion))
                        .font(.headline)
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
        .frame(width: 500, height: 400)
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
