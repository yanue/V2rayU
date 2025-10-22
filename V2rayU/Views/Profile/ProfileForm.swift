//
//  Config.swift
//  V2rayU
//
//  Created by yanue on 2024/11/23.
//
import SwiftUI

struct ConfigFormView: View {
    @ObservedObject var item: ProfileModel
    @StateObject private var viewModel = ProfileViewModel()
    
    var onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "shield.lefthalf.filled")
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
            HStack {
                VStack {
                    VStack{
                        ConfigServerView(item: item)
                        Spacer(minLength: 12)
                        ConfigStreamView(item: item)
                        Spacer(minLength: 12)
                        ConfigTransportView(item: item)
                    }
                    .padding(.all, 12)
                    .padding(.leading, 8)
                }
                .frame(width: 360)
                Divider()
                VStack{
                    ConfigShowView(item: item)
                        .padding(.all, 12)
                        .padding(.trailing, 8)
                }
            }
            Divider()
            HStack {
                Spacer()
                Button(String(localized: .Cancel)) {
                    onClose()
                }
                .buttonStyle(.bordered)
                Button(String(localized: .Save)) {
                    viewModel.upsert(item: item.dto)
                    onClose()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 24)
        }
        .frame(width: 700)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.windowBackgroundColor))
                .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 2)
        )
        .onAppear {
            logger.info("ProfileFormView appeared with item: \(item.id)")
        }
    }
}
