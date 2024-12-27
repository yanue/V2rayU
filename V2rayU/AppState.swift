import SwiftUI

enum RunMode: String {
    case global
    case off
    case manual
    case tunnel

    var icon: String {
        switch self {
        case .global:
            return "IconOn"
        case .off:
            return "IconOff"
        case .manual:
            return "IconM"
        case .tunnel:
            return "IconT"
        }
    }
}

@MainActor
final class AppState: ObservableObject {
    static let shared = AppState() // 单例实例

    @Published var runMode: RunMode = .off

    func setRunMode(mode: RunMode) async {
        self.runMode = mode
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
