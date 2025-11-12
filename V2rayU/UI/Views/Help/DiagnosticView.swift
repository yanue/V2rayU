//
//  LogsPage.swift
//  V2rayU
//
//  Created by yanue on 2025/7/15.
//

import SwiftUI
import AppKit

struct DiagnosticsView: View {
    // 提供当前节点信息的闭包（你可以从 AppState 或配置源取值）
    @StateObject private var viewModel = DiagnosticsViewModel(
        nodeHostProvider: { nil },   // 替换为你的取值
        nodePortProvider: { nil }    // 替换为你的取值
    )
    
    var body: some View {
        VStack {
            HStack {
                Text(String(localized: .Diagnostics))
                    .font(.title3)
                Spacer()
                if !viewModel.progressText.isEmpty {
                    Text(viewModel.progressText)
                        .foregroundColor(.secondary)
                }
                RefreshButton(checking: $viewModel.checking) {
                    viewModel.runSequentialChecks()
                }
                Button {
                    viewModel.showFAQ = true
                } label: {
                    Image(systemName: "questionmark.circle")
                    Text(String(localized: .FAQ))
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, 10)
            
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(viewModel.items) { item in
                        statusRow(item: item)
                    }
                }
                .padding(.top, 6)
            }
            .padding(.horizontal, 10)
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
    }
}

@MainActor
@ViewBuilder
func statusRow1(title: String, subtitle: String?, ok: Bool, problem: String?, actionTitle: String? = nil, action: (() -> Void)? = nil) -> some View {
    HStack(alignment: .top, spacing: 10) {
        Image(systemName: ok ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
            .resizable()
            .frame(width: 24, height: 24)
            .foregroundColor(ok ? .green : .orange)
            .padding(.top, 4)

        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title).font(.headline)
                Spacer()
                if let actionTitle = actionTitle, let action = action {
                    Button(actionTitle) { action() }
                        .background(Color.accentColor.opacity(0.12))
                        .cornerRadius(6)
                }
            }
            if let subtitle = subtitle {
                if ok {
                    Text(subtitle).font(.subheadline).foregroundColor(.green)
                }
            }
            if let problem = problem {
                Text(problem).font(.caption).foregroundColor(.red)
            }
        }
    }
    .padding(12)
    .background(RoundedRectangle(cornerRadius: 10).fill(Color(NSColor.windowBackgroundColor)))
    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.08)))
}

@MainActor
@ViewBuilder
func statusRow(item: DiagnosticItem) -> some View {
    HStack(alignment: .top, spacing: 10) {
        Image(systemName: item.icon)
            .resizable()
            .frame(width: 24, height: 24)
            .foregroundColor(item.color)
            .padding(.top, 4)

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
    .background(RoundedRectangle(cornerRadius: 10).fill(Color(NSColor.windowBackgroundColor)))
    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.08)))
}
