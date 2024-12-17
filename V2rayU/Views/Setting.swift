import SwiftUI
import KeyboardShortcuts

struct SettingView: View {
    @State private var selectedTab: ActivityTab = .latency
    
    // Enum for Tabs
    enum ActivityTab {
        case latency
        case traffic
        case interfaces
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header Section
            Text("Activity")
                .font(.title)
                .fontWeight(.bold)
            
            // Segmented Picker (Tabs)
            Picker("", selection: $selectedTab) {
                Text("General").tag(ActivityTab.latency)
                Text("Advance").tag(ActivityTab.traffic)
                Text("Interfaces").tag(ActivityTab.interfaces)
            }
            .pickerStyle(.segmented).padding(0)
            
            // Content based on Selected Tab
            VStack {
                switch selectedTab {
                case .latency:
                    GeneralView()
                case .traffic:
                    TrafficView()
                case .interfaces:
                    InterfacesView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding()
    }
}

// Placeholder Views for Content
extension KeyboardShortcuts.Name {
    static let toggleV2rayOnOff = Self("toggleV2rayOnOff")
    static let swiftProxyMode = Self("swiftProxyMode")
}

struct GeneralView: View {
    @State private var launchAtLogin = true
    @State private var checkForUpdates = false
    @State private var autoUpdateServers = true
    @State private var selectFastestServer = false
    
    @State private var v2rayShortcut: String = ""
    @State private var proxyModeShortcut: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Form {
                Section {
                    Toggle("Launch V2rayU at login", isOn: $launchAtLogin)
                    Toggle("Check for updates automatically", isOn: $checkForUpdates)
                    Toggle("Automatically update servers from subscriptions", isOn: $autoUpdateServers)
                    Toggle("Automatically select fastest server", isOn: $selectFastestServer)
                }
                
                Section(header: Text("Shortcuts")) {
                    HStack {
                        KeyboardShortcuts.Recorder("Toggle V2ray On/Off:", name: .toggleV2rayOnOff)
                    }
                    HStack{
                        KeyboardShortcuts.Recorder("Switch Proxy Mode:", name: .swiftProxyMode)
                    }
                }
                
                Section(header: Text("Related file locations")) {
                    Text("~/.V2rayU/")
                    Text("~/Library/Preferences/net.yanue.V2rayU.plist")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            HStack {
                Button("Check for Updates...") {
                    // Implement update check logic
                }
                Spacer()
                Button("Feedback...") {
                    // Implement feedback logic
                }
            }
            .padding()
        }
        .frame(width: 500, height: 400)
    }
}

struct TrafficView: View {
    var body: some View {
        Text("Traffic Data")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.green.opacity(0.1))
            .cornerRadius(8)
    }
}

struct InterfacesView: View {
    var body: some View {
        Text("Interfaces Data")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.orange.opacity(0.1))
            .cornerRadius(8)
    }
}

struct SettingView_Previews: PreviewProvider {
    static var previews: some View {
        SettingView()
    }
}
