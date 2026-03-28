//
//  DiagnosticModel.swift
//  V2rayU
//
//  Created by yanue on 2025/11/8.
//

import SwiftUI

/// 诊断分类（精简版）
enum DiagnosticCategory: String, CaseIterable, Identifiable {
    case files = "文件检查"
    case status = "运行状态"
    case logs = "日志分析"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .files: return "folder.badge.gearshape"
        case .status: return "cpu"
        case .logs: return "doc.text.magnifyingglass"
        }
    }
    
    var steps: [DiagnosticStep] {
        switch self {
        case .files:
            return [.v2rayUToolInstall, .uToolPermission, .coreInstall, .coreArch, .configFile, .geoipFile, .geositeFile]
        case .status:
            return [.coreRunning, .localPortConflict, .pingLatency]
        case .logs:
            return [.logAnalysis]
        }
    }
}

/// 单个诊断项的数据模型：驱动 UI
struct DiagnosticItem: Identifiable, @unchecked Sendable {
    let id = UUID()
    let step: DiagnosticStep
    var category: DiagnosticCategory { step.category }
    let title: String
    let subtitle: String?
    var status: DiagnosticStatus = .pending
    let ok: Bool
    let problem: String?
    let actionTitle: String?
    let action: (() -> Void)?
}

// checkmark.seal.fill" : "exclamationmark.triangle.fill
extension DiagnosticItem {
    var icon: String {
        if ok {
          return "checkmark.seal.fill"
        }
        switch status {
        case .pending:  return "clock.fill"
        case .checking: return "arrow.triangle.2.circlepath.circle.fill"
        case .success:  return "checkmark.seal.fill"
        case .failure:  return "exclamationmark.triangle.fill"
        }
    }

    var color: Color {
        if ok {
            return .green
        }
        switch status {
        case .pending:  return .secondary
        case .checking: return .accentColor
        case .success:  return .green
        case .failure:  return .orange
        }
    }

    var defaultSubtitle: String {
        if ok {
            return "检查通过"
        }
        switch status {
        case .pending:  return "等待检查…"
        case .checking: return "正在检查…"
        case .success:  return "检查通过"
        case .failure:  return "检查失败"
        }
    }
}

/// 诊断步骤枚举：顺序执行
enum DiagnosticStep: String, CaseIterable {
    case v2rayUToolInstall            // V2rayUTool 安装
    case uToolPermission              // v2rayU 工具权限
    case coreInstall                  // v2ray 核心安装
    case coreArch                      // Core 架构检查 (amd64/arm64)
    case configFile                   // 配置文件存在
    case geoipFile                    // GeoIP 文件存在
    case geositeFile                  // GeoSite 文件存在
    case coreRunning                  // 核心运行状态
    case nodeConnectivity             // 节点连接（域名解析 + 端口）
    case localPortConflict            // 本地端口占用
    case pingLatency                  // 延迟（可用性）- 无法翻墙时重点
    case logAnalysis                  // 日志解析（错误映射）
    
    static var allCheckSteps: [DiagnosticStep] {
        [.v2rayUToolInstall, .uToolPermission, .coreInstall, .coreArch, .configFile, .geoipFile, .geositeFile, .coreRunning, .nodeConnectivity, .localPortConflict, .pingLatency, .logAnalysis]
    }
    
    var category: DiagnosticCategory {
        switch self {
        case .v2rayUToolInstall, .uToolPermission, .coreInstall, .coreArch, .configFile, .geoipFile, .geositeFile:
            return .files
        case .coreRunning, .nodeConnectivity, .localPortConflict, .pingLatency:
            return .status
        case .logAnalysis:
            return .logs
        }
    }
}

enum DiagnosticStatus {
    case pending      // 等待检查
    case checking     // 正在检查
    case success      // 检查通过
    case failure      // 检查失败
}
