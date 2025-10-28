//
//  JsonView.swift
//  V2rayU
//
//  Created by yanue on 2024/11/25.
//
import SwiftUI

struct JSONTextView: NSViewRepresentable {
    let jsonString: String

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.borderType = .noBorder
        scrollView.autohidesScrollers = true
        
        // 创建 NSTextView
        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = true
        textView.backgroundColor = NSColor.clear
        textView.font = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        
        // 将 NSTextView 添加到 NSScrollView 的 documentView
        scrollView.documentView = textView
        
        // 设置合适的文本视图大小
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.widthAnchor.constraint(equalTo: scrollView.widthAnchor).isActive = true
        textView.heightAnchor.constraint(equalTo: scrollView.heightAnchor).isActive = true
        
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        // 确保 NSTextView 被正确赋值并更新文本内容
        if let textView = nsView.documentView as? NSTextView {
            textView.textStorage?.setAttributedString(highlightJSON(jsonString))
            
            // 使用 textView.layoutManager 确保布局更新
            if let layoutManager = textView.layoutManager {
                layoutManager.ensureLayout(for: textView.textContainer!)
            }
        }
    }

    private func highlightJSON(_ json: String) -> NSAttributedString {
        let attributedString = NSMutableAttributedString(string: json)
        let fullRange = NSRange(location: 0, length: json.utf16.count)

        // 设置默认颜色为黑色
        attributedString.addAttribute(.foregroundColor, value: NSColor.black, range: fullRange)

        // 定义正则表达式和样式
        let patterns: [(String, NSColor)] = [
            (#"\".*?\"(?=\s*[,}\]])"#, NSColor.systemGreen), // 字符串值（例如 "Alice"）需放在第一个位置
            (#"\".*?\"(?=\s*:)"#, NSColor.systemRed), // 键名（例如 "name"）
            (#"\b\d+(\.\d+)?\b"#, NSColor.systemPurple), // 数字（例如 25）
            (#"true|false"#, NSColor.systemOrange), // 布尔值（例如 true）
            (#"null"#, NSColor.systemGray), // Null（例如 null）
            (#"[\{\}\[\]]"#, NSColor.systemBlue) // 花括号和方括号
        ]

        // 使用正则表达式匹配并高亮
        for (pattern, color) in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                regex.matches(in: json, range: fullRange).forEach { match in
                    attributedString.addAttribute(.foregroundColor, value: color, range: match.range)
                }
            }
        }

        return attributedString
    }

}