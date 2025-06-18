//
//  RoutingForm.swift
//  V2rayU
//
//  Created by yanue on 2025/6/18.
//

import SwiftUI

struct RoutingFormView: View {
    @ObservedObject var item: RoutingModel
    @StateObject private var viewModel = RoutingViewModel()

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
                    Text("Routing Settings")
                        .font(.headline)
                    Text("Edit your routing information")
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
                HStack {
                    getTextLabel(label: "domainStrategy")
                    Spacer()
                    Picker("", selection: $item.domainStrategy) {
                        ForEach(domainStrategys, id: \.self) { pick in
                            Text(pick)
                        }
                    }
                }
                HStack {
                    getTextLabel(label: "domainMatcher")
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
                        Text("自定义规则填写说明")
                            .font(.headline)
                        Text("每行填写一个规则，可为域名、IP 或 预定义列表。")
                            .font(.subheadline)
                        Text("优先级: 域名阻断 -> 域名代理 -> 域名直连 -> IP阻断 -> IP代理 -> IP直连")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(alignment: .top, spacing: 4) {
                                Text("• 域名：")
                                    .bold()
                                Text("如 example.com、*.google.com")
                            }
                            HStack(alignment: .top, spacing: 4) {
                                Text("• IP：")
                                    .bold()
                                Text("如 8.8.8.8、192.168.0.0/16")
                            }
                            HStack(alignment: .top, spacing: 4) {
                                Text("• 预定义：")
                                    .bold()
                                Text("如 geoip:private、geosite:cn、localhost")
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
                getTextEditorWithLabel(label: "direct", text: $item.direct)
                getTextEditorWithLabel(label: "block", text: $item.block)
                getTextEditorWithLabel(label: "proxy", text: $item.proxy)
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
