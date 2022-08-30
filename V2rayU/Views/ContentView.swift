//
//  ContentView.swift
//  V2rayU
//
//  Created by yanue on 2022/8/29.
//

import SwiftUI

struct ContentView: View {
    @Environment(\.openURL) var openURL

    var body: some View {
        Button("Other View") {
           if let url = URL(string: "V2rayU://otherview") {
               openURL(url)
           }
       }
        NavigationView {
            SidebarView()
            ConfigView()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}



