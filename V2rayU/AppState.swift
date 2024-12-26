import SwiftUI

enum RunMode: String {
    case global
    case off
    case manual
    case tunnel

    var icon: String {
        switch self {
        case .global:
            return "IconG"
        case .off:
            return "IconOff"
        case .manual:
            return "IconM"
        case .tunnel:
            return "IconT"
        }
    }
}

class AppState: ObservableObject {
    static let shared = AppState() // 单例实例

    @Published var runMode: RunMode = .off
    @Published var windowController: NSWindowController?
    @Published var aboutWindowController: NSWindowController?
    @Published var languageManager = LanguageManager()
    @Published var themeManager = ThemeManager()

    // 使用 Completion Handler 的异步设置
    func setRunMode(mode: RunMode, completion: @escaping () -> Void) {
        DispatchQueue.global().async {
            DispatchQueue.main.async {
                self.runMode = mode
                UserDefaults.set(forKey: .runMode, value: mode.rawValue)
                completion()
            }
        }
    }

    private var _runningProfile: String = UserDefaults.get(forKey: .runningProfile) ?? ""
    var runningProfile: String {
        get {
            _runningProfile
        }
        set {
            _runningProfile = newValue
            UserDefaults.standard.set(newValue, forKey: "runningProfile")
            objectWillChange.send() // 通知更新
        }
    }

    private var _runningRouting: String = UserDefaults.get(forKey: .runningRouting) ?? ""
    var runningRouting: String {
        get {
            _runningRouting
        }
        set {
            _runningRouting = newValue
            UserDefaults.standard.set(newValue, forKey: "runningRouting")
            objectWillChange.send() // 通知更新
        }
    }
}
