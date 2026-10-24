//
//  CombinedForm.swift
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

    private var mode: CombinedOutboundMode { item.outboundMode }

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

    /// 节点在所选核心下不兼容的原因；兼容返回 nil
    private func incompatibleReason(_ p: ProfileEntity) -> String? {
        guard let coreType = item.coreType, let forcedType = coreType.forcedCoreType else { return nil }
        var copy = p
        copy.coreType = forcedType == .XrayCore ? .xray : .singbox
        let decision = copy.resolveCoreCompatibility()
        guard !decision.canLaunch else { return nil }
        return decision.warningMessage ?? String(localized: .IncompatibleWithCore)
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
                return String(localized: .CombinedPortRangeError)
            }
            guard !ports.contains(group.port) else {
                return String(localized: .CombinedDuplicatePort)
            }
            guard !conflictPorts.contains(group.port) else {
                let conflictDesc = conflictPorts.sorted().map(String.init).joined(separator: ", ")
                return String(localized: .CombinedPortConflictFormat, arguments: group.port, conflictDesc)
            }
            guard mode != .chain || group.outboundProfileUUIDs.count >= 2 else {
                return String(localized: .ChainNeedTwoProfiles)
            }
            guard !group.outboundProfileUUIDs.isEmpty else {
                return String(localized: .CombinedNeedOneProfile)
            }
            guard group.outboundProfileUUIDs.allSatisfy({ profileUUIDs.contains($0) }) else {
                return String(localized: .CombinedProfilesMissing)
            }
            let incompatible = group.outboundProfileUUIDs.filter { !filteredUUIDs.contains($0) }
            guard incompatible.isEmpty else {
                let names = profiles.filter { incompatible.contains($0.uuid) }.map { $0.remark.isEmpty ? $0.address : $0.remark }
                return String(localized: .IncompatibleProfilesFormat, arguments: names.joined(separator: ", "))
            }
            ports.insert(group.port)
        }

        return nil
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(item.remark.isEmpty ? String(localized: mode == .chain ? .NewChainProxy : .Add) : String(localized: .Edit))
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
                        Text(String(localized: .CombinedColor))
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
                        Text(String(localized: .OutboundMode))
                            .frame(width: 80, alignment: .leading)
                        Picker(selection: $item.outboundMode, label: EmptyView()) {
                            Text(String(localized: .OutboundModeBalance)).tag(CombinedOutboundMode.balance)
                            Text(String(localized: .OutboundModeChain)).tag(CombinedOutboundMode.chain)
                        }
                        .pickerStyle(.segmented)
                        .fixedSize()
                        // 负载均衡策略只对负载均衡模式有意义
                        if mode == .balance {
                            Picker(selection: $item.balancerStrategy, label: EmptyView()) {
                                Text(String(localized: .BalancerRoundRobin)).tag("roundRobin")
                                Text(String(localized: .BalancerLeastPing)).tag("leastPing")
                                Text(String(localized: .BalancerRandom)).tag("random")
                                Text(String(localized: .BalancerLeastLoad)).tag("leastLoad")
                            }
                            .pickerStyle(.menu)
                            .frame(width: 140)
                            .padding(.leading, 12)
                        }
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
            // 清理已被删除的 outbound profile UUID（例如订阅更新后服务器被移除）
            let validUUIDs = Set(profiles.map { $0.uuid })
            for i in groups.indices {
                groups[i].outboundProfileUUIDs.removeAll { !validUUIDs.contains($0) }
            }
            groups.removeAll { $0.outboundProfileUUIDs.isEmpty }
            // 新建时直接给出一个空分组，免去再点「添加」
            if groups.isEmpty {
                var newGroup = CombinedInboundOutboundGroup()
                newGroup.port = nextAvailablePort(from: newGroup.port, usedPorts: [])
                groups = [newGroup]
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
                Text(String(localized: .CombinedInbound))
                    .frame(width: 80, alignment: .leading)
                Picker(selection: binding.inboundType, label: EmptyView()) {
                    ForEach(CombinedInboundType.allCases) { kind in
                        Text(kind.rawValue.uppercased()).tag(kind)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 180)

                Text(String(localized: .Port))
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
                Text(String(localized: .CombinedOutboundProfiles))
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                let totalCount = profiles.count
                let filteredCount = filteredProfiles.count
                if filteredCount < totalCount {
                    Text(String(localized: .CombinedAvailableOfFormat, arguments: filteredCount, totalCount))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                } else {
                    Text(String(localized: .CombinedAvailableFormat, arguments: totalCount))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            if filteredProfiles.isEmpty {
                Text(String(localized: .CombinedNoCompatibleProfiles))
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else if mode == .chain {
                chainEditor(idx: idx)
            } else {
                // 已勾选但与所选核心不兼容的节点不在 filteredProfiles 中，单独置顶显示以便取消勾选
                let filteredUUIDs = Set(filteredProfiles.map { $0.uuid })
                let incompatibleSelected = profiles.filter { groups[idx].outboundProfileUUIDs.contains($0.uuid) && !filteredUUIDs.contains($0.uuid) }
                VStack(alignment: .leading, spacing: 1) {
                    ForEach(incompatibleSelected + filteredProfiles) { p in
                        HStack(spacing: 6) {
                            Toggle(isOn: outboundBinding(idx: idx, uuid: p.uuid)) {
                                EmptyView()
                            }
                            .toggleStyle(.checkbox)
                            .labelsHidden()

                            profileInfo(p, compatible: filteredUUIDs.contains(p.uuid))
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

    /// 节点信息: 国旗、名称、协议、地址、延迟；不兼容时标红并在悬停时显示原因
    /// (compatible 由调用方根据 filteredProfiles 传入，避免每行重复跑兼容性规则)
    @ViewBuilder
    private func profileInfo(_ p: ProfileEntity, compatible: Bool = true) -> some View {
        let reason = compatible ? nil : incompatibleReason(p)
        if !p.serverRegion.isEmpty {
            Text(countryCodeToEmoji(p.serverRegion))
        }

        HStack(spacing: 4) {
            if let reason {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                    .help(reason)
            }
            Text(p.remark.isEmpty ? p.address : p.remark)
                .lineLimit(1)
                .foregroundColor(reason == nil ? .primary : .red)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .help(reason ?? "")

        Text(p.protocol.rawValue)
            .font(.caption2.bold())
            .foregroundColor(.white)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(Color.accentColor.opacity(0.8))
            .cornerRadius(3)

        Text(verbatim: "\(p.address):\(p.port)")
            .font(.caption)
            .foregroundColor(.secondary)
            .lineLimit(1)

        Text(verbatim: p.speed > 0 ? "[\(p.speed)ms]" : "[-]")
            .font(.caption2)
            .foregroundColor(p.speed > 0 ? Color(getSpeedColor(latency: Double(p.speed))) : .secondary)
            .frame(width: 60, alignment: .trailing)
    }

    /// 链式节点列表: 已选节点按链路顺序在上(第一个为入口，最后一个为出口)，未选节点在下，点击追加到链路末尾
    @ViewBuilder
    private func chainEditor(idx: Int) -> some View {
        let uuids = groups[idx].outboundProfileUUIDs
        let profilesByUUID = Dictionary(uniqueKeysWithValues: profiles.map { ($0.uuid, $0) })
        let compatibleProfiles = filteredProfiles
        let compatibleUUIDs = Set(compatibleProfiles.map { $0.uuid })

        VStack(alignment: .leading, spacing: 1) {
            Text(String(localized: .ChainOrderTip))
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.bottom, 3)

            ForEach(Array(uuids.enumerated()), id: \.element) { pos, uuid in
                if let p = profilesByUUID[uuid] {
                    HStack(spacing: 6) {
                        Text("\(pos + 1)")
                            .font(.caption.bold().monospacedDigit())
                            .foregroundColor(.white)
                            .frame(width: 16, height: 16)
                            .background(Circle().fill(Color.accentColor))

                        profileInfo(p, compatible: compatibleUUIDs.contains(p.uuid))

                        Text(pos == 0 ? String(localized: .ChainEntry) : (pos == uuids.count - 1 ? String(localized: .ChainExit) : ""))
                            .font(.caption2.bold())
                            .foregroundColor(.accentColor)
                            .frame(width: 30)

                        Button {
                            groups[idx].outboundProfileUUIDs.swapAt(pos, pos - 1)
                        } label: {
                            Image(systemName: "chevron.up")
                        }
                        .buttonStyle(.borderless)
                        .disabled(pos == 0)
                        Button {
                            groups[idx].outboundProfileUUIDs.swapAt(pos, pos + 1)
                        } label: {
                            Image(systemName: "chevron.down")
                        }
                        .buttonStyle(.borderless)
                        .disabled(pos == uuids.count - 1)
                        Button {
                            groups[idx].outboundProfileUUIDs.remove(at: pos)
                        } label: {
                            Image(systemName: "xmark")
                        }
                        .buttonStyle(.borderless)
                    }
                    .padding(.vertical, 3)
                    .padding(.horizontal, 4)
                    .background(Color.accentColor.opacity(0.08))
                    .cornerRadius(4)
                }
            }

            if uuids.count < 2 {
                Text(String(localized: .ChainSelectTip))
                    .font(.caption)
                    .foregroundColor(.orange)
                    .padding(.vertical, 3)
            }

            Divider()
                .padding(.vertical, 4)

            ForEach(compatibleProfiles.filter { !uuids.contains($0.uuid) }) { p in
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle")
                        .foregroundColor(.accentColor)
                        .frame(width: 16)

                    profileInfo(p)
                }
                .padding(.vertical, 3)
                .padding(.horizontal, 4)
                .contentShape(Rectangle())
                .onTapGesture {
                    groups[idx].outboundProfileUUIDs.append(p.uuid)
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
