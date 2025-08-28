//
//  Language.swift
//  V2rayU
//
//  Created by yanue on 2024/12/19.
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

    var localized: String {
        return NSLocalizedString(self.rawValue, comment: "")
    }
}

@MainActor
class LanguageManager: ObservableObject {
    static public let shared = LanguageManager()
    @Published var selectedLanguage: Language {
        didSet {
            UserDefaults.standard.set([selectedLanguage.localeIdentifier], forKey: "AppleLanguages")
            UserDefaults.standard.synchronize()
            updateLocale() // 更新 Locale
        }
    }

    @Published private(set) var currentLocale: Locale

    init() {
        let storedLocaleIdentifier = UserDefaults.standard.stringArray(forKey: "AppleLanguages")?.first ?? "en"
        selectedLanguage = Language(localeIdentifier: storedLocaleIdentifier)
        currentLocale = Locale(identifier: storedLocaleIdentifier)
    }

    private func updateLocale() {
        currentLocale = Locale(identifier: selectedLanguage.localeIdentifier)
        logger.info("Current Locale: \(currentLocale)") // 添加此行
    }
}
