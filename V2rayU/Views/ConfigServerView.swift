//
//  ServerView.swift
//  V2rayU
//
//  Created by yanue on 2024/11/24.
//

import SwiftUI

struct ConfigServerView: View {
    @ObservedObject var item: ProxyModel

    var body: some View {
        HStack {
            VStack {
                Section(header: Text("Server Settings")) {
                    HStack {
                        Text("Protocol").frame(width: 100, alignment: .trailing)
                        Spacer()
                        Picker("", selection: $item.protocol) {
                            ForEach(V2rayProtocolOutbound.allCases) { pick in
                                Text(pick.rawValue)
                            }
                        }
                    }
//                    .pickerStyle(.segmented)
                    if item.protocol == .trojan {
                        HStack {
                            Text("remote-addr").frame(width: 100, alignment: .trailing)
                            Spacer()
                            TextField("Enter remote-addr", text: $item.address)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .padding(.leading, 8)
                            Spacer()
                            Text("remote-port")
                            TextField("Enter remote-port", text: $item.address)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .padding(.leading, 8).frame(width: 100)
                        }
                      
                        HStack {
                            Text("password").frame(width: 100, alignment: .trailing)
                            Spacer()
                            TextField("Enter password", text: $item.id)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .padding(.leading, 8)
                        }
                    }
                    if item.protocol == .vmess {
                        HStack {
                            Text("address").frame(width: 100, alignment: .trailing)
                            Spacer()
                            TextField("Enter address", text: $item.address)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .padding(.leading, 8)
                            Spacer()
                            Text("port")
                            TextField("Enter port", text: $item.address)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .padding(.leading, 8).frame(width: 100)
                        }
                          HStack {
                              Text("id").frame(width: 100, alignment: .trailing)
                              Spacer()
                              TextField("Enter id", text: $item.id)
                                  .textFieldStyle(RoundedBorderTextFieldStyle())
                                  .padding(.leading, 8)
                              
                          }
                        HStack {
                            Text("alterId").frame(width: 100, alignment: .trailing)
                            TextField("Enter alterId", text: $item.address)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .padding(.leading, 8).frame(width: 100)
                            Spacer()
                            Text("security")
                            Picker("", selection: $item.security) {
                                ForEach(V2rayProtocolOutbound.allCases) { pick in
                                    Text(pick.rawValue)
                                }
                            }
                        }
                    }
                    if item.protocol == .vless {
                        HStack {
                            Text("address").frame(width: 100, alignment: .trailing)
                            Spacer()
                            TextField("Enter address", text: $item.address)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .padding(.leading, 8)
                            Spacer()
                            Text("port")
                            TextField("Enter port", text: $item.address)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .padding(.leading, 8).frame(width: 100)
                        }
                          HStack {
                              Text("id").frame(width: 100, alignment: .trailing)
                              Spacer()
                              TextField("Enter id", text: $item.id)
                                  .textFieldStyle(RoundedBorderTextFieldStyle())
                                  .padding(.leading, 8)
                              
                          }
                        
                        HStack {
                            Text("alterId").frame(width: 100, alignment: .trailing)
                            TextField("Enter alterId", text: $item.address)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .padding(.leading, 8).frame(width: 100)
                            Spacer()
                            Text("security")
                            Picker("", selection: $item.security) {
                                ForEach(V2rayProtocolOutbound.allCases) { pick in
                                    Text(pick.rawValue)
                                }
                            }
                        }
                    
                        HStack {
                            Text("flow").frame(width: 100, alignment: .trailing)
                            TextField("Enter flow", text: $item.address)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .padding(.leading, 8).frame(width: 100)
                            
                        }
                    }
                }
                if item.protocol == .shadowsocks {
                    HStack {
                        Text("address").frame(width: 100, alignment: .trailing)
                        Spacer()
                        TextField("Enter address", text: $item.address)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .padding(.leading, 8)
                        Spacer()
                        Text("port")
                        TextField("Enter port", text: $item.address)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .padding(.leading, 8).frame(width: 100)
                    }
                    HStack {
                        Text("password").frame(width: 100, alignment: .trailing)
                        Spacer()
                        TextField("Enter password", text: $item.id)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .padding(.leading, 8)
                    }
                    HStack {
                        Text("method").frame(width: 100, alignment: .trailing)
                        Picker("", selection: $item.security) {
                            ForEach(V2rayProtocolOutbound.allCases) { pick in
                                Text(pick.rawValue)
                            }
                        }
                    }
                }
            }
        }.padding(20)
        Spacer()
    }
}

#Preview {
    ConfigServerView(item: ProxyModel(protocol: .trojan, address: "dss", port: 443, id: "aaa", security: "auto", remark: "test01"))
}
