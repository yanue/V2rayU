import SwiftUI

@MainActor
enum MainTab: String, CaseIterable {
    case server
    case subscription
    case routing
    case setting
    case diagnostic
    case about
}

@MainActor
enum SettingsTab {
    case general
    case shortcuts
    case advance
    case dns
    case pac
    case core
    case tun
}

@MainActor
final class NavigationState: ObservableObject {
    static let shared = NavigationState()

    @Published var mainTab: MainTab = .server
    @Published var settingTab: SettingsTab = .general

    private init() {}
}

