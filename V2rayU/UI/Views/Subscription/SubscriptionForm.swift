//
//  SubscriptionForm.swift
//  V2rayU
//
//  Created by yanue on 2025/6/17.
//

import SwiftUI

enum IntervalUnit: String, CaseIterable {
    case hour, minute, day
}

struct SubscriptionFormView: View {
    @ObservedObject var item: SubscriptionModel
    
    @State private var intervalUnit: IntervalUnit = .minute
    
    var onClose: () -> Void
    
    // 绑定显示值和内部秒数的转换
    private var displayedInterval: Binding<Double> {
        Binding(
            get: {
                switch intervalUnit {
                case .hour: return Double(item.updateInterval) / 3600
                case .minute: return Double(item.updateInterval) / 60
                case .day :return Double(item.updateInterval) / 86400
                }
            },
            set: { newValue in
                switch intervalUnit {
                case .hour: item.updateInterval = Int(newValue * 3600)
                case .minute: item.updateInterval = Int(newValue * 60)
                case .day :item.updateInterval = Int(newValue * 86400)
                }
            }
        )
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "personalhotspot")
                    .resizable()
                    .frame(width: 32, height: 32)
                    .foregroundColor(.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    localized(.SubscriptionSettings)
                        .font(.headline)
                    localized(.SubscriptionSettingsSubHead)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(.vertical, 18)
            .padding(.leading, 24)
            
            Divider()
            Spacer()
            
            // Form fields
            VStack {
                getTextFieldWithLabel(label: .Remark, text: $item.remark)
                getTextFieldWithLabel(label: .SubscriptionUrl, text: $item.url)
                getBoolFieldWithLabel(label: .Enable, isOn: $item.enable)
                // 数字输入 + 单位选择
                HStack {
                    LocalizedTextLabelView(label: .updateInterval)
                        .frame(width: 100, alignment: .trailing)
                    Spacer()
                    TextField("", value: displayedInterval, formatter: NumberFormatter())
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.leading, 7)

                    Picker("", selection: $intervalUnit) {
                        Text(String(localized: .Minute)).tag(IntervalUnit.minute)
                        Text(String(localized: .Hour)).tag(IntervalUnit.hour)
                        Text(String(localized: .Day)).tag(IntervalUnit.day)
                    }
                    .pickerStyle(.segmented)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            
            Spacer()
            Divider()
            
            // Footer buttons
            HStack {
                Spacer()
                Button(String(localized: .Cancel)) {
                    onClose()
                }
                Button(String(localized: .Save)) {
                    // updateInterval 已经在 Binding 中转换为秒
                    Task {
                        item.entity.upsert()
                    }
                    onClose()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 24)
        }
    }
}
