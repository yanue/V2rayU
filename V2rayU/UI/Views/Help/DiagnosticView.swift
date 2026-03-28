//
//  LogsPage.swift
//  V2rayU
//
//  Created by yanue on 2025/7/15.
//

import SwiftUI
import AppKit

struct DiagnosticsView: View {
    @StateObject private var viewModel = DiagnosticsViewModel(
        nodeHostProvider: {
            AppState.shared.runningServer?.address
        },
        nodePortProvider: {
            AppState.shared.runningServer.flatMap { UInt16($0.port) }
        }
    )
    @State private var selectedTab: DiagnosticCategory = .files
    
    var body: some View {
        VStack(spacing: 0) {
            PageHeader(
                icon: "questionmark.circle",
                title: String(localized: .Diagnostics),
                subtitle:  String(localized: .DiagnosticSubHead)
            ) {
                if !viewModel.progressText.isEmpty {
                    Text(viewModel.progressText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                RunDiagnosticButton(checking: $viewModel.checking) {
                    viewModel.runSequentialChecks()
                }
                .buttonStyle(.bordered)

                Button {
                    viewModel.submitToGitHub()
                } label: {
                    Image(systemName: "paperplane")
                    Text(String(localized: .SubmitIssue))
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.checking || !viewModel.hasFailures)
            }

            HStack(spacing: 0) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(DiagnosticCategory.allCases) { category in
                            tabButton(for: category)
                        }
                    }
                    .padding(.horizontal, 8)
                }
                .frame(height: 40)
                Button {
                    viewModel.showFAQ = true
                } label: {
                    Image(systemName: "questionmark.circle")
                    Text(String(localized: .FAQ))
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial)

            Divider()
            
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(viewModel.itemsForCategory(selectedTab)) { item in
                        statusRow(item: item)
                    }
                    
                    if selectedTab == .logs && !viewModel.logContent.isEmpty {
                        HStack {
                            Text("错误日志")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        
                        Divider()

                        VStack(alignment: .leading, spacing: 6) {
                            ScrollView(.horizontal, showsIndicators: true) {
                                Text(viewModel.logContent)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(.primary)
                                    .textSelection(.enabled)
                            }
                            .frame(maxHeight: 150)
                            .padding(8)
                        }
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(NSColor.textBackgroundColor).opacity(0.5))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.gray.opacity(0.1), lineWidth: 0.5)
                        )
                    }
                }
                .padding(10)
            }
            .background(.ultraThinMaterial)
            .cornerRadius(8)
            .onAppear { viewModel.runSequentialChecks() }
            .alert(isPresented: $viewModel.showOpenSettingsAlert) {
                Alert(
                    title: Text(String(localized: .UnableToOpenSystemSettings)),
                    message: Text(String(localized: .PleaseManuallyOpenBackgroundActivity)),
                    dismissButton: .default(Text(String(localized: .Confirm)))
                )
            }
            .sheet(isPresented: $viewModel.showFAQ) {
                FAQSheetView() {
                    viewModel.showFAQ = false
                }
            }
        }
        .padding(8)
    }
    
    @ViewBuilder
    private func tabButton(for category: DiagnosticCategory) -> some View {
        let isSelected = selectedTab == category
        let items = viewModel.itemsForCategory(category)
        let passedCount = items.filter { $0.ok }.count
        let failedCount = items.count - passedCount
        let hasFailure = failedCount > 0
        
        let statusColor: Color = hasFailure ? .orange : .green
        let statusIcon = hasFailure ? "exclamationmark.circle.fill" : "checkmark.circle.fill"
        
        Button {
            selectedTab = category
        } label: {
            HStack(spacing: 5) {
                Image(systemName: statusIcon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(statusColor)
                
                Text(category.rawValue)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                    .foregroundColor(.primary)
                
                Text("\(passedCount)/\(items.count)")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.gray.opacity(0.08))
            )
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color.accentColor.opacity(0.4) : Color.gray.opacity(0.15), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

@MainActor
@ViewBuilder
func statusRow(item: DiagnosticItem) -> some View {
    HStack(alignment: .top, spacing: 10) {
        ZStack {
            Circle()
                .fill(item.color.opacity(0.12))
                .frame(width: 28, height: 28)
            Image(systemName: item.icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(item.color)
        }

        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(item.title).font(.headline)
                Spacer()
                if let actionTitle = item.actionTitle, let action = item.action {
                    Button(actionTitle) { action() }
                        .background(Color.accentColor.opacity(0.12))
                        .cornerRadius(6)
                }
            }
            if let subtitle = item.subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(item.color)
            } else {
                Text(item.defaultSubtitle)
                    .font(.subheadline)
                    .foregroundColor(item.color)
            }
            if let problem = item.problem, !problem.isEmpty {
                Text(problem)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
    }
    .padding(12)
    .background(
        RoundedRectangle(cornerRadius: 10)
            .fill(Color(NSColor.textBackgroundColor).opacity(0.5))
    )
    .overlay(
        RoundedRectangle(cornerRadius: 10)
            .stroke(Color.gray.opacity(0.1), lineWidth: 0.5)
    )
}
