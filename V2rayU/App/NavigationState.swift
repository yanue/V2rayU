import SwiftUI

@MainActor
enum MainTab: String, CaseIterable {
    case server
    case combination
    case subscription
    case routing
    case core
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
}

@MainActor
final class NavigationState: ObservableObject {
    static let shared = NavigationState()

    @Published var mainTab: MainTab = .server
    @Published var settingTab: SettingsTab = .general
    @Published var coreSettingTab: CoreSettingTab?

    private init() {}
}

