//
//  RoutingForm.swift
//  V2rayU
//
//  Created by yanue on 2025/6/18.
//

import SwiftUI

struct RoutingFormView: View {
    @ObservedObject var item: RoutingModel

    private let domainStrategys = ["AsIs", "IPIfNonMatch", "IPOnDemand"]
    private let domainMatchers = ["hybrid", "linear"]
    var onClose: () -> Void

    var body: some View {
        VStack {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "map")
                    .resizable()
                    .frame(width: 28, height: 28)
                    .foregroundColor(.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: .RoutingSettings))
                        .font(.title2)
                        .fontWeight(.bold)
                    Text(String(localized: .RoutingSettingsSubHead))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(.vertical, 8)

            Spacer()
            VStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        getTextFieldWithLabel(label: .Remark, text: $item.remark)
                        HStack {
                            getTextLabel(label: .domainStrategy)
                            Spacer()
                            Picker("", selection: $item.domainStrategy) {
                                ForEach(domainStrategys, id: \.self) { pick in
                                    Text(pick)
                                }
                            }
                        }
                        HStack {
                            getTextLabel(label: .domainMatcher)
                            Spacer()
                            Picker("", selection: $item.domainMatcher) {
                                ForEach(domainMatchers, id: \.self) { pick in
                                    Text(pick)
                                }
                            }
                        }
                        
                        Divider()
                        
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "info.circle")
                                .foregroundColor(.accentColor)
                                .font(.title2)
                                .padding(.top, 2)
                            VStack(alignment: .leading, spacing: 6) {
                                Text(String(localized: .CustomRuleGuideTitle))
                                    .font(.headline)
                                Text(String(localized: .CustomRuleGuideDescription))
                                    .font(.subheadline)
                                Text(String(localized: .CustomRulePriorityDescription))
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(alignment: .top, spacing: 4) {
                                        Text(String(localized: .CustomRuleDomainIntro))
                                            .bold()
                                        Text(String(localized: .CustomRuleDomainExample))
                                    }
                                    HStack(alignment: .top, spacing: 4) {
                                        Text(String(localized: .CustomRuleIPIntro))
                                            .bold()
                                        Text(String(localized: .CustomRuleIPExample))
                                    }
                                    HStack(alignment: .top, spacing: 4) {
                                        Text(String(localized: .CustomRulePredefinedIntro))
                                            .bold()
                                        Text(String(localized: .CustomRulePredefinedExample))
                                    }
                                }
                                .font(.footnote)
                                .foregroundColor(.secondary)
                            }
                            Spacer()
                            Button(action: {
                                if let url = URL(string: "https://xtls.github.io/config/routing.html") {
                                    NSWorkspace.shared.open(url)
                                }
                            }) {
                                Image(systemName: "questionmark.circle.fill")
                                    .foregroundColor(.accentColor)
                            }
                        }
                        
                        Divider()
                        
                        getTextEditorWithLabel(label: .Direct, text: $item.direct)
                        getTextEditorWithLabel(label: .Block, text: $item.block)
                        getTextEditorWithLabel(label: .Proxy, text: $item.proxy)
                    }
                    .padding(16)
                }
            }
            .background(.ultraThinMaterial)
            .border(Color.gray.opacity(0.1), width: 1)
            .cornerRadius(8)
            
            Divider()
            
            HStack {
                Spacer()
                Button(String(localized: .Cancel)) {
                    onClose()
                }
                Button(String(localized: .Save)) {
                    RoutingStore.shared.upsert(item.toEntity())
                    onClose()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
        }
        .padding(8)
    }
}
