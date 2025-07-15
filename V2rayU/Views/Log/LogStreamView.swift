//
//  LogView.swift
//  V2rayU
//
//  Created by yanue on 2025/7/13.
//

import SwiftUI

struct LogStreamView: View {
    @ObservedObject var logManager: LogStreamHandler
    var title: String = "Log"
    @State private var scrollToBottom: Bool = false
    @State private var isAtBottom: Bool = true

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack {
                    Text(title)
                        .font(.title3)
                        .bold()
                    Text("(\(logManager.logLines.count)) messages")
                        .font(.caption)
                }
                Spacer()
                HStack {
                    LogActionButton(
                        systemName: logManager.isLogging ? "pause.fill" : "play.fill",
                        label: logManager.isLogging ? "Pause" : "Start",
                        color: .blue,
                        action: {
                            if logManager.isLogging {
                                logManager.stopLogging()
                            } else {
                                logManager.startLogging()
                                scrollToBottom = true
                            }
                        }
                    )
                    LogActionButton(
                        systemName: isAtBottom ? "arrow.down.circle.fill" : "arrow.down.circle",
                        label: isAtBottom ? "Bottom" : "Now",
                        color: isAtBottom ? .green : .gray,
                        action: {
                            scrollToBottom = true
                        },
                        filled: isAtBottom
                    )
                    LogActionButton(
                        systemName: "xmark.circle",
                        label: "Clear",
                        color: .red,
                        action: { logManager.clear() }
                    )
                    LogActionButton(
                        systemName: "arrow.clockwise",
                        label: "Reload",
                        color: .orange,
                        action: {
                            logManager.reload()
                            scrollToBottom = true
                        }
                    )
                }
            }
            .padding()
        }
        Spacer()
        ScrollViewReader { proxy in
            GeometryReader { geometry in
                ScrollView(.vertical) {
                    VStack(alignment: .leading, spacing: 0) {
                        TextEditor(text: .constant(
                            logManager.logLines.map { $0.raw }.joined(separator: "\n")
                        ))
                        .id("logContent")
                        .font(.system(size: 12, design: .monospaced))
                    }
                    .onPreferenceChange(ViewOffsetKey.self) { value in
                        let scrollViewHeight = geometry.size.height
                        // value 是内容底部的 y 坐标
                        // 如果内容底部 <= scrollView 高度 + 2，说明到底部
                        if value <= scrollViewHeight + 2 {
                            isAtBottom = true
                        } else {
                            isAtBottom = false
                        }
                    }
                }
                .padding(8)
                .foregroundColor(.primary)
                .frame(minHeight: 300, maxHeight: .infinity)
                .cornerRadius(8)
                .coordinateSpace(name: "scrollView")
                .onChange(of: logManager.logLines) { _, _ in
                    if logManager.isLogging && isAtBottom, let last = logManager.logLines.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
                .onChange(of: scrollToBottom) { _, newValue in
                    if newValue, let last = logManager.logLines.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                        scrollToBottom = false
                    }
                }
            }
        }
    }
}

// 用于传递内容底部的 y 坐标
struct ViewOffsetKey: @preconcurrency PreferenceKey {
    @MainActor static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct LogActionButton: View {
    let systemName: String
    let label: String
    let color: Color
    let action: () -> Void
    var filled: Bool = false
    var body: some View {
        Button(action: action) {
            VStack(alignment: .center, spacing: 4) {
                HStack(spacing: 2) {
                    Image(systemName: systemName)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(color)
                }
                .padding(6)
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(filled ? color.opacity(0.18) : Color.clear)
                )
                .overlay(
                    Circle()
                        .stroke(color.opacity(0.5), lineWidth: 1.2)
                )
                HStack {
                    Text(label)
                        .font(.caption2)
                        .foregroundColor(color)
                }
            }
            .frame(width: 42, height: 42)
            .contentShape(Rectangle()) // 让整个区域可点击
        }
        .buttonStyle(PlainButtonStyle())
    }
}
