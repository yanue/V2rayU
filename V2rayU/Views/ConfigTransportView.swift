//
//  TransportView.swift
//  V2rayU
//
//  Created by yanue on 2024/11/24.
//
import SwiftUI


struct ConfigTransportView: View {
    @ObservedObject var item: ProxyModel
    var body: some View{
        HStack {
            VStack{
                Section(header: Text("Transport Settings")) {
                    HStack {
                        Text("Security").frame(width: 120, alignment: .trailing)
                        Spacer()
                        Picker("", selection: $item.streamSecurity) {
                            ForEach(V2rayStreamSecurity.allCases) { pick in
                                Text(pick.rawValue)
                            }
                        }
                    }
                    HStack {
                        Text("serverName(SNI)").frame(width: 120, alignment: .trailing)
                        Spacer()

                        TextField("Enter serverName(SNI)", text: $item.sni)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .padding(8)
                        
                        Spacer()
                        Toggle("allowInsecure", isOn: $item.allowInsecure).frame(alignment: .leading)
                            .toggleStyle(SwitchToggleStyle(tint: .blue))
                    }
                    HStack {
                        Text("fingerprint").frame(width: 120, alignment: .trailing)
                        Spacer()
                        Picker("", selection: $item.fingerprint) {
                            ForEach(V2rayStreamFingerprint.allCases) { pick in
                                Text(pick.rawValue)
                            }
                        }
                    }
                    if item.streamSecurity == .reality {
                        HStack {
                            Text("PublicKey").frame(width: 120, alignment: .trailing)
                            Spacer()
                            TextField("Enter PublicKey", text: $item.publicKey)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .padding(.leading,8)
                        }
                        HStack {
                            Text("ShortId").frame(width: 120, alignment: .trailing)
                            Spacer()
                            TextField("Enter ShortId", text: $item.shortId)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .padding(.leading,8)
                        }
                        HStack {
                            Text("spiderX").frame(width: 120, alignment: .trailing)
                            Spacer()
                            TextField("Enter spiderX", text: $item.spiderX)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .padding(.leading,8)
                            
                        }
                    } else {
                        HStack {
                            Text("Alpn").frame(width: 120, alignment: .trailing)
                            Spacer()
                            Picker("", selection: $item.alpn) {
                                ForEach(V2rayStreamAlpn.allCases) { pick in
                                    Text(pick.rawValue)
                                }
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
    ConfigTransportView(item: ProxyModel(protocol: .trojan, address: "dss", port: 443, id: "aaa", security: "auto", remark: "test01"))
}
