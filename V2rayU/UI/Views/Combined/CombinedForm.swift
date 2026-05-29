//
//  CombinedConfigRow.swift
//  V2rayU
//
//  Created by yanue on 2026/5/22.
//

import SwiftUI


struct CombinedConfigFormView: View {
    @State var item: CombinedConfigEntity
    let profiles: [ProfileEntity]
    let onSave: (CombinedConfigEntity) -> Void
    let onCancel: () -> Void

    @State private var groups: [CombinedInboundOutboundGroup] = []

    /// 根据当前选中的核心类型过滤兼容的 profile
    private var filteredProfiles: [ProfileEntity] {
        guard let coreType = item.coreType, let forcedType = coreType.forcedCoreType else {
            return profiles
        }
        return profiles.filter { p in
            var copy = p
            copy.coreType = forcedType == .XrayCore ? .xray : .singbox
            return copy.resolveCoreCompatibility().canLaunch
        }
    }

    private var conflictPorts: Set<Int> {
        isMixedProxyPortEnabled()
            ? [Int(getMixedProxyPort())]
            : [Int(getSocksProxyPort()), Int(getHttpProxyPort())]
    }

    private func nextAvailablePort(from port: Int, usedPorts: Set<Int>) -> Int {
        var p = port
        while conflictPorts.contains(p) || usedPorts.contains(p) {
            p += 1
        }
        return p
    }

    private var validationError: String? {
        var ports = Set<Int>()
        let profileUUIDs = Set(profiles.map { $0.uuid })
        let filteredUUIDs = Set(filteredProfiles.map { $0.uuid })

        for group in groups {
            guard (1...65535).contains(group.port) else {
                return "Port must be between 1 and 65535."
            }
            guard !ports.contains(group.port) else {
                return "Duplicate inbound ports are not allowed."
            }
            guard !conflictPorts.contains(group.port) else {
                let conflictDesc = conflictPorts.sorted().map(String.init).joined(separator: ", ")
                return "Port \(group.port) conflicts with default proxy port (\(conflictDesc))."
            }
            guard !group.outboundProfileUUIDs.isEmpty else {
                return "Each inbound group must select at least one outbound profile."
            }
            guard group.outboundProfileUUIDs.allSatisfy({ profileUUIDs.contains($0) }) else {
                return "Some selected outbound profiles no longer exist."
            }
            guard group.outboundProfileUUIDs.allSatisfy({ filteredUUIDs.contains($0) }) else {
                return "Some selected outbound profiles are incompatible with the selected core."
            }
            ports.insert(group.port)
        }

        return nil
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(item.remark.isEmpty ? String(localized: .Add) : String(localized: .Edit))
                    .font(.headline)
                Spacer()
            }
            .padding()

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(String(localized: .Remark))
                            .frame(width: 80, alignment: .leading)
                        TextField("", text: $item.remark)
                            .textFieldStyle(.roundedBorder)
                    }

                    HStack(spacing: 0) {
                        Text("Color")
                            .frame(width: 80, alignment: .leading)
                        HStack(spacing: 8) {
                            ForEach(CombinationColor.allCases) { color in
                                Circle()
                                    .fill(color.color)
                                    .frame(width: 20, height: 20)
                                    .overlay(
                                        Circle()
                                            .stroke(item.colorName == color.rawValue ? Color.primary : Color.clear, lineWidth: 2)
                                    )
                                    .onTapGesture { item.colorName = color.rawValue }
                            }
                        }
                        Spacer()
                    }

                    HStack(spacing: 0) {
                        Text(String(localized: .Core))
                            .frame(width: 80, alignment: .leading)
                        Picker(selection: $item.coreType, label: EmptyView()) {
                            Text("Xray").tag(ProfileCoreSelection?.some(.xray))
                            Text("Sing-Box").tag(ProfileCoreSelection?.some(.singbox))
                        }
                        .pickerStyle(.segmented)
                        Spacer()
                    }

                    HStack(spacing: 0) {
                        Text("Balancer")
                            .frame(width: 80, alignment: .leading)
                        Picker(selection: $item.balancerStrategy, label: EmptyView()) {
                            Text("Round Robin").tag("roundRobin")
                            Text("Least Ping").tag("leastPing")
                            Text("Random").tag("random")
                            Text("Least Load").tag("leastLoad")
                        }
                        .pickerStyle(.menu)
                        Spacer()
                    }

                    HStack {
                        Text(String(localized: .Combinations))
                            .font(.subheadline.bold())
                        Spacer()
                        Button {
                            let usedPorts = Set(groups.map { $0.port })
                            var newGroup = CombinedInboundOutboundGroup()
                            newGroup.port = nextAvailablePort(from: newGroup.port, usedPorts: usedPorts)
                            groups.append(newGroup)
                        } label: {
                            Label(String(localized: .Add), systemImage: "plus")
                        }
                        .buttonStyle(.bordered)
                    }

                    ForEach(groups.indices, id: \.self) { idx in
                        groupEditor(idx: idx)
                            .padding(10)
                            .background(Color.secondary.opacity(0.06))
                            .cornerRadius(8)
                    }
                }
                .padding(12)
            }

            Divider()

            HStack {
                if let validationError {
                    Text(validationError)
                        .font(.caption)
                        .foregroundColor(.red)
                }
                Spacer()
                Button(String(localized: .Cancel), action: onCancel)
                Button(String(localized: .Save)) {
                    item.groups = groups
                    onSave(item)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(groups.isEmpty || validationError != nil)
            }
            .padding()
        }
        .frame(minWidth: 560, minHeight: 420)
        .onAppear {
            // 去掉 auto, 默认使用 Xray
            if item.coreType == nil || item.coreType == .auto {
                item.coreType = .xray
            }
            if item.groups.isEmpty {
                var newGroups = [CombinedInboundOutboundGroup()]
                let usedPorts = Set(newGroups.map { $0.port })
                for i in newGroups.indices {
                    newGroups[i].port = nextAvailablePort(from: newGroups[i].port, usedPorts: usedPorts.subtracting([newGroups[i].port]))
                }
                groups = newGroups
            } else {
                groups = item.groups
                let usedPorts = Set(groups.map { $0.port })
                for i in groups.indices {
                    groups[i].port = nextAvailablePort(from: groups[i].port, usedPorts: usedPorts.subtracting([groups[i].port]))
                }
            }
        }
    }

    @ViewBuilder
    private func groupEditor(idx: Int) -> some View {
        let binding = Binding(
            get: { groups[idx] },
            set: { groups[idx] = $0 }
        )

        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Inbound")
                    .frame(width: 80, alignment: .leading)
                Picker(selection: binding.inboundType, label: EmptyView()) {
                    ForEach(CombinedInboundType.allCases) { kind in
                        Text(kind.rawValue.uppercased()).tag(kind)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 180)

                Text("Port")
                TextField("port", value: binding.port, formatter: NumberFormatter())
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 90)

                if conflictPorts.contains(groups[idx].port) || groups.contains(where: { $0.id != groups[idx].id && $0.port == groups[idx].port }) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Button("+1") {
                        let otherPorts = Set(groups.map { $0.port }).subtracting([groups[idx].port])
                        groups[idx].port = nextAvailablePort(from: groups[idx].port + 1, usedPorts: otherPorts)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                Spacer()

                Button(role: .destructive) {
                    if groups.count > 1 {
                        groups.remove(at: idx)
                    }
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .disabled(groups.count <= 1)
            }

            HStack {
                Text("Outbound profiles:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                let totalCount = profiles.count
                let filteredCount = filteredProfiles.count
                if filteredCount < totalCount {
                    Text("\(filteredCount)/\(totalCount) available")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                } else {
                    Text("\(totalCount) available")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            if filteredProfiles.isEmpty {
                Text("(no compatible profiles for the selected core)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 1) {
                    ForEach(filteredProfiles) { p in
                        HStack(spacing: 6) {
                            Toggle(isOn: outboundBinding(idx: idx, uuid: p.uuid)) {
                                EmptyView()
                            }
                            .toggleStyle(.checkbox)
                            .labelsHidden()

                            if !p.serverRegion.isEmpty {
                                Text(countryCodeToEmoji(p.serverRegion))
                            }

                            Text(p.remark.isEmpty ? p.address : p.remark)
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Text(p.protocol.rawValue)
                                .font(.caption2.bold())
                                .foregroundColor(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(Color.accentColor.opacity(0.8))
                                .cornerRadius(3)

                            Text("\(p.address):\(p.port)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)

                            Text(p.speed > 0 ? "[\(p.speed)ms]" : "[-]")
                                .font(.caption2)
                                .foregroundColor(p.speed > 0 ? Color(getSpeedColor(latency: Double(p.speed))) : .secondary)
                                .frame(width: 60, alignment: .trailing)
                        }
                        .padding(.vertical, 3)
                        .padding(.horizontal, 4)
                        .background(
                            groups[idx].outboundProfileUUIDs.contains(p.uuid)
                                ? Color.accentColor.opacity(0.06)
                                : Color.clear
                        )
                        .cornerRadius(4)
                    }
                }
            }
        }
    }

    private func outboundBinding(idx: Int, uuid: String) -> Binding<Bool> {
        Binding(
            get: { groups[idx].outboundProfileUUIDs.contains(uuid) },
            set: { newValue in
                var ids = groups[idx].outboundProfileUUIDs
                if newValue {
                    if !ids.contains(uuid) { ids.append(uuid) }
                } else {
                    ids.removeAll { $0 == uuid }
                }
                groups[idx].outboundProfileUUIDs = ids
            }
        )
    }
}
