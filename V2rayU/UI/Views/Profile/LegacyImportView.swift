//
//  LegacyImportView.swift
//  V2rayU
//
//  Created by yanue on 2025/1/1.
//  Copyright © 2025 yanue. All rights reserved.
//
//  旧版数据导入界面
//  允许用户从 V2rayU v4 版本迁移服务器和订阅数据到 v5 版本
//

import SwiftUI

struct LegacyImportView: View {
    @State private var isMigrating = false
    @State private var migrationResult: LegacyMigrationResult?
    @State private var showResult = false
    @State private var showConfirmDialog = false
    @State private var legacyDataCount: (servers: Int, subs: Int) = (0, 0)
    @State private var debugInfo: String = ""
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            // 标题区域
            HStack {
                Image(systemName: "arrow.down.doc")
                    .font(.system(size: 40))
                    .foregroundColor(.accentColor)
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: .ImportLegacyDataTitle))
                        .font(.headline)
                    Text(String(localized: .ImportLegacyDataTip))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(10)

            // 内容区域
            if isMigrating {
                // 迁移中状态
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("正在迁移数据...")
                        .foregroundColor(.secondary)
                }
                .padding()

            } else if showResult, let result = migrationResult {
                // 显示迁移结果
                resultView(result: result)

            } else {
                // 准备迁移界面
                VStack(spacing: 16) {
                    // 检测到的数据统计
                    if legacyDataCount.servers > 0 || legacyDataCount.subs > 0 {
                        VStack(alignment: .leading, spacing: 8) {
                            Label {
                                Text("检测到旧版数据:")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            } icon: {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(.orange)
                            }

                            HStack {
                                Label("\(legacyDataCount.servers) 个服务器", systemImage: "server.rack")
                                Spacer()
                                Label("\(legacyDataCount.subs) 个订阅", systemImage: "list.bullet.rectangle")
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(8)
                    } else {
                        VStack(spacing: 8) {
                            Image(systemName: "checkmark.circle")
                                .font(.system(size: 40))
                                .foregroundColor(.green)
                            Text("未检测到旧版数据")
                                .foregroundColor(.secondary)
                        }
                    }

                    // 调试信息
                    if !debugInfo.isEmpty {
                        Text(debugInfo)
                            .font(.caption2)
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(4)
                    }

                    // 导入按钮
                    Button(action: {
                        showConfirmDialog = true
                    }) {
                        HStack {
                            Image(systemName: "square.and.arrow.down.on.square")
                            Text(String(localized: .ImportLegacyData))
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(legacyDataCount.servers == 0 && legacyDataCount.subs == 0)
                }
            }

            // 底部按钮
            HStack {
                Button(String(localized: .Close)) {
                    onDismiss()
                }
                .keyboardShortcut(.cancelAction)
            }
        }
        .padding(30)
        .frame(width: 450, height: 350)
        .onAppear {
            checkLegacyData()
        }
        .alert("确认导入", isPresented: $showConfirmDialog) {
            Button("取消", role: .cancel) { }
            Button("导入") {
                performMigration()
            }
        } message: {
            Text("即将从旧版本导入 \(legacyDataCount.servers) 个服务器和 \(legacyDataCount.subs) 个订阅到新版本。是否继续？")
        }
    }

    /// 显示迁移结果的视图
    @ViewBuilder
    private func resultView(result: LegacyMigrationResult) -> some View {
        switch result {
        case .success(let profiles, let subscriptions):
            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.green)
                Text(String(localized: .LegacyDataMigrationSuccess, arguments: profiles, subscriptions))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                if !debugInfo.isEmpty {
                    Text(debugInfo)
                        .font(.caption2)
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(4)
                }
            }
            .padding()

        case .noData:
            VStack(spacing: 12) {
                Image(systemName: "tray")
                    .font(.system(size: 40))
                    .foregroundColor(.secondary)
                Text(String(localized: .LegacyDataMigrationNoData))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
            }
            .padding()

        case .error(let message):
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.orange)
                Text(String(localized: .LegacyDataMigrationFailed, arguments: message))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                if !debugInfo.isEmpty {
                    Text(debugInfo)
                        .font(.caption2)
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(4)
                }
            }
            .padding()
        }
    }

    /// 检查旧版数据
    private func checkLegacyData() {
        Task {
            // v4 版本使用 net.yanue.V2rayU domain
            let defaults = UserDefaults(suiteName: "net.yanue.V2rayU") ?? .standard
            let serverList = defaults.array(forKey: "v2rayServerList") as? [String] ?? []
            let subList = defaults.array(forKey: "v2raySubList") as? [String] ?? []

            await MainActor.run {
                legacyDataCount = (serverList.count, subList.count)

                // 生成调试信息
                var info = "检测到的键:\n"
                info += "- v2rayServerList: \(serverList.count) 项\n"
                info += "- v2raySubList: \(subList.count) 项\n\n"

                if !serverList.isEmpty {
                    info += "服务器列表:\n"
                    for (index, item) in serverList.prefix(5).enumerated() {
                        info += "  \(index + 1). \(item)\n"
                    }
                    if serverList.count > 5 {
                        info += "  ... 还有 \(serverList.count - 5) 项\n"
                    }
                }

                if !subList.isEmpty {
                    info += "\n订阅列表:\n"
                    for (index, item) in subList.prefix(5).enumerated() {
                        info += "  \(index + 1). \(item)\n"
                    }
                    if subList.count > 5 {
                        info += "  ... 还有 \(subList.count - 5) 项\n"
                    }
                }

                debugInfo = info
            }
        }
    }

    /// 执行迁移
    private func performMigration() {
        isMigrating = true
        debugInfo = "开始迁移...\n"

        Task {
            // 直接调用 migrate 方法，不再检查 hasMigrated
            let result = await LegacyMigrationHandler.shared.migrate()

            await MainActor.run {
                isMigrating = false
                migrationResult = result
                showResult = true

                // 添加结果到调试信息
                switch result {
                case .success(let profiles, let subscriptions):
                    debugInfo += "\n迁移完成!\n"
                    debugInfo += "- 成功导入 \(profiles) 个服务器\n"
                    debugInfo += "- 成功导入 \(subscriptions) 个订阅"
                case .noData:
                    debugInfo += "\n没有找到旧版数据"
                case .error(let message):
                    debugInfo += "\n迁移失败: \(message)"
                }
            }
        }
    }
}
