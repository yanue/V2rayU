//
//  GeneralView.swift
//  V2rayU
//
//  Created by yanue on 2022/9/27.
//

import SwiftUI

struct GeneralView: View {
    @EnvironmentObject var store: V2rayUStore
    @State private var fullText: String = """
   ~/.V2rayU/
   ~/Library/LaunchAgents/yanue.v2rayu.v2ray-core.plist
   ~/Library/Preferences/net.yanue.V2rayU.plist
"""
    
    var body: some View {
        VStack(alignment: .leading){
            Toggle(isOn: $store.autoLaunch) {
                Text("Launch V2rayU at login")
            }.toggleStyle(CheckboxToggleStyle())
            Toggle(isOn: $store.autoCheckVersion) {
                Text("Check for updates automutically")
            }.toggleStyle(CheckboxToggleStyle())
            Toggle(isOn: $store.autoUpdateServers) {
                Text("Automatically update servers from subscriptions")
            }.toggleStyle(CheckboxToggleStyle())
            
            Spacer()
            
            Text("Related file locations")
            TextEditor(text: $fullText)
                .foregroundColor(Color.gray)
                .lineSpacing(5)
                .padding()
        }.padding(20)
    }
}

struct General_Previews: PreviewProvider {
    static var previews: some View {
        GeneralView().environmentObject(V2rayUStore.shared)
    }
}
