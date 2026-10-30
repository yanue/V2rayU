//
//  BackupView.swift
//  V2rayU
//
//  设置 → 备份: 导出 / 导入 节点、订阅、路由、组合和设置
//

import SwiftUI

struct BackupView: View {
    @State private var lastExport: Date? = BackupHandler.lastExportDate

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(String(localized: .BackupSection))
                    .font(.headline)
                    .foregroundColor(.secondary)

                Text(String(localized: .BackupHint))
                    .font(.callout)
                    .foregroundColor(.secondary)

                card(icon: "square.and.arrow.up", title: String(localized: .BackupExport),
                     detail: String(localized: .BackupExportDetail)) {
                    VStack(alignment: .trailing, spacing: 4) {
                        Button(String(localized: .BackupExport)) {
                            BackupHandler.exportWithPanel()
                            lastExport = BackupHandler.lastExportDate
                        }
                        .buttonStyle(.borderedProminent)
                        .focusable(false)
                        Text(String(localized: .BackupLastExport) + ": " +
                             (lastExport.map { Int($0.timeIntervalSince1970).formattedDate } ?? String(localized: .RuleSetNever)))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                card(icon: "square.and.arrow.down", title: String(localized: .BackupImport),
                     detail: String(localized: .BackupImportConfirm)) {
                    Button(String(localized: .BackupImport)) {
                        BackupHandler.importWithPanel()
                    }
                    .buttonStyle(.bordered)
                    .focusable(false)
                }
                Spacer()
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func card<Trailing: View>(icon: String, title: String, detail: String, @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.accentColor)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.body.weight(.medium))
                Text(detail).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            trailing()
        }
        .padding(14)
        .background(Color.secondary.opacity(0.06))
        .cornerRadius(8)
    }
}
