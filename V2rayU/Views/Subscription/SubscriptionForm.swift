//
//  SubscriptionForm.swift
//  V2rayU
//
//  Created by yanue on 2025/6/17.
//

import SwiftUI

struct SubscriptionFormView: View {
    @ObservedObject var item: SubModel
    @StateObject private var viewModel = SubViewModel()
    
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
                    Text("Edit your subscription information")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(.vertical, 18)
            .padding(.leading, 24)
            Divider()
            Spacer()
            VStack() {
                getTextFieldWithLabel(label: "Remark", text: $item.remark)
                getTextFieldWithLabel(label: "Url", text: $item.url)
                getNumFieldWithLabel(label: "sort", num: $item.sort)
                getNumFieldWithLabel(label: "updateInterval", num: $item.updateInterval)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
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
        
    }
}
