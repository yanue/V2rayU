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
        VStack {
            PageHeader(
                icon: "questionmark.circle",
                title: String(localized: .Diagnostics),
                subtitle:  String(localized: .DiagnosticSubHead)
            ) {
                HStack(spacing: 8) {
                    if !viewModel.progressText.isEmpty {
                        Text(viewModel.progressText)
                            .foregroundColor(.secondary)
                    }
                    RefreshButton(checking: $viewModel.checking) {
                        viewModel.runSequentialChecks()
                    }
                    .buttonStyle(.bordered)

                    Button {
                        viewModel.showFAQ = true
                    } label: {
                        Image(systemName: "questionmark.circle")
                        Text(String(localized: .FAQ))
                    }
                    .buttonStyle(.bordered)
                }
            }

            VStack(spacing: 0) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(DiagnosticCategory.allCases) { category in
                            tabButton(for: category)
                        }
                    }
                    .padding(.horizontal, 8)
                }
                .frame(height: 40)
//                .background(Color(NSColor.controlBackgroundColor))
                
                Divider()
                
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(viewModel.itemsForCategory(selectedTab)) { item in
                            statusRow(item: item)
                        }
                    }
                    .padding(10)
                }
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
        
        Button {
            selectedTab = category
        } label: {
            HStack(spacing: 4) {
                Image(systemName: category.icon)
                    .font(.system(size: 11))
                Text(category.rawValue)
                    .font(.system(size: 12))
                Text("\(passedCount)/\(items.count)")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
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
