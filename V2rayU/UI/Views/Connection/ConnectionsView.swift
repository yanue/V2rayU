//
//  ConnectionsView.swift
//  V2rayU
//
//  连接面板: 轮询 sing-box clash_api 的 /connections, 看每个连接走了哪个出站、命中哪条规则、是哪个进程
//

import SwiftUI

@MainActor
final class ConnectionsViewModel: ObservableObject {
    enum Status: Equatable {
        case coreOff
        case notSingbox
        case error(String)
        case ok
    }

    @Published var connections: [ClashConnection] = []
    @Published var uploadTotal = 0
    @Published var downloadTotal = 0
    @Published var paused = false
    @Published var keyword = ""
    @Published var status: Status = .coreOff
    @Published var now = Date()

    private var pollTask: Task<Void, Never>?
    private let interval: UInt64 = 1_000_000_000

    var filtered: [ClashConnection] {
        let k = keyword.trimmingCharacters(in: .whitespaces)
        guard !k.isEmpty else { return connections }
        return connections.filter { $0.matches(k) }
    }

    func start() {
        stop()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.tick()
                try? await Task.sleep(nanoseconds: self?.interval ?? 1_000_000_000)
            }
        }
    }

    func stop() {
        pollTask?.cancel()
        pollTask = nil
    }

    func tick() async {
        guard AppState.shared.v2rayTurnOn else {
            status = .coreOff
            connections = []
            return
        }
        let core = await V2rayLaunch.shared.lastCore
        guard core == .SingBox else {
            status = .notSingbox
            connections = []
            return
        }
        now = Date()
        guard !paused else { return }
        do {
            let snapshot = try await ClashConnectionsHandler.shared.fetch()
            connections = snapshot.list
            uploadTotal = snapshot.uploadTotal
            downloadTotal = snapshot.downloadTotal
            status = .ok
        } catch {
            status = .error(error.localizedDescription)
        }
    }

    func close(_ ids: [String]) {
        Task {
            for id in ids { await ClashConnectionsHandler.shared.close(id: id) }
            await tick()
        }
    }

    func closeAll() {
        Task {
            await ClashConnectionsHandler.shared.closeAll()
            await tick()
        }
    }
}

struct ConnectionsView: View {
    var showHeader = true
    @StateObject private var viewModel = ConnectionsViewModel()
    @State private var selection: Set<ClashConnection.ID> = []
    @State private var sortOrder: [KeyPathComparator<ClashConnection>] = [KeyPathComparator(\.start, order: .reverse)]

    private var rows: [ClashConnection] {
        viewModel.filtered.sorted(using: sortOrder)
    }

    var body: some View {
        VStack(spacing: 0) {
            if showHeader {
                PageHeader(
                    icon: "point.3.connected.trianglepath.dotted",
                    title: localizedString(.Connections),
                    subtitle: localizedString(.ConnectionsSubHead)
                )
            }

            HStack(spacing: 8) {
                    TextField(localizedString(.SearchTip), text: $viewModel.keyword)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 180)

                    Button(action: { viewModel.paused.toggle() }) {
                        Label(localizedString(viewModel.paused ? .Resume : .Pause),
                              systemImage: viewModel.paused ? "play.fill" : "pause.fill")
                    }
                    .buttonStyle(.bordered)
                    .focusable(false)
                    .disabled(viewModel.status != .ok)

                    Button(role: .destructive, action: { viewModel.closeAll() }) {
                        Label(localizedString(.CloseAllConnections), systemImage: "xmark.circle")
                    }
                    .buttonStyle(.bordered)
                    .focusable(false)
                    .disabled(viewModel.status != .ok || viewModel.connections.isEmpty)
                    Spacer()
            }

            summaryBar
                .padding(.vertical, 6)

            content
        }
        .padding(8)
        .onAppear { viewModel.start() }
        .onDisappear { viewModel.stop() }
    }

    private var summaryBar: some View {
        HStack(spacing: 16) {
            Label("\(rows.count) / \(viewModel.connections.count)", systemImage: "number")
            Label("↑ \(formatByte(Double(viewModel.uploadTotal)))", systemImage: "arrow.up")
            Label("↓ \(formatByte(Double(viewModel.downloadTotal)))", systemImage: "arrow.down")
            Spacer()
            if viewModel.paused {
                Text(localizedString(.Pause))
                    .foregroundColor(.orange)
            }
        }
        .font(.caption)
        .foregroundColor(.secondary)
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.status {
        case .coreOff:
            placeholder(icon: "power", text: localizedString(.CoreNotRunning))
        case .notSingbox:
            placeholder(icon: "cpu", text: localizedString(.ConnectionsSingboxOnly))
        case .error(let message):
            placeholder(icon: "exclamationmark.triangle", text: message)
        case .ok:
            table
                .fullWidthTable()
        }
    }

    private func placeholder(icon: String, text: String) -> some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 36))
                .foregroundColor(.secondary)
            Text(text)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var table: some View {
        Table(of: ClashConnection.self, selection: $selection, sortOrder: $sortOrder) {
            TableColumn(String(localized: .TableFieldHost), value: \.target) { row in
                Text(row.target)
                    .help(row.source)
            }
            .width(min: 180, ideal: 260)

            TableColumn(String(localized: .TableFieldNetwork), value: \.metadata.network) { row in
                Text(row.metadata.network.uppercased())
                    .font(.caption)
                    .foregroundColor(row.metadata.network == "udp" ? .purple : .secondary)
            }
            .width(50)

            TableColumn(String(localized: .TableFieldChain), value: \.outbound) { row in
                Text(row.chainText)
                    .foregroundColor(row.outbound == "direct" ? .secondary : .accentColor)
            }
            .width(min: 80, ideal: 140)

            TableColumn(String(localized: .TableFieldRule), value: \.ruleText) { row in
                Text(row.ruleText)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .help(row.ruleText)
            }
            .width(min: 80, ideal: 160)

            TableColumn(String(localized: .TableFieldProcess), value: \.processName) { row in
                Text(row.processName)
                    .help(row.metadata.processPath ?? "")
            }
            .width(min: 60, ideal: 110)

            TableColumn(String(localized: .TableFieldUpload), value: \.upload) { row in
                Text(formatByte(Double(row.upload)))
                    .font(.system(.caption, design: .monospaced))
            }
            .width(70)

            TableColumn(String(localized: .TableFieldDownload), value: \.download) { row in
                Text(formatByte(Double(row.download)))
                    .font(.system(.caption, design: .monospaced))
            }
            .width(70)

            TableColumn(String(localized: .TableFieldDuration), value: \.start) { row in
                Text(row.startDate.map { formatConnectionDuration(viewModel.now.timeIntervalSince($0)) } ?? "-")
                    .font(.system(.caption, design: .monospaced))
            }
            .width(60)
        } rows: {
            ForEach(rows) { row in
                TableRow(row)
                    .contextMenu { contextMenu(for: row) }
            }
        }
    }

    private func selectedIds(for row: ClashConnection) -> [String] {
        selection.contains(row.id) && selection.count > 1 ? Array(selection) : [row.id]
    }

    @ViewBuilder
    private func contextMenu(for row: ClashConnection) -> some View {
        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(row.target, forType: .string)
        } label: {
            Label(localizedString(.Copy), systemImage: "doc.on.doc")
        }
        if let host = QuickRouting.normalizeHost(row.metadata.host.isEmpty ? row.metadata.destinationIP : row.metadata.host) {
            Divider()
            ForEach(QuickRuleTarget.allCases, id: \.rawValue) { target in
                Button {
                    DispatchQueue.main.async { QuickRouting.add(host: host, target: target) }
                } label: {
                    Label("\(localizedString(.QuickRouting)): \(localizedString(target.label))", systemImage: "arrow.triangle.branch")
                }
            }
        }
        Divider()
        Button(role: .destructive) {
            let ids = selectedIds(for: row)
            DispatchQueue.main.async { viewModel.close(ids) }
        } label: {
            Label(localizedString(.CloseConnection), systemImage: "xmark.circle")
        }
    }
}
