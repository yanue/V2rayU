//
//  StreamView.swift
//  V2rayU
//
//  Created by yanue on 2024/11/24.
//

import SwiftUI

struct ConfigStreamView: View {
    @ObservedObject var item: ProfileModel

    var body: some View {
        VStack {
            HStack {
                Image(systemName: "waveform.path")
                localized(.StreamSettings)
                Spacer()
            }
            .foregroundColor(.primary)
            .padding(.horizontal, 10)
            .font(.title3)
            
            VStack {
                getPickerWithLabel(label: .Network, selection: $item.network)

                // Use .id(item.network) so SwiftUI fully tears down and recreates
                // this subtree (including all TextField focus state) when the
                // network type changes, preventing AttributeGraph / UpdateViewFocusItem crashes.
                Group {
                    if item.network == .tcp  {
                        if item.network == .tcp {
                            getPickerWithLabel(label: .HeaderType, selection: $item.headerType, ignore: [.srtp, .utp, .`wechat-video`, .dtls, .wireguard, .dns])
                        }
                        if item.headerType == .http {
                            getTextFieldWithLabel(label: .HttpHost, text: $item.host)
                            getTextFieldWithLabel(label: .HttpPath, text: $item.path)
                        }
                    }

                    if item.network == .ws {
                        getTextFieldWithLabel(label: .WsHost, text: $item.host)
                        getTextFieldWithLabel(label: .WsPath, text: $item.path)
                    }

                    if item.network == .h2 {
                        getTextFieldWithLabel(label: .HttpHost, text: $item.host)
                        getTextFieldWithLabel(label: .HttpPath, text: $item.path)
                    }

                    if item.network == .grpc {
                        getTextFieldWithLabel(label: .ServerName, text: $item.path)
                    }

                    if item.network == .quic {
                        getTextFieldWithLabel(label: .Key, text: $item.path)
                        getPickerWithLabel(label: .HeaderType, selection: $item.headerType, ignore: [.http, .dns])
                        getPickerWithLabel(label: .Security, selection: $item.security)
                    }

                    if item.network == .domainsocket {
                        getTextFieldWithLabel(label: .DsPath, text: $item.path)
                    }

                    if item.network == .kcp {
                        getTextFieldWithLabel(label: .Seed, text: $item.path)
                        getPickerWithLabel(label: .HeaderType, selection: $item.headerType)
                    }

                    if item.network == .xhttp {
                        getTextFieldWithLabel(label: .XhttpHost, text: $item.host)
                        getTextFieldWithLabel(label: .XhttpPath, text: $item.path)
                        getTextEditorWithLabel(label: .Extra, text: $item.extra)
                    }

                    if item.network == .hysteria2 {
                        getTextFieldWithLabel(label: .ObfsPassword, text: $item.hysteria2ObfsPassword)

                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                LocalizedTextLabelView(label: .HopPortRange).frame(width: 150, alignment: .trailing)
                                TextField("1000-2000,3000,4000", text: $item.hysteria2HopPortRange)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                            }
                            HStack {
                                Spacer().frame(width: 150)
                                Text(String(localized: .HopPortRangeTip))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        getNumFieldWithLabel(label: .HopInterval, num: $item.hysteria2HopInterval)

                        getTextFieldWithLabel(label: .UploadBandwidth, text: $item.hysteria2BandwidthUp)
                        getTextFieldWithLabel(label: .DownloadBandwidth, text: $item.hysteria2BandwidthDown)

                        Divider()

                        getTextEditorWithLabel(label: .Masquerade, text: $item.hysteria2MasqueradeJson)
                        getTextEditorWithLabel(label: .FinalMask, text: $item.hysteria2FinalMaskJson)
                    }
                }
                .id(item.network) // Force full subtree recreation on network change
            }
            .padding() // 1. 内边距
            .background() // 2. 然后背景
            .clipShape(RoundedRectangle(cornerRadius: 8)) // 3. 内圆角
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                    .shadow(color: Color.primary.opacity(0.1), radius: 1, x: 0, y: 1)
            ) // 4. 添加边框和阴影
        }
    }
}
