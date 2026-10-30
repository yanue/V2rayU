import SwiftUI

@MainActor
enum MainTab: String, CaseIterable {
    case status
    case server
    case combination
    case subscription
    case routing
    case core
    case connections
    case logs
    case diagnostic
    case setting
    case about
}

@MainActor
enum SettingsTab {
    case general
    case shortcuts
    case advance
    case dns
    case pac
    case tun
    case backup
}

@MainActor
final class NavigationState: ObservableObject {
    static let shared = NavigationState()

    @Published var mainTab: MainTab = .server {
        didSet { crashBreadcrumb("tab \(mainTab)") }
    }
    @Published var settingTab: SettingsTab = .general {
        didSet { crashBreadcrumb("setting tab \(settingTab)") }
    }
    @Published var coreSettingTab: CoreSettingTab? {
        didSet { crashBreadcrumb("core setting tab \(coreSettingTab.map { "\($0)" } ?? "nil")") }
    }

    private init() {}
}

