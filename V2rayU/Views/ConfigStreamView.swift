//
//  Stream.swift
//  V2rayU
//
//  Created by yanue on 2024/11/24.
//

import SwiftUI

struct ConfigStreamView: View {
    @ObservedObject var item: ProxyModel
    
    var body: some View {
        HStack {
            VStack {
                Section(header: Text("Stream Settings")) {
                    HStack {
                        Text("Network").frame(width: 120, alignment: .trailing)
                        Spacer()
                        Picker("", selection: $item.network) {
                            ForEach(V2rayStreamNetwork.allCases) { pick in
                                Text(pick.rawValue)
                            }
                        }
                    }
                    if item.network == .tcp || item.network == .ws || item.network == .h2  || item.network == .http {
                        if item.network == .tcp || item.network == .http {
                            HStack {
                                Text("header type").frame(width: 120, alignment: .trailing)
                                Spacer()
                                Picker("", selection: $item.headerType) {
                                    ForEach(V2rayHeaderType.allCases) { pick in
                                        Text(pick.rawValue)
                                    }
                                }
                            }
                        }
                        HStack {
                            Text("request host").frame(width: 120, alignment: .trailing)
                            Spacer()
                            TextField("Enter request host", text: $item.requestHost)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .padding(.leading,8)
                        }
                        HStack {
                            Text("request path").frame(width: 120, alignment: .trailing)
                            Spacer()
                            TextField("Enter request path", text: $item.path)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .padding(.leading,8)
                        }
                    }
                    if item.network == .grpc {
                        HStack {
                            Text("serviceName").frame(width: 120, alignment: .trailing)
                            Spacer()
                            TextField("Enter serviceName", text: $item.path)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .padding(.leading,8)
                        }
                        HStack {
                            Text("userAgent").frame(width: 120, alignment: .trailing)
                            Spacer()
                            TextField("Enter userAgent", text: $item.requestHost)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .padding(.leading,8)
                        }
                    }
                    if item.network == .quic {
                        HStack {
                            Text("Key").frame(width: 120, alignment: .trailing)
                            Spacer()
                            TextField("Enter Key", text: $item.path)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .padding(.leading,8)
                        }
                        HStack {
                            Text("secruity").frame(width: 120, alignment: .trailing)
                            Spacer()
                            Picker("", selection: $item.headerType) {
                                ForEach(V2rayHeaderType.allCases) { pick in
                                    Text(pick.rawValue)
                                }
                            }
                        }
                        HStack {
                            Text("header-type").frame(width: 120, alignment: .trailing)
                            Spacer()
                            Picker("", selection: $item.headerType) {
                                ForEach(V2rayHeaderType.allCases) { pick in
                                    Text(pick.rawValue)
                                }
                            }
                        }
                    }
                    if item.network == .domainsocket {
                        HStack {
                            Text("path").frame(width: 120, alignment: .trailing)
                            Spacer()
                            TextField("Enter path", text: $item.path)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .padding(.leading,8)
                        }
                    }
                    if item.network == .kcp {
                        HStack {
                            Text("seed").frame(width: 120, alignment: .trailing)
                            Spacer()
                            TextField("Enter seed", text: $item.path)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .padding(.leading,8)
                        }
                        HStack {
                            Text("header-type").frame(width: 120, alignment: .trailing)
                            Spacer()
                            Picker("", selection: $item.headerType) {
                                ForEach(V2rayHeaderType.allCases) { pick in
                                    Text(pick.rawValue)
                                }
                            }
                            Spacer()
                            Toggle("congestion", isOn: $item.allowInsecure).frame(alignment: .leading)
                                .toggleStyle(SwitchToggleStyle(tint: .blue))
                        }
                        HStack {
                            Text("mtu").frame(width: 120, alignment: .trailing)
                            Spacer()
                            TextField("Enter mtu", text: $item.path)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .padding(.leading,8)
                            Text("tti").frame(width: 120, alignment: .trailing)
                            Spacer()
                            TextField("Enter tti", text: $item.path)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .padding(.leading,8)
                        }
                        HStack {
                            Text("uplinkCapacity").frame(width: 120, alignment: .trailing)
                            Spacer()
                            TextField("Enter uplinkCapacity", text: $item.path)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .padding(.leading,8)
                            Text("downlinkCapacity").frame(width: 120, alignment: .trailing)
                            Spacer()
                            TextField("Enter downlinkCapacity", text: $item.path)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .padding(.leading,8)
                        }
                    }
                }
            }
        }.padding(20)
        Spacer()
    }
}

#Preview {
    ConfigStreamView(item: ProxyModel(protocol: .trojan, address: "dss", port: 443, id: "aaa", security: "auto", remark: "test01"))
}
