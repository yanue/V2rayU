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
        VStack(spacing: 0) {
            headerSection

            Divider()

            if isMigrating {
                migratingView
            } else if showResult, let result = migrationResult {
                resultView(result: result)
            } else {
                contentSection
            }

            Divider()

            footerSection
        }
        .frame(width: 500, height: 400)
        .onAppear {
            checkLegacyData()
        }
        .alert(String(localized: .ImportLegacyConfirmTitle), isPresented: $showConfirmDialog) {
            Button(String(localized: .Cancel), role: .cancel) { }
            Button(String(localized: .ImportLegacyData)) {
                performMigration()
            }
        } message: {
            Text(String(localized: .ImportLegacyConfirmMessage, arguments: legacyDataCount.servers, legacyDataCount.subs))
        }
    }

    private var headerSection: some View {
        HStack(spacing: 16) {
            Image(systemName: "arrow.down.doc.fill")
                .font(.system(size: 36))
                .foregroundStyle(.blue.gradient)
                .frame(width: 50)

            VStack(alignment: .leading, spacing: 4) {
                Text(String(localized: .ImportLegacyDataTitle))
                    .font(.title3)
                    .fontWeight(.semibold)
                Text(String(localized: .ImportLegacyDataTip))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(action: { onDismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.cancelAction)
        }
        .padding(20)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var contentSection: some View {
        VStack(spacing: 16) {
            if legacyDataCount.servers > 0 || legacyDataCount.subs > 0 {
                dataCard
            } else {
                noDataCard
            }

            if !debugInfo.isEmpty {
                debugCard
            }
        }
        .padding(20)
    }

    private var dataCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.orange)
                Text(String(localized: .ImportLegacyDataDetected))
                    .font(.headline)
                Spacer()
            }

            HStack(spacing: 24) {
                dataItem(
                    icon: "server.rack",
                    title: String(localized: .ImportLegacyDataServerCount, arguments: legacyDataCount.servers),
                    color: .blue
                )

                dataItem(
                    icon: "list.bullet.rectangle",
                    title: String(localized: .ImportLegacyDataSubCount, arguments: legacyDataCount.subs),
                    color: .purple
                )
            }

            Button(action: { showConfirmDialog = true }) {
                HStack {
                    Image(systemName: "square.and.arrow.down.on.square")
                    Text(String(localized: .ImportLegacyData))
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(16)
        .background(Color.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func dataItem(icon: String, title: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var noDataCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)
            Text(String(localized: .ImportLegacyDataNoData))
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .background(Color.green.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var debugCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Debug Info")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            ScrollView {
                Text(debugInfo)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .frame(maxHeight: 100)
        }
        .padding(12)
        .background(Color.gray.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var migratingView: some View {
        VStack(spacing: 16) {
            Spacer()

            ProgressView()
                .scaleEffect(1.5)
            Text(String(localized: .ImportLegacyDataMigrating))
                .font(.headline)
                .foregroundStyle(.secondary)

            if !debugInfo.isEmpty {
                Text(debugInfo)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: 300)
                    .multilineTextAlignment(.center)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func resultView(result: LegacyMigrationResult) -> some View {
        switch result {
        case .success(let profiles, let subscriptions):
            VStack(spacing: 16) {
                Spacer()

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.green)
                Text(String(localized: .LegacyDataMigrationSuccess, arguments: profiles, subscriptions))
                    .font(.title3)
                    .multilineTextAlignment(.center)

                if !debugInfo.isEmpty {
                    Text(debugInfo)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: 300)
                        .multilineTextAlignment(.center)
                }

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()

        case .noData:
            VStack(spacing: 12) {
                Spacer()
                Image(systemName: "tray")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                Text(String(localized: .LegacyDataMigrationNoData))
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()

        case .error(let message):
            VStack(spacing: 16) {
                Spacer()

                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.orange)
                Text(String(localized: .LegacyDataMigrationFailed, arguments: message))
                    .font(.title3)
                    .multilineTextAlignment(.center)

                if !debugInfo.isEmpty {
                    Text(debugInfo)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: 300)
                        .multilineTextAlignment(.center)
                }

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
        }
    }

    private var footerSection: some View {
        HStack {
            Button(String(localized: .Close)) {
                onDismiss()
            }
            .keyboardShortcut(.cancelAction)

            Spacer()
        }
        .padding(16)
    }

    private func checkLegacyData() {
        Task {
            let defaults = UserDefaults(suiteName: "net.yanue.V2rayU") ?? .standard
            let serverList = defaults.array(forKey: "v2rayServerList") as? [String] ?? []
            let subList = defaults.array(forKey: "v2raySubList") as? [String] ?? []

            await MainActor.run {
                legacyDataCount = (serverList.count, subList.count)

                var info = String(localized: .ImportLegacyDetectedKeys) + "\n"
                info += String(localized: .ImportLegacyV2rayServerList) + "\(serverList.count)\n"
                info += String(localized: .ImportLegacyV2raySubList) + "\(subList.count)"

                if !serverList.isEmpty {
                    info += "\n\n" + String(localized: .ImportLegacyServerList) + "\n"
                    for (index, item) in serverList.prefix(3).enumerated() {
                        info += "  \(index + 1). \(item)\n"
                    }
                    if serverList.count > 3 {
                        info += "  " + String(localized: .ImportLegacyItemsRemaining, arguments: serverList.count - 3)
                    }
                }

                if !subList.isEmpty {
                    info += "\n\n" + String(localized: .ImportLegacySubList) + "\n"
                    for (index, item) in subList.prefix(3).enumerated() {
                        info += "  \(index + 1). \(item)\n"
                    }
                    if subList.count > 3 {
                        info += "  " + String(localized: .ImportLegacyItemsRemaining, arguments: subList.count - 3)
                    }
                }

                debugInfo = info
            }
        }
    }

    private func performMigration() {
        isMigrating = true
        debugInfo = String(localized: .ImportLegacyMigratingStart) + "\n"

        Task {
            let result = await LegacyMigrationHandler.shared.migrate()

            await MainActor.run {
                isMigrating = false
                migrationResult = result
                showResult = true

                switch result {
                case .success(let profiles, let subscriptions):
                    debugInfo = String(localized: .ImportLegacyMigratingComplete) + "\n\n"
                    debugInfo += String(localized: .ImportLegacySuccessServers, arguments: profiles) + "\n"
                    debugInfo += String(localized: .ImportLegacySuccessSubscriptions, arguments: subscriptions)
                case .noData:
                    debugInfo = String(localized: .ImportLegacyNoDataFound)
                case .error(let message):
                    debugInfo = String(localized: .ImportLegacyMigrationFailed) + message
                }
            }
        }
    }
}
