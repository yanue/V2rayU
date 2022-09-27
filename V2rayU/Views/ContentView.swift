//
//  ContentView.swift
//  V2rayU
//
//  Created by yanue on 2022/8/29.
//

import SwiftUI

struct ContentView: View {    
    var body: some View {
        NavigationView {
            SidebarView()
            ConfigView()
        }.navigationTitle("Settings")
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}



