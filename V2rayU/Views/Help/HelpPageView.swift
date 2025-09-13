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
        case diagnostic
        case qa
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
                }.padding(.bottom, 10)

                // Segmented Picker (Tabs)
                Picker("", selection: $appState.helpTab) {
                    localized(.Diagnostics).tag(HelpTab.diagnostic)
                    localized(.QA).tag(HelpTab.qa)
                }
                .pickerStyle(.segmented)
                
                Spacer()

                // Content based on Selected Tab
                HStack{
                    VStack {
                        switch appState.helpTab {
                        case .diagnostic:
                            DiagnosticsView()
                        case .qa:
                            QAView()
                        }
                    }
                }
             }
         }
     }
 }
