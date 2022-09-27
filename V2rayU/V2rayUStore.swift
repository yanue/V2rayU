//
//  V2rayUStore.swift
//  V2rayU
//
//  Created by yanue on 2022/9/13.
//

import os
import Foundation


enum V2rayUPanelViewType: Hashable, Equatable {
    case servers
    case subscribtions
    case routes
    
    var stringValue: String {
        switch self {
        case .servers:
            return "today"
        case .subscribtions:
            return "subscribtions"
        case .routes:
            return "routes"
        }
    }
}

@MainActor class V2rayUStore: ObservableObject {
    static let shared = V2rayUStore()
    static let version = 1
    
    let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "V2rayUStore")
    
    let indicatorTimer = Timer.publish(every: 1.25, tolerance: 0.25, on: .current, in: .default).autoconnect()
    
    @Published var navigationTitle = "Planet"
    @Published var navigationSubtitle = ""
    
    @Published var isCreatingPlanet = false
    @Published var isEditingPlanet = false
    @Published var isFollowingPlanet = false
    @Published var isShowingPlanetInfo = false
    @Published var isImportingPlanet = false
    @Published var isMigrating = false
    @Published var isShowingAlert = false
    @Published var alertTitle: String = ""
    @Published var alertMessage: String = ""
    @Published var selectedView: V2rayUPanelViewType? {
        didSet {
            if selectedView != oldValue {
                //                refreshSelectedArticles()
                //                selectedArticle = nil
                UserDefaults.standard.set(selectedView?.stringValue, forKey: "lastSelectedView")
            }
        }
    }
}
