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
    
    init() {
        self.autoLaunch = UserDefaults.getBool(forKey: .autoLaunch)
        self.autoCheckVersion = UserDefaults.getBool(forKey: .autoCheckVersion)
        self.autoUpdateServers = UserDefaults.getBool(forKey: .autoUpdateServers)
        self.autoSelectFastestServer = UserDefaults.getBool(forKey: .autoSelectFastestServer)
        self.enableUdp = UserDefaults.getBool(forKey: .enableUdp)
        self.enableMux = UserDefaults.getBool(forKey: .enableMux)
        self.enableSniffing = UserDefaults.getBool(forKey: .enableSniffing)
        self.localHttpHost = UserDefaults.get(forKey: .localHttpHost) ?? "127.0.0.1"
        self.localSockHost = UserDefaults.get(forKey: .localSockHost) ?? "127.0.0.1"
        self.localHttpPort = UserDefaults.get(forKey: .localHttpPort) ?? "1080"
        self.localSockPort = UserDefaults.get(forKey: .localSockHost) ?? "1087"
        self.v2rayLogLevel = UserDefaults.get(forKey: .v2rayLogLevel) ?? "error"
    }
    
    @Published var enableUdp: Bool {
        didSet {
            UserDefaults.setBool(forKey: .enableUdp, value: enableUdp)
        }
    }
    @Published var enableMux: Bool {
        didSet {
            UserDefaults.setBool(forKey: .enableMux, value: enableMux)
        }
    }
    @Published var enableSniffing: Bool {
        didSet {
            UserDefaults.setBool(forKey: .enableSniffing, value: enableSniffing)
        }
    }
    // v2ray-core log level
    @Published var v2rayLogLevel: String {
        didSet {
            UserDefaults.set(forKey: .v2rayLogLevel, value: v2rayLogLevel)
        }
    }
    @Published var autoLaunch: Bool {
        didSet {
            UserDefaults.setBool(forKey: .autoLaunch, value: autoLaunch)
        }
    }
    @Published var autoCheckVersion: Bool {
        didSet {
            UserDefaults.setBool(forKey: .autoCheckVersion, value: autoCheckVersion)
        }
    }
    @Published var autoUpdateServers: Bool {
        didSet {
            UserDefaults.setBool(forKey: .autoUpdateServers, value: autoUpdateServers)
        }
    }
    @Published var autoSelectFastestServer: Bool {
        didSet {
            UserDefaults.setBool(forKey: .autoSelectFastestServer, value: autoSelectFastestServer)
        }
    }
    @Published var localHttpHost: String {
        didSet {
            UserDefaults.set(forKey: .localHttpHost, value: localHttpHost)
        }
    }
    @Published var localSockHost: String {
        didSet {
            UserDefaults.set(forKey: .localSockHost, value: localSockHost)
        }
    }
    @Published var localHttpPort: String {
        didSet {
            UserDefaults.set(forKey: .localHttpPort, value: localHttpPort)
        }
    }
    @Published var localSockPort: String {
        didSet {
            UserDefaults.set(forKey: .localSockPort, value: localSockPort)
        }
    }
    
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
