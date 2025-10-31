//
//  UpdateViewModel.swift
//  V2rayU
//
//  Created by yanue on 2025/10/31.
//

import SwiftUI

@MainActor
final class AppVersionViewModel: ObservableObject {
    @Published var stage: UpdateStage = .checking

    // 检查阶段
    @Published var progressText: String = "Checking for updates..."

    // 版本信息阶段
    @Published var title: String = ""
    @Published var description: String = ""
    @Published var releaseNotes: String = ""
    @Published var releaseNodesTitle: String = "Release Notes"
    @Published var skipVersion: String = "Skip This Version"
    @Published var installUpdate: String = "Install Update"

    // 下载阶段
    @Published var selectedRelease: GithubRelease?

    // 回调
    var onClose: (() -> Void)?
    var onSkip: (() -> Void)?
    var onDownload: (() -> Void)?
    var onInstall: ((String) -> Void)?
}
