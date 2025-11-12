//
//  LanguageManager.swift
//  V2rayU
//
//  Created by yanue on 2025/8/30.
//

import SwiftUI

enum Language: String, CaseIterable, Identifiable { // 添加 Identifiable
    var id: Self { self } // 使枚举可用于 ForEach
    case en = "English"
    case zhHans = "Simplified Chinese"
    case zhHant = "Traditional Chinese"

    var localeIdentifier: String {
        switch self {
        case .en: return "en"
        case .zhHans: return "zh-Hans"
        case .zhHant: return "zh-Hant"
        }
    }

    init(localeIdentifier: String) {
        switch localeIdentifier {
        case "en": self = .en
        case "zh-Hans": self = .zhHans
        case "zh-Hant": self = .zhHant
        default: self = .en
        }
    }
}

// 在 LanguageManager 中添加
extension Notification.Name {
    static let languageDidChange = Notification.Name("LanguageDidChange")
}

// MARK: - Language Manager
@MainActor
class LanguageManager: ObservableObject {
    static let shared = LanguageManager()

    @Published var selectedLanguage: Language {
        didSet {
            UserDefaults.standard.set([selectedLanguage.localeIdentifier], forKey: "AppleLanguages")
            UserDefaults.standard.synchronize()
            applyLanguage()
        }
    }

    private var languageBundle: Bundle?
    @Published private(set) var currentLocale: Locale

    private init() {
        // 初始化时从 UserDefaults 读取语言
        let storedLocaleIdentifier = UserDefaults.standard.stringArray(forKey: "AppleLanguages")?.first ?? "en"
        let lang = Language(localeIdentifier: storedLocaleIdentifier)

        self.selectedLanguage = lang
        self.currentLocale = Locale(identifier: storedLocaleIdentifier)

        // 初始化时只加载 bundle，不触发 UI 更新，避免循环依赖
        if let path = Bundle.main.path(forResource: lang.localeIdentifier, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            self.languageBundle = bundle
        } else {
            self.languageBundle = Bundle.main
        }
    }

    /// 切换语言时调用
    private func applyLanguage() {
        if let path = Bundle.main.path(forResource: selectedLanguage.localeIdentifier, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            languageBundle = bundle
        } else {
            languageBundle = Bundle.main
        }
        currentLocale = Locale(identifier: selectedLanguage.localeIdentifier)

        // ⚠️ 注意：这里不要直接调用 AppMenuManager.shared
        // 否则可能导致初始化循环
        // 建议在 AppDelegate 或 SceneDelegate 中监听语言变化后再更新菜单
        NotificationCenter.default.post(name: .languageDidChange, object: nil)
    }

    func localizedString(_ key: String) -> String {
        return languageBundle?.localizedString(forKey: key, value: nil, table: nil) ?? key
    }
}

// MARK: - String 扩展
extension String {
    @MainActor
    init(localized key: String) {
        self = LanguageManager.shared.localizedString(key)
    }
    @MainActor
    init(localized label: LanguageLabel) {
        self = LanguageManager.shared.localizedString(label.rawValue)
    }
    @MainActor
    init(localized label: LanguageLabel, arguments: CVarArg...) {
        let localizedString = LanguageManager.shared.localizedString(label.rawValue)
        let finalString = arguments.isEmpty ? localizedString : String(format: localizedString, arguments: arguments)
        self = finalString
    }
}


// MARK: - View Extensions
extension View {
    /// 响应式本地化 Text - 使用字符串
    func localized(_ label: String) -> some View {
        LocalizedTextView(key: label)
    }
    
    /// 响应式本地化 Text - 使用枚举
    func localized(_ label: LanguageLabel) -> some View {
        LocalizedTextView(key: label.rawValue)
    }
    
    /// 响应式本地化 Text - 带参数
    func localized(_ label: LanguageLabel, _ arguments: CVarArg...) -> some View {
        LocalizedTextView(key: label.rawValue, arguments: arguments)
    }
    
    /// 获取本地化字符串（用于 Picker 标题等）
    func localizedString(_ label: LanguageLabel) -> String {
        LanguageManager.shared.localizedString(label.rawValue)
    }
}

// MARK: - 响应式本地化 Text View
struct LocalizedTextView: View {
    let key: String
    var arguments: [CVarArg] = []
    
    @ObservedObject var languageManager = LanguageManager.shared
    
    var body: some View {
        let localizedString = languageManager.localizedString(key)
        let finalString = arguments.isEmpty ? localizedString : String(format: localizedString, arguments: arguments)
        Text(finalString)
    }
}

// MARK: - 响应式本地化 Text View - 使用枚举(View外部调用更方便)
struct LocalizedTextLabelView: View {
    let label: LanguageLabel
    
    @ObservedObject var languageManager = LanguageManager.shared
    
    var body: some View {
        let localizedString = languageManager.localizedString(label.rawValue)
        Text(localizedString)
    }
}
