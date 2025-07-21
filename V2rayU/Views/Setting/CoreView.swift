//
//  CoreView.swift
//  V2rayU
//
//  Created by yanue on 2025/7/20.
//

import SwiftUI

struct CoreView: View {
    @State private var xrayCoreVersion: String = "Unknown"
    @State private var v2rayCoreVersion: String = "Unknown"
    @State private var singBoxCoreVersion: String = "Unknown"
    
    var body: some View {
        VStack() {
            
            HStack{
                Image(systemName: "crown")
                    .resizable()
                    .frame(width: 28, height: 28)
                    .foregroundColor(.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Core Settings")
                        .font(.title)
                        .fontWeight(.bold)
                    Text("Manage your core versions")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding()

            List {
                Section(header: Text("Xray Core Version")) {
                    Text(xrayCoreVersion)
                }
                Section(header: Text("V2Ray Core Version")) {
                    Text(v2rayCoreVersion)
                }
                Section(header: Text("SingBox Core Version")) {
                    Text(singBoxCoreVersion)
                }
            }
            .listStyle(PlainListStyle())
            
            Button("Check Versions") {
                checkVersions()
            }
            .buttonStyle(.borderedProminent)
            .padding()


            
        }.onAppear {
            loadCoreVersions()
        }
    }
        
    private func loadCoreVersions() {
        if let xrayVersion = UserDefaults.standard.string(forKey: "xrayCoreVersion") {
            xrayCoreVersion = xrayVersion
        }
        if let v2rayVersion = UserDefaults.standard.string(forKey: "v2rayCoreVersion") {
            v2rayCoreVersion = v2rayVersion
        }
        if let singBoxVersion = UserDefaults.standard.string(forKey: "singBoxCoreVersion") {
            singBoxCoreVersion = singBoxVersion
        }
    }
    
    private func checkVersions() {
        // 这里可以添加检查版本的逻辑
        // 比如调用 API 或者读取文件等
    }

}
