import SwiftData
import SwiftUI

@main
struct V2rayUApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.colorScheme) var colorScheme // 获取当前系统主题模式
    @Environment(\.scenePhase) private var scenePhase
    var body: some Scene {
        // 留空
    }
}
