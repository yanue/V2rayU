//
//  Overview.swift
//  V2rayU
//
//  Created by yanue on 2024/12/17.
//

import SwiftUI
import SwiftUI

struct ActivityView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            
            // Header Section
            Text("Activity")
                .font(.title)
                .fontWeight(.bold)
            
            // Tabs
            HStack {
                TabItem(name: "Latency", selected: true)
                TabItem(name: "Traffic", selected: false)
                TabItem(name: "Interfaces", selected: false)
            }
            
            // Cards: Router, DNS, Internet, Proxy
            HStack(spacing: 12) {
                CardView(title: "ROUTER", value: "≤1", unit: "ms", color: .cyan)
                CardView(title: "DNS", value: "3", unit: "ms", color: .purple)
                CardView(title: "INTERNET", value: "60", unit: "ms", color: .blue)
                CardView(title: "Proxy", value: "157", unit: "ms", color: .orange)
            }
            
            // Network Info
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("UPLOAD")
                        .font(.caption)
                        .foregroundColor(.pink)
                    Text("2 KB/s")
                        .font(.headline)
                }
                Spacer()
                VStack(alignment: .leading, spacing: 8) {
                    Text("DOWNLOAD")
                        .font(.caption)
                        .foregroundColor(.blue)
                    Text("4 KB/s")
                        .font(.headline)
                }
                Spacer()
                VStack(alignment: .leading, spacing: 8) {
                    Text("ACTIVE CONNECTIONS")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("10")
                        .font(.headline)
                }
                Spacer()
                VStack(alignment: .leading, spacing: 8) {
                    Text("TOTAL")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("63.4 MB")
                        .font(.headline)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
            
            // Network History Chart
            VStack(alignment: .leading) {
                Text("Network History")
                    .font(.headline)
                // Replace this placeholder with a chart view or graph.
                Rectangle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(height: 100)
                    .cornerRadius(10)
            }
            
            // Event Log
            VStack(alignment: .leading) {
                Text("Events")
                    .font(.headline)
                EventLogItem(timestamp: "2023/4/6, 3:03:49 PM", message: "SOCKS5 proxy listen on interface: 127.0.0.1, port: 6153")
                EventLogItem(timestamp: "2023/4/6, 3:03:49 PM", message: "HTTP proxy listen on interface: 127.0.0.1, port: 6152")
            }
            
            Spacer()
        }
        .padding()
    }
}

// Subviews

struct TabItem: View {
    var name: String
    var selected: Bool
    
    var body: some View {
        Text(name)
            .font(.subheadline)
            .foregroundColor(selected ? .black : .gray)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(selected ? Color.gray.opacity(0.2) : Color.clear)
            .cornerRadius(8)
    }
}

struct CardView: View {
    var title: String
    var value: String
    var unit: String
    var color: Color
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.caption)
                .foregroundColor(color)
            HStack {
                Text(value)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Text(unit)
                    .font(.caption)
            }
        }
        .padding()
        .frame(width: 80, height: 80)
        .background(color.opacity(0.1))
        .cornerRadius(10)
    }
}

struct EventLogItem: View {
    var timestamp: String
    var message: String
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("INFO")
                    .foregroundColor(.green)
                    .font(.caption)
                Text(timestamp)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            Text(message)
                .font(.footnote)
        }
        .padding(.vertical, 4)
    }
}

struct ActivityView_Previews: PreviewProvider {
    static var previews: some View {
        ActivityView()
    }
}
