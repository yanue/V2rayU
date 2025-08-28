//
//  Theme.swift
//  V2rayU
//
//  Created by yanue on 2024/12/19.
//

import SwiftUI

enum Theme: String, CaseIterable {
    case System = "Follow System"
    case Light
    case Dark
    var localized: String {
        return NSLocalizedString(rawValue, comment: "")
    }
}

@MainActor
class ThemeManager: ObservableObject {
    @Published var selectedTheme: Theme {
        didSet {
            setAppearance(selectedTheme)
        }
    }

    init() {
        if let savedTheme = UserDefaults.standard.string(forKey: "AppleThemes"),
           let theme = Theme(rawValue: savedTheme) {
            selectedTheme = theme
        } else {
            selectedTheme = .System
        }
        // 初始化应用外观,等待主线程完成后再执行
        DispatchQueue.main.async {
            self.setAppearance(self.selectedTheme)
        }
    }

    // 更新应用外观的方法
    private func setAppearance(_ theme: Theme) {
        logger.info("setAppearance: \(theme)-\(theme.rawValue)-\(theme.localized)")
        // 保存主题设置
        UserDefaults.standard.set(theme.rawValue, forKey: "AppleThemes")
        // 刷新应用外观
        if #available(macOS 10.14, *) {
            switch theme {
            case .Light:
                // 浅色模式
                NSApp.appearance = NSAppearance(named: .aqua)
            case .Dark:
                // 深色模式
                NSApp.appearance = NSAppearance(named: .darkAqua)
            default:
                // 系统默认模式
                NSApp.appearance = nil
            }
        }
    }
}
