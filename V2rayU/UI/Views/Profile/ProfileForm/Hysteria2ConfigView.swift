//
//  Hysteria2ConfigView.swift
//  V2rayU
//
//  Created by yanue on 2026/1/19.
//  Copyright © 2026 yanue. All rights reserved.
//

import SwiftUI

struct Hysteria2ConfigView: View {
    @ObservedObject var item: ProfileModel
    
    var body: some View {
        VStack(spacing: 8) {
            // Hysteria 2 标题
            HStack {
                Image(systemName: "globe.badge.chevron.backward")
                    .foregroundColor(.blue)
                Text(String(localized: .Hysteria2Configuration))
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal, 10)
            
            Divider()
            
            // 混淆设置
            VStack(alignment: .leading, spacing: 8) {
                Text(String(localized: .ObfuscationSettings))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 10)
                
                HStack {
                    Text(String(localized: .ObfsType) + ":")
                        .frame(width: 100, alignment: .trailing)
                    TextField("salamander", text: $item.hysteria2ObfsType)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                .padding(.horizontal, 10)
                
                if !item.hysteria2ObfsType.isEmpty {
                    HStack {
                        Text(String(localized: .ObfsPassword) + ":")
                            .frame(width: 100, alignment: .trailing)
                        TextField("Obfs password", text: $item.hysteria2ObfsPassword)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    .padding(.horizontal, 10)
                }
            }
            
            // 认证设置
            VStack(alignment: .leading, spacing: 8) {
                Text(String(localized: .AuthenticationSettings))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 10)
                
                HStack {
                    Text(String(localized: .AuthType) + ":")
                        .frame(width: 100, alignment: .trailing)
                    Picker("Auth Type", selection: $item.hysteria2AuthType) {
                        Text(String(localized: .None)).tag("")
                        Text(String(localized: .Password)).tag("password")
                        Text(String(localized: .Token)).tag("token")
                    }
                    .pickerStyle(MenuPickerStyle())
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 10)
                
                if !item.hysteria2AuthType.isEmpty && item.hysteria2AuthType == "password" {
                    HStack {
                        Text(String(localized: .AuthPassword) + ":")
                            .frame(width: 100, alignment: .trailing)
                        TextField("Auth password", text: $item.hysteria2AuthPassword)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    .padding(.horizontal, 10)
                }
            }
            
            // 带宽设置
            VStack(alignment: .leading, spacing: 8) {
                Text(String(localized: .BandwidthSettings))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 10)
                
                HStack {
                    Text(String(localized: .UploadBandwidth) + ":")
                        .frame(width: 100, alignment: .trailing)
                    TextField("e.g., 100 mbps", text: $item.hysteria2BandwidthUp)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                .padding(.horizontal, 10)
                
                HStack {
                    Text(String(localized: .DownloadBandwidth) + ":")
                        .frame(width: 100, alignment: .trailing)
                    TextField("e.g., 100 mbps", text: $item.hysteria2BandwidthDown)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                .padding(.horizontal, 10)
            }
            
            // 高级设置
            VStack(alignment: .leading, spacing: 8) {
                Text(String(localized: .AdvancedSettings))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 10)
                
                HStack {
                    Text(String(localized: .HopInterval) + ":")
                        .frame(width: 100, alignment: .trailing)
                    TextField("0 for disabled", value: $item.hysteria2HopInterval, formatter: NumberFormatter())
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                .padding(.horizontal, 10)
                
                Toggle("Allow Insecure Connection", isOn: $item.hysteria2Insecure)
                    .padding(.horizontal, 10)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
        )
    }
}

// Extension for ProfileModel to handle Hysteria 2 config
extension ProfileModel {
    var hysteria2ObfsType: String {
        get { getHysteria2Config().obfsType }
        set { setHysteria2ConfigField(\.obfsType, newValue) }
    }
    
    var hysteria2ObfsPassword: String {
        get { getHysteria2Config().obfsPassword }
        set { setHysteria2ConfigField(\.obfsPassword, newValue) }
    }
    
    var hysteria2AuthType: String {
        get { getHysteria2Config().authType }
        set { setHysteria2ConfigField(\.authType, newValue) }
    }
    
    var hysteria2AuthPassword: String {
        get { getHysteria2Config().authPassword }
        set { setHysteria2ConfigField(\.authPassword, newValue) }
    }
    
    var hysteria2BandwidthUp: String {
        get { getHysteria2Config().bandwidthUp }
        set { setHysteria2ConfigField(\.bandwidthUp, newValue) }
    }
    
    var hysteria2BandwidthDown: String {
        get { getHysteria2Config().bandwidthDown }
        set { setHysteria2ConfigField(\.bandwidthDown, newValue) }
    }
    
    var hysteria2HopInterval: Int {
        get { getHysteria2Config().hopInterval }
        set { setHysteria2ConfigField(\.hopInterval, newValue) }
    }
    
    var hysteria2Insecure: Bool {
        get { getHysteria2Config().insecure }
        set { setHysteria2ConfigField(\.insecure, newValue) }
    }
    
    func getHysteria2Config() -> ProfileEntity.Hysteria2Config {
        guard let data = entity.extra.data(using: .utf8),
              let config = try? JSONDecoder().decode(ProfileEntity.Hysteria2Config.self, from: data) else {
            return ProfileEntity.Hysteria2Config()
        }
        return config
    }

    func setHysteria2Config(_ config: ProfileEntity.Hysteria2Config) {
        guard let data = try? JSONEncoder().encode(config),
              let jsonString = String(data: data, encoding: .utf8) else { return }
        entity.extra = jsonString
    }

    private func setHysteria2ConfigField<T>(_ keyPath: WritableKeyPath<ProfileEntity.Hysteria2Config, T>, _ value: T) {
        var config = getHysteria2Config()
        config[keyPath: keyPath] = value
        setHysteria2Config(config)
    }
}