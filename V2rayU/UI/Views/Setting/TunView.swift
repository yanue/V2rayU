import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct TunView: View {
    private enum ProcessRoute: Hashable {
        case direct
        case proxy
    }

    private enum ProcessRuleTarget: Hashable {
        case application(path: String)
        case process(name: String)

        var id: String {
            switch self {
            case let .application(path): return "application:\(path)"
            case let .process(name): return "process:\(name)"
            }
        }
    }

    private struct ProcessRule: Identifiable {
        let target: ProcessRuleTarget
        let route: ProcessRoute

        var id: String { target.id }
    }

    @ObservedObject var settings = AppSettings.shared
    @State private var showIPv6Warning = false
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
        let directApplicationPaths = TunConfigHandler.normalizeApplicationPaths(settings.tunDirectApplicationPaths)
        let directApplicationPathKeys = Set(directApplicationPaths)
        let proxyApplicationPaths = TunConfigHandler.normalizeApplicationPaths(settings.tunProxyApplicationPaths)
            .filter { !directApplicationPathKeys.contains($0) }

        let directProcessNames = TunConfigHandler.parseProcessNames(settings.tunDirectProcessNames)
        let directProcessNameKeys = Set(directProcessNames)
        let proxyProcessNames = TunConfigHandler.parseProcessNames(settings.tunProxyProcessNames)
            .filter { !directProcessNameKeys.contains($0) }

        return directApplicationPaths.map {
            ProcessRule(target: .application(path: $0), route: .direct)
        } + directProcessNames.map {
            ProcessRule(target: .process(name: $0), route: .direct)
        } + proxyApplicationPaths.map {
            ProcessRule(target: .application(path: $0), route: .proxy)
        } + proxyProcessNames.map {
            ProcessRule(target: .process(name: $0), route: .proxy)
        }
    }

    private var processAlertTitle: String {
        String(localized: pendingProcessRoute == .direct ? .AddDirectProcess : .AddProxyProcess)
    }

    private func processRuleRow(_ rule: ProcessRule) -> some View {
        let applicationURL: URL?
        let displayName: String
        let subtitle: String
        let detail: String

        switch rule.target {
        case let .application(path):
            let url = URL(fileURLWithPath: path)
            applicationURL = url
            displayName = applicationDisplayName(for: url)
            subtitle = String(localized: .ApplicationBundleRule)
            detail = path
        case let .process(name):
            applicationURL = nil
            displayName = name
            subtitle = "\(String(localized: .ProcessName)): \(name)"
            detail = String(format: String(localized: .ProcessOnlyRule), name)
        }

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
                Text(subtitle)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                Text(detail)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .help(detail)
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
                removeRule(rule.target)
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
            set: { moveRule(rule.target, to: $0) }
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
        let applicationPaths = panel.urls.map { applicationURL in
            applicationURL.resolvingSymlinksInPath().standardizedFileURL.path
        }
        addApplicationPaths(applicationPaths, to: route)
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
            switch route {
            case .direct:
                proxy.removeAll { $0 == processName }
                if !direct.contains(processName) {
                    direct.append(processName)
                }
            case .proxy:
                direct.removeAll { $0 == processName }
                if !proxy.contains(processName) {
                    proxy.append(processName)
                }
            }
        }

        settings.tunDirectProcessNames = direct.joined(separator: "\n")
        settings.tunProxyProcessNames = proxy.joined(separator: "\n")
    }

    private func addApplicationPaths(_ applicationPaths: [String], to route: ProcessRoute) {
        var direct = TunConfigHandler.normalizeApplicationPaths(settings.tunDirectApplicationPaths)
        var proxy = TunConfigHandler.normalizeApplicationPaths(settings.tunProxyApplicationPaths)

        for path in TunConfigHandler.normalizeApplicationPaths(applicationPaths) {
            switch route {
            case .direct:
                proxy.removeAll { $0 == path }
                if !direct.contains(path) {
                    direct.append(path)
                }
            case .proxy:
                direct.removeAll { $0 == path }
                if !proxy.contains(path) {
                    proxy.append(path)
                }
            }
        }

        settings.tunDirectApplicationPaths = direct
        settings.tunProxyApplicationPaths = proxy
    }

    private func moveRule(_ target: ProcessRuleTarget, to route: ProcessRoute) {
        switch target {
        case let .application(path):
            addApplicationPaths([path], to: route)
        case let .process(name):
            addProcessNames([name], to: route)
        }
    }

    private func removeRule(_ target: ProcessRuleTarget) {
        switch target {
        case let .application(path):
            settings.tunDirectApplicationPaths = TunConfigHandler.normalizeApplicationPaths(settings.tunDirectApplicationPaths)
                .filter { $0 != path }
            settings.tunProxyApplicationPaths = TunConfigHandler.normalizeApplicationPaths(settings.tunProxyApplicationPaths)
                .filter { $0 != path }
        case let .process(name):
            let direct = TunConfigHandler.parseProcessNames(settings.tunDirectProcessNames)
                .filter { $0 != name }
            let proxy = TunConfigHandler.parseProcessNames(settings.tunProxyProcessNames)
                .filter { $0 != name }

            settings.tunDirectProcessNames = direct.joined(separator: "\n")
            settings.tunProxyProcessNames = proxy.joined(separator: "\n")
        }
    }

    private func applicationDisplayName(for url: URL) -> String {
        let bundle = Bundle(url: url)
        return bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? url.deletingPathExtension().lastPathComponent
    }
}
