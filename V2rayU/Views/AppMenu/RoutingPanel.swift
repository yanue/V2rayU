//
//  Routing.swift
//  V2rayU
//
//  Created by yanue on 2025/1/8.
//

import SwiftUI

struct MenuRoutingPanel: View {
    @ObservedObject var appState = AppState.shared // 引用单例
    @StateObject private var routingModel = RoutingViewModel()
    @State private var isExpanded = false

    var body: some View {
        // Bluetooth and AirDrop
        HStack(spacing: 8) {
            GroupBox("mode") {
                // Network List
                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(routingModel.list) { item in
                            MenuRoutingRow(item: item, isSelected: item.uuid == appState.runningRouting)
                                .padding(.horizontal)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    appState.runRouting(uuid: item.uuid)
                                }
                        }
                    }
                }
                .frame(height: 30)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(.top, 4)
            }

            GroupBox("routing") {
                // Network List
                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(routingModel.list) { item in
                            MenuRoutingRow(item: item, isSelected: item.uuid == appState.runningRouting)
                                .padding(.horizontal)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    appState.runRouting(uuid: item.uuid)
                                }
                        }
                    }
                }
                .frame(height: 30)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(.top, 4)
            }
        }
        .padding(.horizontal,16)
        .onAppear {
            routingModel.getList()
        }
    }
}

// Supporting Components and Models
struct MenuRoutingRow: View {
    let item: RoutingModel
    let isSelected: Bool

    var body: some View {
        HStack {
            // Network Icon
            Image(systemName: "wifi")
                .foregroundColor(isSelected ? .blue : .primary)

            // Network Name
            Text(item.name)
                .font(.system(size: 13))

            Spacer()

            // Connected Check
            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundColor(.blue)
            }
        }
        .padding(.vertical, 6)
    }
}
