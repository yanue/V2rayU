//
//  ShortcutsView.swift
//  V2rayU
//
//  Created by yanue on 2024/12/18.
//

import SwiftUI
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let toggleV2rayOnOff = Self("toggleV2rayOnOff")
    static let switchProxyMode = Self("switchProxyMode")
    static let switchToTunnelMode = Self("switchToTunnelMode")
    static let switchToGlobalMode = Self("switchToGlobalMode")
    static let switchToManualMode = Self("switchToManualMode")
    static let switchToPacMode = Self("switchToPacMode")
    static let viewConfigJson = Self("viewConfigJson")
    static let viewPacFile = Self("viewPacFile")
    static let viewLog = Self("viewLog")
    static let pingSpeed = Self("pingSpeed")
    static let importServers = Self("importServers")
    static let scanQRCode = Self("scanQRCode")
    static let shareQRCode = Self("shareQRCode")
    static let copyHttpProxy = Self("copyHttpProxy")
}

struct ShortcutsView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                toggleSection
                proxyModesSection
                viewSection
                toolsSection
            }
            .padding()
        }
    }

    private var toggleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: .Toggle))
                .font(.headline)
                .foregroundColor(.secondary)

            VStack(spacing: 8) {
                shortcutRow(
                    label: String(localized: .ToggleV2rayOnOff),
                    name: .toggleV2rayOnOff,
                    icon: "power"
                )

                shortcutRow(
                    label: String(localized: .SwitchProxyMode),
                    name: .switchProxyMode,
                    icon: "arrow.triangle.2.circlepath"
                )
            }
            .padding(12)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
        }
    }

    private var proxyModesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: .ProxyModes))
                .font(.headline)
                .foregroundColor(.secondary)

            VStack(spacing: 8) {
                shortcutRow(
                    label: String(localized: .SwitchToTunnelMode),
                    name: .switchToTunnelMode,
                    icon: "network"
                )

                shortcutRow(
                    label: String(localized: .SwitchToGlobalMode),
                    name: .switchToGlobalMode,
                    icon: "globe"
                )

                shortcutRow(
                    label: String(localized: .SwitchToManualMode),
                    name: .switchToManualMode,
                    icon: "hand.raised"
                )

                shortcutRow(
                    label: String(localized: .SwitchToPacMode),
                    name: .switchToPacMode,
                    icon: "doc.text"
                )
            }
            .padding(12)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
        }
    }

    private var viewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: .View))
                .font(.headline)
                .foregroundColor(.secondary)

            VStack(spacing: 8) {
                shortcutRow(
                    label: String(localized: .ViewConfigJson),
                    name: .viewConfigJson,
                    icon: "doc.text.magnifyingglass"
                )

                shortcutRow(
                    label: String(localized: .ViewPacFile),
                    name: .viewPacFile,
                    icon: "doc.plaintext"
                )

                shortcutRow(
                    label: String(localized: .ViewCoreLog),
                    name: .viewLog,
                    icon: "list.bullet.rectangle"
                )
            }
            .padding(12)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
        }
    }

    private var toolsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: .Tools))
                .font(.headline)
                .foregroundColor(.secondary)

            VStack(spacing: 8) {
                shortcutRow(
                    label: String(localized: .LatencyTest),
                    name: .pingSpeed,
                    icon: "speedometer"
                )

                shortcutRow(
                    label: String(localized: .ImportServersFromClipboard),
                    name: .importServers,
                    icon: "square.and.arrow.down"
                )

                shortcutRow(
                    label: String(localized: .ScanQRCodeFromScreen),
                    name: .scanQRCode,
                    icon: "qrcode.viewfinder"
                )

                shortcutRow(
                    label: String(localized: .ShareQrCode),
                    name: .shareQRCode,
                    icon: "qrcode"
                )

                shortcutRow(
                    label: String(localized: .CopyHttpProxyShellExportLine),
                    name: .copyHttpProxy,
                    icon: "doc.on.clipboard"
                )
            }
            .padding(12)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
        }
    }

    private func shortcutRow(label: String, name: KeyboardShortcuts.Name, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.accentColor)
                .frame(width: 20)

            Text(label)
                .frame(maxWidth: .infinity, alignment: .leading)

            KeyboardShortcuts.Recorder("", name: name)
                .frame(width: 180)
        }
    }
}
