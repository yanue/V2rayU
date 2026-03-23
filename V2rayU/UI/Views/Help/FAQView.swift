//
//  QA.swift
//  V2rayU
//
//  Created by yanue on 2025/9/13.
//

import SwiftUI

struct FAQView: View {
    @State private var expandedIndices: Set<Int> = []

    var body: some View {
        ScrollView {
            VStack {
                ForEach(Array(faqItems.enumerated()), id: \.offset) { idx, item in
                    VStack(spacing: 0) {
                        Button(action: {
                            withAnimation(.interactiveSpring(response: 0.32, dampingFraction: 0.78, blendDuration: 0)) {
                                if expandedIndices.contains(idx) {
                                    expandedIndices.remove(idx)
                                } else {
                                    expandedIndices.insert(idx)
                                }
                            }
                        }) {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: expandedIndices.contains(idx) ? "chevron.down.circle.fill" : "chevron.right.circle.fill")
                                    .resizable()
                                    .frame(width: 20, height: 20)
                                    .foregroundColor(.accentColor)
                                    .padding(.top, 2)

                                VStack(alignment: .leading, spacing: 6) {
                                    item.question
                                        .font(.headline)
                                        .foregroundColor(Color.primary)
                                    if !expandedIndices.contains(idx) {
                                        item.answer
                                            .font(.subheadline)
                                            .foregroundColor(Color.secondary)
                                            .lineLimit(2)
                                    }
                                }
                                Spacer()
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if expandedIndices.contains(idx) {
                                    expandedIndices.remove(idx)
                                } else {
                                    expandedIndices.insert(idx)
                                }
                            }
                            .padding()
                        }
                        .buttonStyle(PlainButtonStyle())
                        .accessibilityElement(children: .combine)

                        if expandedIndices.contains(idx) {
                            VStack(alignment: .leading, spacing: 10) {
                                item.answer
                                    .font(.body)
                                    .foregroundColor(Color.primary)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .multilineTextAlignment(.leading)
                                    .textSelection(.enabled)
                            }
                            .padding([.horizontal, .bottom])
                            .transition(.move(edge: .top).combined(with: .opacity))
                        }
                    }
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color(NSColor.windowBackgroundColor)))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.08)))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .languageDidChange)) { _ in
            withAnimation { expandedIndices.removeAll() }
        }
    }

    private var faqItems: [(question: some View, answer: some View)] {
        [
            (question: localized(.FaqHowItWorks), answer: localized(.FaqHowItWorksDetail)),
            (question: localized(.FaqConfigLocation), answer: localized(.FaqConfigLocationDetail2)),
            (question: localized(.FaqOperationModes), answer: localized(.FaqOperationModesDetail2)),
            (question: localized(.FaqModeRoutingRelation), answer: localized(.FaqModeRoutingRelationDetail)),
            (question: localized(.FaqRoutingPriority), answer: localized(.FaqRoutingPriorityDetail2)),
            (question: localized(.FaqTrueGlobalProxy), answer: localized(.FaqTrueGlobalProxyDetail2)),
            (question: localized(.FaqManualCoreUpdate), answer: localized(.FaqManualCoreUpdateDetail2)),
        ]
    }
}

struct FAQSheetView: View {
    var onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "questionmark.circle")
                    .resizable()
                    .frame(width: 32, height: 32)
                    .foregroundColor(.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    localized(.FAQ)
                        .font(.headline)
                    localized(.FaqSubtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(.vertical, 18)
            .padding(.leading, 24)

            Divider()

            FAQView()
                .padding()

            Divider()
            Spacer()

            HStack {
                Spacer()
                Button(String(localized: .Close)) {
                    onClose()
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 24)
        }
    }
}
