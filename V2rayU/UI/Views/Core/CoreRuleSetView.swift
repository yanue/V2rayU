//
//  CoreRuleSetView.swift
//  V2rayU
//
//  核心页 Tab: 规则集更新 — geoip/geosite (xray) 与 .srs (sing-box) 的来源、自动更新周期和手动更新
//

import SwiftUI

@MainActor
final class RuleSetViewModel: ObservableObject {
    @Published var sources: [RuleSetSource] = RuleSetUpdater.sources
    @Published var autoUpdate: Bool = RuleSetUpdater.autoUpdate {
        didSet { RuleSetUpdater.autoUpdate = autoUpdate }
    }
    @Published var interval: Int = RuleSetUpdater.interval {
        didSet { RuleSetUpdater.interval = interval }
    }
    @Published var updating = false
    @Published var lastResult: RuleSetUpdateResult?
    @Published var lastUpdate: Date? = RuleSetUpdater.lastUpdate
    @Published var fileInfos: [String: (size: Int, modified: Date)] = [:]

    init() { refreshFileInfos() }

    func refreshFileInfos() {
        var infos: [String: (size: Int, modified: Date)] = [:]
        for s in sources {
            if let info = RuleSetUpdater.localFileInfo(s) { infos[s.id] = info }
        }
        fileInfos = infos
        lastUpdate = RuleSetUpdater.lastUpdate
    }

    func save() {
        sources = sources.map { s in
            var copy = s
            copy.url = s.url.trimmingCharacters(in: .whitespacesAndNewlines)
            return copy
        }
        RuleSetUpdater.sources = sources
    }

    func resetDefaults() {
        RuleSetUpdater.resetSources()
        sources = RuleSetSource.defaults
        refreshFileInfos()
    }

    func updateNow() {
        guard !updating else { return }
        save()
        updating = true
        lastResult = nil
        Task {
            let result = await RuleSetUpdater.shared.update()
            await MainActor.run {
                lastResult = result
                updating = false
                refreshFileInfos()
            }
        }
    }
}

struct CoreRuleSetView: View {
    @StateObject private var vm = RuleSetViewModel()
    @State private var showAdvanced = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            settingsRow
            Divider()
            sourceList
            footer
        }
        .padding(16)
        .onDisappear { vm.save() }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "arrow.triangle.2.circlepath.doc.on.clipboard")
                .font(.title3)
                .foregroundColor(.accentColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: .CoreTabRuleSets)).font(.headline)
                Text(String(localized: .RuleSetSubHead)).font(.caption).foregroundColor(.secondary)
            }
            Spacer()
        }
    }

    private var settingsRow: some View {
        HStack(spacing: 16) {
            Toggle(String(localized: .RuleSetAutoUpdate), isOn: $vm.autoUpdate)
                .toggleStyle(.switch)
                .fixedSize()

            Picker(String(localized: .RuleSetUpdateInterval), selection: $vm.interval) {
                ForEach(RuleSetUpdater.intervalOptions, id: \.self) { seconds in
                    Text(seconds.localizedInterval(locale: LanguageManager.shared.currentLocale)).tag(seconds)
                }
            }
            .fixedSize()
            .disabled(!vm.autoUpdate)

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(String(localized: .RuleSetLastUpdate) + ": " + (vm.lastUpdate.map { Int($0.timeIntervalSince1970).formattedDate } ?? String(localized: .RuleSetNever)))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .layoutPriority(-1)
                if let result = vm.lastResult {
                    Text(Self.friendly(result))
                        .font(.caption)
                        .foregroundColor(result.failed.isEmpty ? .green : .orange)
                        .lineLimit(2)
                        .help(result.summary)
                }
            }

            Button(action: { vm.updateNow() }) {
                if vm.updating {
                    ProgressView().controlSize(.small).frame(width: 14, height: 14)
                    Text(String(localized: .RuleSetUpdating))
                } else {
                    Label(String(localized: .RuleSetUpdateNow), systemImage: "arrow.down.circle")
                }
            }
            .buttonStyle(.borderedProminent)
            .fixedSize()
            .disabled(vm.updating)
            .focusable(false)
        }
    }

    private var sourceList: some View {
        ScrollView {
            VStack(spacing: 6) {
                ForEach($vm.sources) { $source in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 10) {
                            Toggle("", isOn: $source.enabled)
                                .toggleStyle(.checkbox)
                                .labelsHidden()
                                .onChange(of: source.enabled) { _, _ in vm.save() }

                            Text(source.core == .xray ? "xray" : "sing-box")
                                .font(.caption2.bold())
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(source.core == .xray ? Color.blue.opacity(0.15) : Color.orange.opacity(0.15))
                                .cornerRadius(4)
                                .frame(width: 60)

                            VStack(alignment: .leading, spacing: 1) {
                                Text(Self.description(for: source))
                                    .lineLimit(1)
                                Text(source.fileName)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                            .help(source.url)

                            Spacer()

                            Text(fileStatus(source))
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        if showAdvanced {
                            TextField("URL", text: $source.url)
                                .textFieldStyle(.roundedBorder)
                                .font(.caption)
                                .padding(.leading, 90)
                                .onSubmit { vm.save() }
                        }
                    }
                    .padding(.vertical, 3)
                }
            }
        }
    }

    /// 更新结果用人话说; 详细的文件名放在悬停提示里
    static func friendly(_ r: RuleSetUpdateResult) -> String {
        if !r.failed.isEmpty {
            return String(format: String(localized: .RuleSetResultFailed), r.failed.count)
        }
        if !r.updated.isEmpty {
            return String(format: String(localized: .RuleSetResultUpdated), r.updated.count)
        }
        return String(localized: .RuleSetResultLatest)
    }

    /// 每个文件管什么, 用人话说
    static func description(for source: RuleSetSource) -> String {
        switch source.fileName {
        case "geoip.dat": return String(localized: .RuleSetDescGeoipDat)
        case "geosite.dat": return String(localized: .RuleSetDescGeositeDat)
        case "geoip-cn.srs": return String(localized: .RuleSetDescGeoipCn)
        case "geosite-cn.srs": return String(localized: .RuleSetDescGeositeCn)
        case "geosite-geolocation-!cn.srs": return String(localized: .RuleSetDescGeositeNotCn)
        case "geosite-category-ads-all.srs": return String(localized: .RuleSetDescAds)
        default: return source.fileName
        }
    }

    private func fileStatus(_ source: RuleSetSource) -> String {
        guard let info = vm.fileInfos[source.id] else { return String(localized: .RuleSetNotDownloaded) }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return "\(formatByte(Double(info.size)))  \(formatter.string(from: info.modified))"
    }

    private var footer: some View {
        HStack {
            Text(userRuleSetPath)
                .font(.caption)
                .foregroundColor(.secondary)
                .textSelection(.enabled)
            Spacer()
            Toggle(String(localized: .RuleSetAdvanced), isOn: $showAdvanced)
                .toggleStyle(.checkbox)
                .fixedSize()
            Button(String(localized: .RuleSetResetDefaults)) { vm.resetDefaults() }
                .buttonStyle(.bordered)
                .focusable(false)
        }
    }
}
