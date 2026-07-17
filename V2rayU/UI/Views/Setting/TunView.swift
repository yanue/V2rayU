import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct TunView: View {
    private enum ProcessRoute: Hashable {
        case direct
        case proxy

        var label: LanguageLabel {
            switch self {
            case .direct: return .Direct
            case .proxy: return .Proxy
            }
        }
    }

    private struct ProcessRule: Identifiable {
        let processName: String
        let route: ProcessRoute

        var id: String { processName.lowercased() }
    }

    @ObservedObject var settings = AppSettings.shared
    @State private var showIPv6Warning = false
    @State private var applicationURLs: [String: URL] = [:]
    @State private var showAddProcess = false
    @State private var pendingProcessName = ""
    @State private var pendingProcessRoute: ProcessRoute = .direct
    private let labelWidth: CGFloat = 150

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(String(localized: .TunSettings))
                    .font(.headline)
                    .foregroundColor(.secondary)

                // MARK: - 基本设置

                HStack {
                    getTextLabel(label: .TunAddress, labelWidth: labelWidth)
                    TextField(String(localized: .TunAddress), text: $settings.tunAddress)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.leading, 7)
                    Spacer()
                }

                HStack {
                    getTextLabel(label: .TunAddressIPv6, labelWidth: labelWidth)
                    TextField(String(localized: .TunAddressIPv6), text: $settings.tunAddressIPv6)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.leading, 7)
                }

                HStack {
                    getTextLabel(label: .TunMtu, labelWidth: labelWidth)
                    TextField(String(localized: .TunMtu), value: $settings.tunMtu, formatter: NumberFormatter())
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.leading, 7)
                    Spacer()
                }

                HStack {
                    getTextLabel(label: .TunStack, labelWidth: labelWidth)
                    Picker("", selection: $settings.tunStack) {
                        ForEach(TunStack.allCases, id: \.self) { pick in
                            Text(pick.rawValue)
                        }
                    }
                    .padding(.leading, 7)
                    Spacer()
                }

                HStack {
                    getTextLabel(label: .TunLogLevel, labelWidth: labelWidth)
                    Picker("", selection: $settings.tunLogLevel) {
                        ForEach(V2rayLogLevel.allCases, id: \.self) { pick in
                            Text(pick.rawValue)
                        }
                    }
                    .padding(.leading, 7)
                    Spacer()
                }

                // MARK: - 路由 & IPv6

                HStack {
                    Spacer().frame(width: labelWidth)
                    Toggle(isOn: $settings.tunStrictRoute) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(String(localized: .TunStrictRoute))
                            Text(String(localized: .TunStrictRouteTip))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Spacer().frame(width: labelWidth)
                        Toggle(isOn: $settings.tunEnableIPv6) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(String(localized: .TunEnableIPv6))
                                Text(String(localized: .TunEnableIPv6Tip))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                    }

                    if settings.tunEnableIPv6 {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Toggle(isOn: $settings.tunShowIPv6Reminder) {
                                    Text(String(localized: .TunShowIPv6Reminder))
                                        .font(.caption)
                                }
                                Spacer()
                            }
                        }
                        .padding(8)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                        )
                        .padding(.leading, labelWidth + 20)
                    }
                }

                HStack {
                    Spacer().frame(width: labelWidth)
                    Toggle(isOn: $settings.tunAutoRebuild) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(String(localized: .TunAutoRebuild))
                            Text(String(localized: .TunAutoRebuildTip))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                }

                HStack(alignment: .top) {
                    getTextLabel(label: .TunRouteExcludeHosts, labelWidth: labelWidth)
                    VStack(alignment: .leading, spacing: 4) {
                        TextEditor(text: $settings.tunRouteExcludeHosts)
                            .font(.system(.body, design: .monospaced))
                            .frame(minHeight: 64, maxHeight: 80)
                            .padding(4)
                            .overlay {
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color(nsColor: .separatorColor))
                            }
                        Text(String(localized: .TunRouteExcludeHostsTip))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Divider()

                HStack {
                    Text(String(localized: .TunProcessRouting))
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Menu {
                        Button {
                            Task { await selectApplications(for: .direct) }
                        } label: {
                            Label(String(localized: .AddDirectApplication), systemImage: "app.badge")
                        }
                        Button {
                            Task { await selectApplications(for: .proxy) }
                        } label: {
                            Label(String(localized: .AddProxyApplication), systemImage: "network")
                        }
                        Divider()
                        Button {
                            beginAddingProcess(for: .direct)
                        } label: {
                            Label(String(localized: .AddDirectProcess), systemImage: "terminal")
                        }
                        Button {
                            beginAddingProcess(for: .proxy)
                        } label: {
                            Label(String(localized: .AddProxyProcess), systemImage: "terminal")
                        }
                    } label: {
                        Label(String(localized: .Add), systemImage: "plus")
                    }
                    .fixedSize()
                }

                VStack(spacing: 0) {
                    if processRules.isEmpty {
                        Label(String(localized: .NoProcessRules), systemImage: "app.dashed")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, minHeight: 64)
                    } else {
                        ForEach(Array(processRules.enumerated()), id: \.element.id) { index, rule in
                            processRuleRow(rule)
                            if index < processRules.count - 1 {
                                Divider()
                                    .padding(.leading, 48)
                            }
                        }
                    }
                }
                .padding(.horizontal, 10)
                .background(Color(nsColor: .controlBackgroundColor))
                .overlay {
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color(nsColor: .separatorColor))
                }

                Text(String(localized: .TunProcessRoutingTip))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Divider()

                // MARK: - DNS

                Text(String(localized: .TunDns))
                    .font(.headline)
                    .foregroundColor(.secondary)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        getTextLabel(label: .TunRemoteDns, labelWidth: labelWidth)
                        Picker("", selection: $settings.tunDnsRemote) {
                            Text("1.1.1.1 (Cloudflare)").tag("1.1.1.1")
                            Text("8.8.8.8 (Google)").tag("8.8.8.8")
                            Text("9.9.9.9 (Quad9)").tag("9.9.9.9")
                            Text("208.67.222.222 (OpenDNS)").tag("208.67.222.222")
                        }
                        .pickerStyle(.menu)
                        .frame(width: 220)
                    }
                    Label(String(localized: .TunRemoteDnsTip), systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.leading, labelWidth + 7)
                }

                HStack {
                    getTextLabel(label: .TunChinaDns, labelWidth: labelWidth)
                    TextField(String(localized: .TunChinaDns), text: $settings.tunDnsChina)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.leading, 7)
                    Spacer()
                }

                Divider()

                HStack {
                    Spacer()
                    Button(String(localized: .Save)) {
                        settings.saveSettings()
                    }
                    Spacer()
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onDisappear {
            AppSettings.shared.saveSettings()
        }
        .onAppear {
            resolveApplicationURLs()
        }
        .onChange(of: settings.tunEnableIPv6) { _, newValue in
            if newValue {
                showIPv6Warning = true
            }
        }
        .alert(String(localized: .TunEnableIPv6), isPresented: $showIPv6Warning) {
            Button(String(localized: .OK)) { }
        } message: {
            Text(String(localized: .TunEnableIPv6ChromeWarning))
        }
        .alert(processAlertTitle, isPresented: $showAddProcess) {
            TextField(String(localized: .ProcessName), text: $pendingProcessName)
            Button(String(localized: .Cancel), role: .cancel) { }
            Button(String(localized: .Add)) {
                addProcessNames([pendingProcessName], to: pendingProcessRoute)
            }
            .disabled(pendingProcessName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    private var processRules: [ProcessRule] {
        let direct = TunConfigHandler.parseProcessNames(settings.tunDirectProcessNames)
        let directKeys = Set(direct.map { $0.lowercased() })
        let proxy = TunConfigHandler.parseProcessNames(settings.tunProxyProcessNames)
            .filter { !directKeys.contains($0.lowercased()) }

        return direct.map { ProcessRule(processName: $0, route: .direct) }
            + proxy.map { ProcessRule(processName: $0, route: .proxy) }
    }

    private var processAlertTitle: String {
        String(localized: pendingProcessRoute == .direct ? .AddDirectProcess : .AddProxyProcess)
    }

    private func processRuleRow(_ rule: ProcessRule) -> some View {
        let applicationURL = applicationURLs[rule.id]
        let displayName = applicationURL.flatMap(applicationDisplayName) ?? rule.processName

        return HStack(spacing: 10) {
            Group {
                if let applicationURL {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: applicationURL.path))
                        .resizable()
                } else {
                    Image(systemName: "terminal")
                        .resizable()
                        .scaledToFit()
                        .padding(5)
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(displayName)
                    .fontWeight(.medium)
                    .lineLimit(1)
                Text("\(String(localized: .ProcessName)): \(rule.processName)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                Text(applicationURL?.path ?? String(format: String(localized: .ProcessOnlyRule), rule.processName))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .help(applicationURL?.path ?? rule.processName)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Picker("", selection: processRouteBinding(for: rule)) {
                Text(String(localized: .Direct)).tag(ProcessRoute.direct)
                Text(String(localized: .Proxy)).tag(ProcessRoute.proxy)
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .frame(width: 132)

            Button {
                removeProcessName(rule.processName)
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
            .help(String(localized: .Delete))
        }
        .padding(.vertical, 7)
    }

    private func processRouteBinding(for rule: ProcessRule) -> Binding<ProcessRoute> {
        Binding(
            get: { rule.route },
            set: { addProcessNames([rule.processName], to: $0) }
        )
    }

    @MainActor
    private func selectApplications(for route: ProcessRoute) async {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.resolvesAliases = true
        panel.allowedContentTypes = [.applicationBundle]
        panel.prompt = String(localized: .AddApplications)
        panel.directoryURL = URL(fileURLWithPath: "/Applications", isDirectory: true)

        guard await presentOpenPanel(panel) == .OK else { return }
        let processNames = panel.urls.compactMap { applicationURL -> String? in
            guard let processName = Bundle(url: applicationURL)?.executableURL?.lastPathComponent else {
                return nil
            }
            applicationURLs[processName.lowercased()] = applicationURL
            return processName
        }
        addProcessNames(processNames, to: route)
    }

    private func beginAddingProcess(for route: ProcessRoute) {
        pendingProcessName = ""
        pendingProcessRoute = route
        showAddProcess = true
    }

    private func addProcessNames(_ processNames: [String], to route: ProcessRoute) {
        var direct = TunConfigHandler.parseProcessNames(settings.tunDirectProcessNames)
        var proxy = TunConfigHandler.parseProcessNames(settings.tunProxyProcessNames)

        let normalizedProcessNames = TunConfigHandler.parseProcessNames(processNames.joined(separator: "\n"))
        for processName in normalizedProcessNames {
            let key = processName.lowercased()
            switch route {
            case .direct:
                proxy.removeAll { $0.lowercased() == key }
                if !direct.contains(where: { $0.lowercased() == key }) {
                    direct.append(processName)
                }
            case .proxy:
                direct.removeAll { $0.lowercased() == key }
                if !proxy.contains(where: { $0.lowercased() == key }) {
                    proxy.append(processName)
                }
            }
        }

        settings.tunDirectProcessNames = direct.joined(separator: "\n")
        settings.tunProxyProcessNames = proxy.joined(separator: "\n")
    }

    private func removeProcessName(_ processName: String) {
        let key = processName.lowercased()
        let direct = TunConfigHandler.parseProcessNames(settings.tunDirectProcessNames)
            .filter { $0.lowercased() != key }
        let proxy = TunConfigHandler.parseProcessNames(settings.tunProxyProcessNames)
            .filter { $0.lowercased() != key }

        settings.tunDirectProcessNames = direct.joined(separator: "\n")
        settings.tunProxyProcessNames = proxy.joined(separator: "\n")
        applicationURLs.removeValue(forKey: key)
    }

    private func resolveApplicationURLs() {
        let unresolvedKeys = Set(processRules.map(\.id)).subtracting(applicationURLs.keys)
        guard !unresolvedKeys.isEmpty else { return }

        let roots = [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications", isDirectory: true),
            URL(fileURLWithPath: "/System/Applications", isDirectory: true),
        ]

        for root in roots {
            guard let applications = try? FileManager.default.contentsOfDirectory(
                at: root,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ) else { continue }

            for applicationURL in applications where applicationURL.pathExtension.lowercased() == "app" {
                guard let processName = Bundle(url: applicationURL)?.executableURL?.lastPathComponent,
                      unresolvedKeys.contains(processName.lowercased()) else { continue }
                applicationURLs[processName.lowercased()] = applicationURL
            }
        }
    }

    private func applicationDisplayName(for url: URL) -> String {
        let bundle = Bundle(url: url)
        return bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? url.deletingPathExtension().lastPathComponent
    }
}
