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
                Image(systemName: "personalhotspot")
                    .resizable()
                    .frame(width: 32, height: 32)
                    .foregroundColor(.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Subscription Settings")
                        .font(.headline)
                    Text("Edit your Profile information")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(.vertical, 18)
            .padding(.leading, 24)
            Divider()
            HStack {
                VStack{
                    ConfigServerView(item: item)
                    ConfigStreamView(item: item)
                    ConfigTransportView(item: item)
                }
                .frame(width: 400) // 左

                Divider().frame(width: 0) // 分隔线，适当调整宽度

                ConfigShowView(item: item) // 右
            }.padding()
            Spacer()
            Divider()
            HStack {
                Spacer()
                Button("Cancel") {
                    onClose()
                }
                Button("Save") {
                    viewModel.upsert(item: item)
                    onClose()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 24)
        }
        .frame(width: 660)
        .onAppear {
            print("ConfigView appeared with item: \(item.id)")
        }
    }
}

