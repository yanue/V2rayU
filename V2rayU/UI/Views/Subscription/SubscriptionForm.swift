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
    
    var showHeader: Bool = true
    var onClose: () -> Void
    var onSaveAndSync: (() -> Void)?
    
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
                let unit: Double
                switch intervalUnit {
                case .hour: unit = 3600
                case .minute: unit = 60
                case .day: unit = 86400
                }
                // 负数、非数字或过大的值不接受: Int(Double) 超出范围会直接崩溃
                let seconds = newValue * unit
                guard seconds.isFinite, seconds > 0 else { return }
                item.updateInterval = Int(min(seconds, Double(SubscriptionScheduler.maxUpdateInterval)))
            }
        )
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            if showHeader {
                HStack(alignment: .center, spacing: 12) {
                    Image(systemName: "arrow.triangle.2.circlepath")
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
            }
            Spacer()
            
            // Form fields
            VStack {
                getTextFieldWithLabel(label: .Remark, text: $item.remark)
                getTextFieldWithLabel(label: .SubscriptionUrl, text: $item.url)
                // 配置类型选择
                HStack {
                    LocalizedTextLabelView(label: .ConfigType)
                        .frame(width: 150, alignment: .trailing)
                    Spacer()
                    Picker("", selection: $item.configType) {
                        Text(String(localized: .ConfigTypeAuto)).tag("")
                        Text(String(localized: .ConfigTypeNormal)).tag("normal")
                        Text(String(localized: .ConfigTypeClash)).tag("clash")
                    }
                    .pickerStyle(.segmented)
                }
                getBoolFieldWithLabel(label: .Enable, isOn: $item.enable)
                // 数字输入 + 单位选择
                HStack {
                    LocalizedTextLabelView(label: .UpdateInterval)
                        .frame(width: 150, alignment: .trailing)
                    Spacer()
                    // .id(intervalUnit) forces the TextField to be fully recreated
                    // when the unit changes. The computed displayedInterval binding
                    // produces a new Binding identity on every render, which confuses
                    // the AttributeGraph focus tracking and can cause crashes.
                    TextField("", value: displayedInterval, formatter: NumberFormatter())
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.leading, 7)
                        .id(intervalUnit)

                    Picker("", selection: $intervalUnit) {
                        Text(String(localized: .Minute)).tag(IntervalUnit.minute)
                        Text(String(localized: .Hour)).tag(IntervalUnit.hour)
                        Text(String(localized: .Day)).tag(IntervalUnit.day)
                    }
                    .pickerStyle(.segmented)
                }
                getTextFieldWithLabel(label: .Notes, text: $item.notes)
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
                .focusable(false)
                Button(String(localized: .Save)) {
                    // trim URL 避免首尾空白导致解析失败
                    item.url = item.url.trimmingCharacters(in: .whitespacesAndNewlines)
                    Task {
                        item.entity.upsert()
                        AppMenuManager.shared.refreshServerItems()
                        if let callback = onSaveAndSync {
                            callback()
                        }
                        await MainActor.run {
                            onClose()
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .focusable(false)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 24)
        }
    }
}
