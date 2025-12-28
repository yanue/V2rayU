//
//  Stream.swift
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
                if item.network == .tcp  {
                    if item.network == .tcp {
                        getPickerWithLabel(label: .HeaderType, selection: $item.headerType)
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
                    getPickerWithLabel(label: .HeaderType, selection: $item.headerType)
                    getPickerWithLabel(label: .Security, selection: $item.security)
                }
                
                if item.network == .domainsocket {
                    getTextFieldWithLabel(label: .DsPath, text: $item.path)
                }
                
                if item.network == .kcp {
                    getTextFieldWithLabel(label: .Seed, text: $item.path)
                    getPickerWithLabel(label: .HeaderType, selection: $item.headerType)
                    getBoolFieldWithLabel(label: .Congestion, isOn: $item.allowInsecure)
                }
                
                if item.network == .xhttp {
                    getTextFieldWithLabel(label: .xhttpHost, text: $item.host)
                    getTextFieldWithLabel(label: .xhttpPath, text: $item.path)
                    getTextEditorWithLabel(label: .Extra, text: $item.extra)
                }
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
