//
//  LogsPage.swift
//  V2rayU
//
//  Created by yanue on 2025/7/15.
//

import SwiftUI
import AppKit

struct HelpPageView: View {
    @ObservedObject var appState = AppState.shared // 引用单例

    // Enum for Tabs
    enum HelpTab {
        case qa
        case about
    }

    var body: some View {
        VStack {
            VStack() {
                HStack {
                    Image(systemName: "questionmark.circle")
                        .resizable()
                        .frame(width: 28, height: 28)
                        .foregroundColor(.accentColor)
                    VStack(alignment: .leading, spacing: 2) {
                        localized(.HelpPageTitle)
                            .font(.title)
                            .fontWeight(.bold)
                        localized(.HelpPageSubHead)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    // 如果不想用自定义图片，可以用 SF Symbols 代替
                    Link(destination: URL(string: "https://github.com/yanue/V2rayU/issues")!) {
                        Label(String(localized: .GithubIssues), systemImage: "link") // 用 link 图标代替
                           .padding()
                           .cornerRadius(8)
                    }
                }.padding(.bottom, 10)

                // Segmented Picker (Tabs)
                Picker("", selection: $appState.helpTab) {
                    localized(.FAQ).tag(HelpTab.qa)
                    localized(.About).tag(HelpTab.about)
                }
                .pickerStyle(.segmented)
                
                Spacer()

                // Content based on Selected Tab
                HStack{
                    VStack {
                        switch appState.helpTab {
                        case .qa:
                            FAQView()
                        case .about:
                            AboutView()
                        }
                    }
                }
             }
         }
     }
 }
