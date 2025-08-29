import SwiftData
import SwiftUI

@main
struct V2rayUApp: App {
    @StateObject var languageManager = LanguageManager()
    @StateObject var themeManager = ThemeManager()
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState.shared
    @Environment(\.colorScheme) var colorScheme // 获取当前系统主题模式
    @Environment(\.scenePhase) private var scenePhase
    var body: some Scene {
        // 留空
    }
}
