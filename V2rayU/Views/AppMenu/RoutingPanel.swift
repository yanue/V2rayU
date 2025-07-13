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
    @State private var isTransitioning: Bool = false

    var count: Int {
        return routingModel.list.count
    }
    var name: String {
        return routingModel.list.first(where: { $0.uuid == appState.runningRouting })?.remark ?? ""
    }

    var body: some View {
        VStack(spacing: 0) {
            GroupBox("Routing") {
                Button(action: {
                    if isTransitioning { return }
                    isTransitioning = true
                    isExpanded.toggle()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        isTransitioning = false
                    }
                }) {
                    HStack {
                        HStack(spacing: 12) {
                            Image(systemName: "arrow.triangle.branch")
                                .foregroundColor(.white)
                                .frame(width: 16, height: 16)
                                .padding(8)
                                .background(appState.v2rayTurnOn ? Color.blue : Color.gray)
                                .clipShape(Circle())
                            VStack(alignment: .leading) {
                                HStack {
                                    Text("Routing")
                                        .font(.system(size: 13))
                                    Text("(\(count))")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.gray)
                                }
                                Text(name)
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.blue)
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    }
                    .padding(.horizontal,8)
                    .padding(.vertical,4)
                    .contentShape(Rectangle())
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .buttonStyle(.plain)

                if isExpanded {
                    VStack {
                        Divider()
                        ScrollView {
                            VStack(spacing: 4) {
                                ForEach(routingModel.list) { item in
                                    MenuRoutingRow(name: item.remark, isSelected: item.uuid == appState.runningRouting)
                                        .padding(.horizontal)
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            appState.runRouting(uuid: item.uuid)
                                        }
                                }
                            }
                        }
                        .frame(height:  130)
                    }
                    .padding(.top, 4)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .animation(.easeInOut(duration: 0.3), value: isExpanded)
                }
            }
        }
        .onAppear {
            routingModel.getList()
        }
        .id("routing-panel")
    }
}

// Supporting Components and Models
struct MenuRoutingRow: View {
    let name: String
    let isSelected: Bool

    var body: some View {
        HStack {
            // Network Name
            Text(name)
                .foregroundColor(isSelected ? .blue : .primary)

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
