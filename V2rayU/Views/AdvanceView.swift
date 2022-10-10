//
//  AdvanceView.swift
//  V2rayU
//
//  Created by yanue on 2022/9/27.
//

import SwiftUI

struct AdvanceView: View {
    @EnvironmentObject var store: V2rayUStore
    
    var body: some View {
        VStack(alignment: .leading){
            Form {
                HStack(){
                    Text("V2ray Core Log Level").frame(width: 180,alignment: .trailing)
                    Picker("", selection: $store.v2rayLogLevel) {
                        Text("none").tag("none")
                        Text("error").tag("error")
                        Text("warning").tag("warning")
                        Text("info").tag("info")
                        Text("debug").tag("debug")
                    }.frame(width: 200)
                }
                HStack(){
                    Text("Local Sock Listen Host").frame(width: 180,alignment: .trailing)
                    TextField("", text: $store.localSockHost).frame(width: 200)
                }
                HStack(){
                    Text("Local Sock Listen Port").frame(width: 180,alignment: .trailing)
                    TextField("", text: $store.localSockPort).frame(width: 200)
                }
                HStack(){
                    Text("Local Http Listen Host").frame(width: 180,alignment: .trailing)
                    TextField("", text: $store.localHttpHost).frame(width: 200)
                }
                HStack(){
                    Text("Local Http Listen Port").frame(width: 180,alignment: .trailing)
                    TextField("", text: $store.localHttpPort).frame(width: 200)
                }
                HStack(){
                    Toggle(isOn: $store.enableUdp) {
                        Text("Enable UDP")
                    }.toggleStyle(CheckboxToggleStyle())
                }
                HStack(){
                    Toggle(isOn: $store.enableMux) {
                        Text("Enable Mux")
                    }.toggleStyle(CheckboxToggleStyle())
                }
                HStack(){
                    Toggle(isOn: $store.enableSniffing) {
                        Text("Enable sniffing")
                    }.toggleStyle(CheckboxToggleStyle())
                }

            }
        }
    }
}

struct Advance_Previews: PreviewProvider {
    static var previews: some View {
        AdvanceView().environmentObject(V2rayUStore.shared)
    }
}
