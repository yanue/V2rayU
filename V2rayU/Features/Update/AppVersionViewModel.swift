//
//  UpdateViewModel.swift
//  V2rayU
//
//  Created by yanue on 2025/10/31.
//

import SwiftUI

final class AppVersionViewModel: ObservableObject {
    @Published var stage: UpdateStage = .checking

    // 检查阶段
    @Published var checkError: String?

    // 版本信息阶段
    @Published var title: String = ""
    @Published var description: String = ""
    @Published var releaseNotes: String = ""
    
    // 下载阶段
    @Published var selectedRelease: GithubRelease?

    // 回调
    var onClose: (() -> Void)?
    var onSkip: (() -> Void)?
    var onDownload: (() -> Void)?
    var onInstall: ((String) -> Void)?
}
