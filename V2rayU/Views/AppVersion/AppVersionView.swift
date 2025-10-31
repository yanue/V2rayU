//
//  UpdateView.swift
//  V2rayU
//
//  Created by yanue on 2025/10/31.
//

import SwiftUI

struct AppVersionView: View {
    @ObservedObject var vm: AppVersionViewModel

    var body: some View {
        switch vm.stage {
        case .checking:
            VStack(spacing: 20) {
                HStack {
                    Image("V2rayU")
                        .resizable()
                        .frame(width: 64, height: 64)
                        .cornerRadius(8)

                    Spacer()

                    VStack {
                        HStack {
                            ProgressView(vm.progressText)
                                .progressViewStyle(LinearProgressViewStyle())
                                .padding(.horizontal)
                        }

                        HStack {
                            Spacer()
                            Button("Cancel") {
                                vm.onClose?()
                            }
                            .padding(.trailing, 20)
                        }
                    }
                }
                .padding()
            }

        case .versionAvailable:
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 10) {
                    Image("V2rayU")
                        .resizable()
                        .frame(width: 64, height: 64)
                        .padding(.top, 20)
                        .padding(.leading, 20)

                    VStack(alignment: .leading, spacing: 5) {
                        Text(vm.title)
                            .font(.headline)
                            .padding(.top, 20)

                        Text(vm.description)
                            .padding(.trailing, 20)

                        Text(vm.releaseNodesTitle)
                            .font(.headline)
                            .bold()
                            .padding(.top, 20)

                        HStack {
                            TextEditor(text: $vm.releaseNotes)
                                .lineSpacing(6)
                                .frame(height: 120)
                                .border(Color.gray, width: 1)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 20)
                        }

                        HStack {
                            Button(vm.skipVersion) {
                                vm.onSkip?()
                            }

                            Spacer()

                            Button(vm.installUpdate) {
                                vm.onDownload?()
                            }
                            .padding(.trailing, 20)
                            .keyboardShortcut(.defaultAction)
                        }
                        .padding(.top, 20)
                        .padding(.bottom, 20)
                    }
                }
            }
            .frame(width: 500, height: 300)

        case .downloading:
            if let release = vm.selectedRelease {
                DownloadView(
                    version: release,
                    onDownloadSuccess: { filePath in
                        vm.onInstall?(filePath)
                    },
                    onDownloadFail: { err in
                        vm.progressText = "Download failed: \(err)"
                    },
                    closeDownloadDialog: {
                        vm.onClose?()
                    }
                )
                .padding(.all, 20)
                .background()
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                        .shadow(color: Color.primary.opacity(0.1), radius: 1, x: 0, y: 1)
                )
            }
        }
    }
}
