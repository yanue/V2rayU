//
//  DiagnosticModel.swift
//  V2rayU
//
//  Created by yanue on 2025/11/8.
//

import SwiftUI

/// 单个诊断项的数据模型：驱动 UI
struct DiagnosticItem: Identifiable, @unchecked Sendable {
    let id = UUID()
    let step: DiagnosticStep
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
    case networkConnectivity          // 联网（DNS + 公网 IP）
    case systemProxy                  // 系统代理设置
    case firewall                     // 防火墙/安全软件阻断（提示级）
    case coreInstall                  // v2ray 核心安装
    case coreRunning                  // 核心运行状态
    case uToolPermission              // v2rayU 工具权限
    case configValidity               // 配置文件合法性（JSON）
    case dnsResolution                // 节点域名解析
    case portConnectivity             // 节点端口连通性（TCP）
    case localPortConflict            // 本地端口占用
    case geoipFile                    // GeoIP 文件存在
    case pingLatency                  // 延迟（可用性）
    case logAnalysis                  // 日志解析（错误映射）
}

enum DiagnosticStatus {
    case pending      // 等待检查
    case checking     // 正在检查
    case success      // 检查通过
    case failure      // 检查失败
}
