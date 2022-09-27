//
//  Config.swift
//  V2rayU
//
//  Created by yanue on 2022/8/29.
//
//

import SwiftUI

struct ConfigView: View {
    @EnvironmentObject var store: V2rayUStore
    
    var body: some View {
        
        VStack {
            Button("Open Main View") {
                // magic here
                WinHelper.mainView.open()
            }
            
            Button("Open Other View") {
                // magic here
                WinHelper.advanceView.open()
            }
        }
        .frame(minWidth: 400)
    }
    
}

struct Config_Previews: PreviewProvider {
    static var previews: some View {
        ConfigView()
    }
}
