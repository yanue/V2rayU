//
//  ProfileForm.swift
//  V2rayU
//
//  Created by yanue on 2024/11/23.
//
import SwiftUI

struct ConfigFormView: View {
    @ObservedObject var item: ProfileModel
    
    var onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "globe")
                    .resizable()
                    .frame(width: 32, height: 32)
                    .foregroundColor(.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    localized(.ProfileSettings)
                        .font(.headline)
                    localized(.ProfileSettingsSubHead)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(.vertical, 18)
            .padding(.leading, 24)
            Divider()
            ScrollView(.vertical, showsIndicators: true) {
                HStack(alignment: .top) {
                    VStack {
                        VStack{
                            ConfigServerView(item: item)
                            Spacer(minLength: 12)
                            if item.protocol != .socks && item.protocol != .anytls && item.protocol != .naive {
                                ConfigStreamView(item: item)
                                Spacer(minLength: 12)
                            }
                            if item.protocol != .socks {
                                ConfigTransportView(item: item)
                            }
                        }
                        .padding(.all, 12)
                        .padding(.leading, 8)
                    }
                    .frame(width: 460)
                    Divider()
                    VStack{
                        ConfigShowView(item: item)
                            .padding(.all, 12)
                            .padding(.trailing, 8)
                    }
                }
            }
            .frame(maxHeight: 500) // 限制最大高度，防止超出屏幕
            Divider()
            HStack {
                Spacer()
                Button(String(localized: .Cancel)) {
                    onClose()
                }
                .buttonStyle(.bordered)
                .focusable(false)
                Button(String(localized: .Save)) {
                    ProfileStore.shared.upsert(item.entity)
                    Task {
                        AppMenuManager.shared.refreshServerItems() // 刷新servers
                        uiLogger.info("edit profile: runningProfile=\(AppState.shared.runningProfile), edit=\(item.uuid)")
                        if AppState.shared.runningProfile == item.uuid {
                            await V2rayLaunch.shared.restart()
                        }
                    }
                    onClose()
                }
                .buttonStyle(.borderedProminent)
                .focusable(false)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 24)
        }
        .frame(width: 760)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.windowBackgroundColor))
                .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 2)
        )
        .onAppear {
            logger.info("ProfileFormView appeared with item: \(item.id)")
            // ⚠️ 推迟到下一轮 run loop，原因同下方的 onChange
            DispatchQueue.main.async {
                if item.selectedProtocol == .hysteria2 {
                    if item.security == .none { item.security = .tls }
                    if item.alpn == .h2h1 { item.alpn = .h3 }
                    if item.network != .hysteria2 { item.network = .hysteria2 }
                } else if item.selectedProtocol == .anytls || item.selectedProtocol == .naive {
                    if item.security == .none { item.security = .tls }
                    if item.network != .tcp { item.network = .tcp }
                }
            }
        }
        .onChange(of: item.selectedProtocol) { _, newProtocol in
            // ⚠️ 推迟到下一轮 run loop，避免 SwiftUI 事务内修改属性
            // 导致 FocusItem graph 状态不一致而崩溃
            DispatchQueue.main.async {
                if newProtocol == .hysteria2 {
                    if item.security == .none { item.security = .tls }
                    if item.alpn == .h2h1 { item.alpn = .h3 }
                    if item.network != .hysteria2 { item.network = .hysteria2 }
                } else if newProtocol == .anytls || newProtocol == .naive {
                    if item.security == .none { item.security = .tls }
                    if item.network != .tcp { item.network = .tcp }
                }
            }
        }
    }
}
