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
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "bonjour")
                    .resizable()
                    .frame(width: 32, height: 32)
                    .foregroundColor(.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    localized(.RoutingSettings)
                        .font(.headline)
                    localized(.RoutingSettingsSubHead)
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
                        Text(String(localized: .CustomRuleGuideTitle)) // 自定义规则填写说明
                            .font(.headline)
                        Text(String(localized: .CustomRuleGuideDescription)) // 每行填写一个规则，可为域名、IP 或 预定义列表。
                            .font(.subheadline)
                        Text(String(localized: .CustomRulePriorityDescription)) // 优先级: 域名阻断 -> 域名代理 -> 域名直连 -> IP阻断 -> IP代理 -> IP直连
                            .font(.footnote)
                            .foregroundColor(.secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(alignment: .top, spacing: 4) {
                                Text(String(localized: .CustomRuleDomainIntro)) // • 域名：
                                    .bold()
                                Text(String(localized: .CustomRuleDomainExample)) // 如 example.com、*.google.com
                            }
                            HStack(alignment: .top, spacing: 4) {
                                Text(String(localized: .CustomRuleIPIntro)) // • IP：
                                    .bold()
                                Text(String(localized: .CustomRuleIPExample)) // 如 8.8.8.8、192.168.0.0/16
                            }
                            HStack(alignment: .top, spacing: 4) {
                                Text(String(localized: .CustomRulePredefinedIntro)) // • 预定义：
                                    .bold()
                                Text(String(localized: .CustomRulePredefinedExample)) // 如 geoip:private、geosite:cn、localhost
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
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            Spacer()
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
            .padding(.horizontal, 24)
        }
    }
}
