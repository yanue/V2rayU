//
//  DiagnosticView.swift
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

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            Divider()
            // Content
            contentView
        }
        .padding(8)
        .task { viewModel.ensureItemsInitialized() }
        .onDisappear { viewModel.cancelChecks() }
        .alert(isPresented: $viewModel.showOpenSettingsAlert) {
            Alert(
                title: Text(String(localized: .UnableToOpenSystemSettings)),
                message: Text(String(localized: .PleaseManuallyOpenBackgroundActivity)),
                dismissButton: .default(Text(String(localized: .Confirm)))
            )
        }
        .sheet(isPresented: $viewModel.showFAQ) {
            FAQSheetView { viewModel.showFAQ = false }
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .resizable()
                .frame(width: 28, height: 28)
                .foregroundColor(.accentColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: .Diagnostics))
                    .font(.title2).fontWeight(.bold)
                Text(String(localized: .DiagnosticSubHead))
                    .font(.caption).foregroundColor(.secondary)
            }

            Spacer()

            if viewModel.checking {
                Text(viewModel.progressText)
                    .font(.caption).foregroundColor(.secondary)
                    .lineLimit(1).truncationMode(.tail)
            }

            RunDiagnosticButton(checking: $viewModel.checking) {
                viewModel.runSequentialChecks()
            }
            .buttonStyle(.bordered).focusable(false)

            Button {
                viewModel.submitToGitHub()
            } label: {
                Image(systemName: "paperplane")
                Text(String(localized: .SubmitIssue))
            }
            .buttonStyle(.bordered).focusable(false)
            .disabled(viewModel.checking || !viewModel.hasFailures)

            Button {
                viewModel.showFAQ = true
            } label: {
                Image(systemName: "questionmark.circle")
            }
            .buttonStyle(.bordered).focusable(false)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
    }

    // MARK: - Content

    private var contentView: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Summary card
                summaryCard

                // Category sections
                ForEach(DiagnosticCategory.allCases) { category in
                    categorySection(category)
                }
            }
            .padding(12)
        }
        .background(.ultraThinMaterial)
        .cornerRadius(8)
        .onAppear {
            viewModel.runChecksIfNeeded()
        }
    }

    // MARK: - Summary Card

    private var summaryCard: some View {
        let passed = viewModel.passedCount
        let total  = viewModel.totalCount
        let checkedCount = viewModel.checkedCount
        let ratio  = total > 0 ? Double(passed) / Double(total) : 0
        let progressRatio = total > 0 ? Double(checkedCount) / Double(total) : 0
        let allOK  = passed == total && !viewModel.checking

        return HStack(spacing: 16) {
            // Circular progress
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.15), lineWidth: 6)

                if viewModel.checking {
                    // Show progress arc during checking
                    Circle()
                        .trim(from: 0, to: progressRatio)
                        .stroke(
                            Color.accentColor.opacity(0.5),
                            style: StrokeStyle(lineWidth: 6, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.3), value: progressRatio)
                    // Overlay passed portion
                    Circle()
                        .trim(from: 0, to: ratio)
                        .stroke(
                            Color.green,
                            style: StrokeStyle(lineWidth: 6, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.3), value: ratio)
                } else {
                    Circle()
                        .trim(from: 0, to: ratio)
                        .stroke(
                            allOK ? Color.green : Color.orange,
                            style: StrokeStyle(lineWidth: 6, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.5), value: ratio)
                }

                if viewModel.checking {
                    Text("\(checkedCount)/\(total)")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.accentColor)
                } else {
                    Text("\(passed)/\(total)")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(allOK ? .green : .orange)
                }
            }
            .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 4) {
                if viewModel.checking {
                    Text(viewModel.progressText)
                        .font(.headline)
                        .foregroundColor(.primary)
                } else if allOK {
                    Text(String(localized: .DiagPassed))
                        .font(.headline).foregroundColor(.green)
                } else {
                    let failCount = total - passed
                    Text("\(failCount) \(String(localized: .DiagFailed))")
                        .font(.headline).foregroundColor(.orange)
                }

                // Mini progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.gray.opacity(0.15))
                        if viewModel.checking {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.accentColor.opacity(0.3))
                                .frame(width: geo.size.width * progressRatio)
                                .animation(.easeInOut(duration: 0.3), value: progressRatio)
                        }
                        RoundedRectangle(cornerRadius: 3)
                            .fill(allOK ? Color.green : Color.orange)
                            .frame(width: geo.size.width * ratio)
                            .animation(.easeInOut(duration: 0.3), value: ratio)
                    }
                }
                .frame(height: 6)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.12), lineWidth: 1)
        )
    }

    // MARK: - Category Section

    @ViewBuilder
    private func categorySection(_ category: DiagnosticCategory) -> some View {
        let items = viewModel.itemsFor(category)
        let passedCount = items.filter { $0.ok }.count
        let isCollapsed = viewModel.collapsedSections.contains(category)

        VStack(spacing: 0) {
            // Section header
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if isCollapsed {
                        viewModel.collapsedSections.remove(category)
                    } else {
                        viewModel.collapsedSections.insert(category)
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                        .frame(width: 14)

                    Image(systemName: category.icon)
                        .font(.system(size: 13))
                        .foregroundColor(.accentColor)

                    Text(category.rawValue)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primary)

                    Spacer()

                    // Pass badge
                    let allOK = passedCount == items.count && !viewModel.checking
                    HStack(spacing: 4) {
                        Image(systemName: allOK ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(allOK ? .green : .orange)
                        Text("\(passedCount)/\(items.count)")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(NSColor.controlBackgroundColor).opacity(0.6))
                )
            }
            .buttonStyle(.plain).focusable(false)

            // Items
            if !isCollapsed {
                VStack(spacing: 6) {
                    ForEach(items) { item in
                        statusRow(item: item)
                    }

                    // Log viewer in logs section
                    if category == .logs && !viewModel.logContent.isEmpty {
                        logViewer
                    }
                }
                .padding(.top, 6)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    // MARK: - Status Row

    @ViewBuilder
    private func statusRow(item: DiagnosticItem) -> some View {
        HStack(alignment: .center, spacing: 10) {
            // Status icon
            ZStack {
                Circle()
                    .fill(item.color.opacity(0.1))
                    .frame(width: 30, height: 30)

                if item.status == .checking {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(0.5)
                        .frame(width: 14, height: 14)
                } else {
                    Image(systemName: item.icon)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(item.color)
                }
            }

            // Title + subtitle
            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)

                Text(item.subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(item.ok ? .secondary : item.color)
                    .lineLimit(2)

                if let problem = item.problem, !problem.isEmpty, !item.ok {
                    Text(problem)
                        .font(.system(size: 10))
                        .foregroundColor(.red.opacity(0.8))
                        .lineLimit(3)
                }
            }

            Spacer()

            // Action button
            if let actionTitle = item.actionTitle, let action = item.action {
                Button(actionTitle) { action() }
                    .font(.system(size: 11))
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .focusable(false)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.textBackgroundColor).opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.08), lineWidth: 0.5)
        )
    }

    // MARK: - Log Viewer

    private var logViewer: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "doc.text")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Text(String(localized: .ErrorLog))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                Spacer()
            }

            ScrollView([.horizontal, .vertical], showsIndicators: true) {
                Text(viewModel.logContent)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.primary)
                    .textSelection(.enabled)
                    .lineLimit(50)
            }
            .frame(maxHeight: 150)
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(NSColor.textBackgroundColor).opacity(0.5))
            )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.textBackgroundColor).opacity(0.3))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.08), lineWidth: 0.5)
        )
    }
}
