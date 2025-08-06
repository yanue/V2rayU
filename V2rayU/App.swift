import SwiftData
import SwiftUI

@main
struct V2rayUApp: App {
    @State  var windowController: NSWindowController?
    @State  var aboutWindowController: NSWindowController?
    @StateObject var languageManager = LanguageManager()
    @StateObject var themeManager = ThemeManager()
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState.shared
    @Environment(\.colorScheme) var colorScheme // 获取当前系统主题模式

    init() {
        // 初始化
        let fileManager = FileManager.default
        if fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first != nil {
//            print("Application Support Directory: \(appSupportURL)")
        }
        print("NSHomeDirectory()",NSHomeDirectory())
        print("userHomeDirectory",userHomeDirectory)
//        AppDelegate.redirectStdoutToFile()
        // 加载
//        appState.viewModel.getList()
//        V2rayLaunch.runTun2Socks()
    }


    var body: some Scene {
        // 留空
    }
}
