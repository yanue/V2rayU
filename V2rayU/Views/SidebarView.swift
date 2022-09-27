//
//  Sidebar.swift
//  V2rayU
//
//  Created by yanue on 2022/8/26.
//

import SwiftUI

struct SidebarView: View {
    @EnvironmentObject var store: V2rayUStore
    
    var body: some View {
        VStack {
            List(selection: $store.selectedView) {
                Section(header: Text("Configure")) {
                    NavigationLink(destination: ConfigView()) {
                        HStack(spacing: 4) {
                            Image(systemName: "network")
                                .resizable()
                                .foregroundColor(Color.orange)
                                .frame(width: 18, height: 18)
                                .padding(.all, 2)
                            Text("Servers")
                                .font(.body)
                                .foregroundColor(.primary)
                        }
                        .tag(V2rayUPanelViewType.servers)
                    }
                    
                    NavigationLink(destination:SubscriptionView()) {
                        HStack(spacing: 4) {
                            Image(systemName: "bolt.horizontal.circle")
                                .resizable()
                                .foregroundColor(Color.blue)
                                .frame(width: 18, height: 18)
                                .padding(.all, 2)
                            Text("Subscribtions")
                                .font(.body)
                                .foregroundColor(.primary)
                        }
                        .tag(V2rayUPanelViewType.subscribtions)
                    }
                    
                    NavigationLink(destination:RoutingView()) {
                        HStack(spacing: 4) {
                            Image(systemName: "repeat.circle")
                                .resizable()
                                .renderingMode(.original)
                                .frame(width: 18, height: 18)
                                .padding(.all, 2)
                                .foregroundColor(Color.green)
                            Text("Routes")
                                .font(.body)
                        }
                        .tag(V2rayUPanelViewType.routes)
                    }
                }
                
                Section(header: Text("Preferences")) {
                    NavigationLink(destination:GeneralView()) {
                        HStack(spacing: 4) {
                            Image(systemName: "gearshape")
                                .resizable()
                                .renderingMode(.original)
                                .frame(width: 18, height: 18)
                                .padding(.all, 2)
                                .foregroundColor(Color.cyan)
                            Text("General")
                                .font(.body)
                                .foregroundColor(.primary)
                            
                        }
                    }
                    
                    NavigationLink(destination:AdvanceView()) {
                        HStack(spacing: 4) {
                            Image(systemName: "gear")
                                .resizable()
                                .renderingMode(.original)
                                .foregroundColor(Color.indigo)
                                .frame(width: 18, height: 18)
                                .padding(.all, 2)
                            Text("Advance")
                                .font(.body)
                                .foregroundColor(.primary)
                        }
                    }
                }
            }
            .listStyle(.sidebar)
        }
        .frame(minWidth: 200)
        .padding(10)
    }
}

struct Sidebar_Previews: PreviewProvider {
    static var previews: some View {
        SidebarView()
    }
}
