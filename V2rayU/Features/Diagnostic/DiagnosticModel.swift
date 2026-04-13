//
//  DiagnosticModel.swift
//  V2rayU
//
//  Created by yanue on 2025/11/8.
//

import SwiftUI

// MARK: - Category

enum DiagnosticCategory: String, CaseIterable, Identifiable {
    case files   = "文件检查"
    case status  = "运行状态"
    case network = "网络检查"
    case logs    = "日志分析"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .files:   return "folder.badge.gearshape"
        case .status:  return "cpu"
        case .network: return "globe"
        case .logs:    return "doc.text.magnifyingglass"
        }
    }

    var steps: [DiagnosticStep] {
        switch self {
        case .files:
            return [.appDataDir, .v2rayUTool, .xrayCore, .singBox, .updateScript,
                    .sudoersCheck, .tunDaemon, .configCheck, .geoDataFiles]
        case .status:
            return [.coreRunning, .launchdProcess, .systemProxy, .localPortConflict]
        case .network:
            return [.basicNetwork, .nodeConnectivity, .pingLatency]
        case .logs:
            return [.logAnalysis]
        }
    }
}

// MARK: - Step

enum DiagnosticStep: String, CaseIterable {
    // Files
    case appDataDir
    case v2rayUTool
    case xrayCore
    case singBox
    case updateScript
    case sudoersCheck
    case tunDaemon
    case configCheck
    case geoDataFiles
    // Status
    case coreRunning
    case launchdProcess
    case systemProxy
    case localPortConflict
    // Network
    case basicNetwork
    case nodeConnectivity
    case pingLatency
    // Logs
    case logAnalysis

    static var ordered: [DiagnosticStep] {
        DiagnosticCategory.allCases.flatMap { $0.steps }
    }

    var category: DiagnosticCategory {
        switch self {
        case .appDataDir, .v2rayUTool, .xrayCore, .singBox, .updateScript,
             .sudoersCheck, .tunDaemon, .configCheck, .geoDataFiles:
            return .files
        case .coreRunning, .launchdProcess, .systemProxy, .localPortConflict:
            return .status
        case .basicNetwork, .nodeConnectivity, .pingLatency:
            return .network
        case .logAnalysis:
            return .logs
        }
    }
}

// MARK: - Status

enum DiagnosticStatus: Equatable {
    case pending
    case checking
    case passed
    case failed
}

// MARK: - Check Result (value type, Sendable)

struct CheckResult: Sendable {
    let step: DiagnosticStep
    let ok: Bool
    let subtitle: String
    let problem: String?
    let actionId: DiagnosticAction?

    @MainActor
    static func pass(_ step: DiagnosticStep, _ subtitle: String = "") -> CheckResult {
        CheckResult(step: step, ok: true,
                    subtitle: subtitle.isEmpty ? String(localized: .DiagPassed) : subtitle,
                    problem: nil, actionId: nil)
    }

    static func fail(_ step: DiagnosticStep, subtitle: String, problem: String,
                     action: DiagnosticAction? = nil) -> CheckResult {
        CheckResult(step: step, ok: false, subtitle: subtitle, problem: problem, actionId: action)
    }
}

// MARK: - Action ID

enum DiagnosticAction: Sendable {
    case fixInstall
    case fixTool
    case fixGeoip
    case openConfig
    case openNetworkSettings
    case startCore
    case restartCore
    case rePing
    case reloadLaunchd
}

// MARK: - Display Item

struct DiagnosticItem: Identifiable {
    let id: String
    let step: DiagnosticStep
    let title: String
    let subtitle: String
    let status: DiagnosticStatus
    let ok: Bool
    let problem: String?
    let actionTitle: String?
    let action: (() -> Void)?

    var category: DiagnosticCategory { step.category }

    var icon: String {
        switch status {
        case .pending:  return "circle.dotted"
        case .checking: return "arrow.triangle.2.circlepath.circle.fill"
        case .passed:   return "checkmark.circle.fill"
        case .failed:   return "xmark.circle.fill"
        }
    }

    var color: Color {
        switch status {
        case .pending:  return .secondary
        case .checking: return .blue
        case .passed:   return .green
        case .failed:   return .orange
        }
    }
}
