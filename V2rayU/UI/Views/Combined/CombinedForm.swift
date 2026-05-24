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
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text(String(localized: .Remark))
                            .frame(width: 80, alignment: .leading)
                        TextField("", text: $item.remark)
                            .textFieldStyle(.roundedBorder)
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

                    // Default ports & current node
                    HStack(spacing: 12) {
                        Label("SOCKS:\(getSocksProxyPort())", systemImage: "rectangle.connected.to.line.below")
                        Label("HTTP:\(getHttpProxyPort())", systemImage: "rectangle.connected.to.line.below")
                        Spacer()
                        if AppState.shared.v2rayTurnOn, let server = AppState.shared.runningServer {
                            Label(server.remark.isEmpty ? server.address : server.remark,
                                  systemImage: "point.3.connected.trianglepath.dotted")
                                .foregroundColor(.accentColor)
                        } else {
                            Label("-", systemImage: "point.3.connected.trianglepath.dotted")
                                .foregroundColor(.secondary)
                        }
                    }
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    
                    ForEach(groups.indices, id: \.self) { idx in
                        groupEditor(idx: idx)
                            .padding(10)
                            .background(Color.secondary.opacity(0.06))
                            .cornerRadius(8)
                    }
                }
                .padding()
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
                Picker(selection: binding.inboundType, label: Text("Inbound")) {
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

            Text("Outbound profiles:")
                .font(.caption)
                .foregroundColor(.secondary)

            if profiles.isEmpty {
                Text("(no profiles available)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(profiles) { p in
                            Toggle(isOn: outboundBinding(idx: idx, uuid: p.uuid)) {
                                HStack(spacing: 4) {
                                    Text(p.remark.isEmpty ? p.address : p.remark)
                                    Text("(\(p.protocol.rawValue))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .toggleStyle(.checkbox)
                        }
                    }
                }
                .frame(maxHeight: 140)
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
