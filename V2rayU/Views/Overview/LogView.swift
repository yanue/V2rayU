//
//  LogView.swift
//  V2rayU
//
//  Created by yanue on 2025/7/13.
//

import SwiftUI

struct LogView: View {
    @ObservedObject var logManager: LogStreamHandler
    var title: String = "Log"
    @State private var scrollToBottom: Bool = false
    @State private var isAtBottom: Bool = true

    var body: some View {
        VStack {
            HStack {
                Text(title)
                    .font(.title)
                    .bold()
                Text("(\(logManager.logLines.count))")
                    .font(.caption)
                Spacer()
                HStack() {
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


            ScrollViewReader { proxy in
                GeometryReader { geometry in
                    ScrollView(.vertical) {
                        VStack(alignment: .leading, spacing: 0) {
                            TextEditor(text: .constant(
                                    logManager.logLines.map { $0.raw }.joined(separator: "\n")
                            ))
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.primary)
                            .frame(minHeight: 300, maxHeight: .infinity)
                            .background(Color.clear)
                            .id("logContent") // 用于标识内容
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
                        .padding()
                        .background(Color.clear)

                    }
                    .coordinateSpace(name: "scrollView")
                    .onChange(of: logManager.logLines) { _,_ in
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
                .background() // 2. 然后背景
                .clipShape(RoundedRectangle(cornerRadius: 8)) // 3. 内圆角
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                        .shadow(color: Color.primary.opacity(0.1), radius: 1, x: 0, y: 1)
                ) // 4. 添加边框和阴影
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
                .frame(width: 36,height: 36)
                .background(
                    Circle()
                        .fill(filled ? color.opacity(0.18) : Color.clear)
                )
                .overlay(
                    Circle()
                        .stroke(color.opacity(0.5), lineWidth: 1.2)
                )
                HStack{
                    Text(label)
                        .font(.caption2)
                        .foregroundColor(color)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}
