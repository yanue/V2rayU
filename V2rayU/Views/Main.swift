//
//  Config.swift
//  V2rayU
//
//  Created by yanue on 2024/11/23.
//
import SwiftUI


struct ContentView: View {
    @State private var isOverrideEnabled = false
    @State private var isRewriteEnabled = false
    @State private var isMitMEnabled = false
    @State private var isScriptEnabled = false
    
    var body: some View {
        HStack{
            VStack{
                VStack(spacing: 20) {
                    createTabView(image: "star.fill", text: "Override", isOn: $isOverrideEnabled)
                    createTabView(image: "hammer", text: "Rewrite", isOn: $isRewriteEnabled)
                    createTabView(image: "lock", text: "MitM", isOn: $isMitMEnabled)
                    createTabView(image: "f.square", text: "Script", isOn: $isScriptEnabled)
                }
                 // 列表
            }.padding()
            
            Divider() // 分隔线，适当调整宽度

            VStack{
                ConfigListView()
                RoutingListView()
                SubListView()
            }.padding()
            
        }
    }
    
    private func createTabView(image: String, text: String, isOn: Binding<Bool>) -> some View {
        VStack(spacing: 10) {
            Image(systemName: image)
                .resizable()
                .frame(width: 30, height: 30)
            
            Toggle(isOn: isOn) {
                Text(text)
                    .font(.body)
            }
        }
        .background(
            LinearGradient(gradient: Gradient(colors: [Color.blue, Color.purple]), startPoint: .leading, endPoint: .trailing)
        )
        .cornerRadius(10)
    }
}

#Preview {
    ContentView()
}
