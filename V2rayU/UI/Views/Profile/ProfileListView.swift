//
//  ConfigList.swift
//  V2rayU
//
//  Created by yanue on 2024/11/30.
//

import SwiftUI

private enum ActiveSheet: Identifiable {
    case edit(ProfileModel)
    case ping(ProfileModel)
    case pingMultiple([ProfileEntity])
    case share(ProfileModel)
    case export([ProfileEntity])
    case pingAll
    case importLegacy
    case importServers

    var id: String {
        switch self {
        case .edit(let m):       return "edit-\(m.uuid)"
        case .ping(let m):       return "ping-\(m.uuid)"
        case .pingMultiple(let items):
            let head = items.first?.uuid ?? ""
            let tail = items.last?.uuid ?? ""
            return "pingMulti-\(items.count)-\(head)-\(tail)"
        case .share(let m):      return "share-\(m.uuid)"
        case .export(let items):
            let head = items.first?.uuid ?? ""
            let tail = items.last?.uuid ?? ""
            return "export-\(items.count)-\(head)-\(tail)"
        case .pingAll:           return "pingAll"
        case .importLegacy:      return "importLegacy"
        case .importServers:     return "importServers"
        }
    }
}

struct ProfileListView: View {
    @StateObject private var viewModel = ProfileViewModel()
    @State private var sortOrder: [KeyPathComparator<ProfileEntity>] = []
    @State private var selection: Set<ProfileModel.ID> = []
    @State private var selectGroup: String = ""
    @State private var searchText = ""
    @State private var selectAll: Bool = false
    @State private var activeSheet: ActiveSheet? = nil
    @State private var tableOpacity: Double = 1.0

    private var isRunningRow: (ProfileEntity) -> Bool {
        { $0.uuid == AppState.shared.runningProfile }
    }

    var filteredAndSortedItems: [ProfileEntity] {
        let filteredItems = viewModel.list.filter { item in
            let itemGroupName = getGroupName(for: item)
            return (selectGroup.isEmpty || selectGroup == itemGroupName) &&
                (searchText.isEmpty ||
                 item.address.lowercased().contains(searchText.lowercased()) ||
                 item.remark.lowercased().contains(searchText.lowercased()))
        }

        guard !sortOrder.isEmpty else { return filteredItems }
        return filteredItems.sorted(using: sortOrder)
    }
    
    private func getGroupName(for item: ProfileEntity) -> String {
        if item.subid.isEmpty {
            return String(localized: .DefaultGroup)
        }
        if let sub = SubscriptionStore.shared.fetchOne(uuid: item.subid) {
            return sub.remark.isEmpty ? sub.url : sub.remark
        }
        return item.subid
    }

    private func resolveSelectedItems(for item: ProfileEntity) -> [ProfileEntity] {
        if selection.contains(item.uuid) && selection.count > 1 {
            return filteredAndSortedItems.filter { selection.contains($0.uuid) }
        }
        return [item]
    }

    var body: some View {
        VStack {
            PageHeader(
                icon: "globe",
                title: String(localized: .Servers),
                subtitle: String(localized: .ServerSubHead)
            ) {
                HStack(spacing: 8) {
                    Button(action: { activeSheet = .pingAll }) {
                        Label(String(localized: .LatencyTest), systemImage: "gauge.with.dots.needle.67percent")
                    }
                    .buttonStyle(.borderedProminent)
                    .focusable(false)
                    .disabled(viewModel.list.isEmpty)

                    Button(action: {
                        withAnimation {
                            let newProxy = ProfileModel(from: ProfileEntity())
                            activeSheet = .edit(newProxy)
                        }
                    }) {
                        Label(String(localized: .Add), systemImage: "plus")
                    }
                    .buttonStyle(.bordered)
                    .focusable(false)

                    Button(action: {
                        activeSheet = .importServers
                    }) {
                        Label(String(localized: .ImportServers), systemImage: "square.and.arrow.down")
                    }
                    .buttonStyle(.bordered)
                    .focusable(false)

                    Divider()
                        .frame(height: 20)
                    
                    Menu {
                        Button(action: {
                            withAnimation(.easeOut(duration: 0.15)) {
                                tableOpacity = 0
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                loadData()
                                withAnimation(.easeIn(duration: 0.2)) {
                                    tableOpacity = 1
                                }
                            }
                        }) {
                            Label(String(localized: .Refresh), systemImage: "arrow.clockwise")
                        }

                        Button(action: {
                            activeSheet = .importLegacy
                        }) {
                            Label(String(localized: .ImportLegacyData), systemImage: "square.and.arrow.down.on.square")
                        }

                        Divider()

                        Button(action: {
                            if showConfirmAlertSync(
                                title: String(localized: .RemoveDuplicateServers),
                                message: String(localized: .RemoveDuplicateConfirmTip)
                            ) {
                                let count = viewModel.removeDuplicates()
                                alertDialog(
                                    title: String(localized: .RemoveDuplicateServers),
                                    message: String(localized: .RemoveDuplicateConfirm, arguments: count)
                                )
                            }
                        }) {
                            Label(String(localized: .RemoveDuplicateServers), systemImage: "doc.on.doc")
                        }
                        .disabled(viewModel.list.isEmpty)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .focusable(false)
                    .frame(width: 50)
                }
            }

            Spacer()
            VStack {
                Spacer()
                HStack {
                    Picker(String(localized: .SelectGroup), selection: $selectGroup) {
                        Text(String(localized: .AllGroup)).tag("")
                        ForEach(viewModel.groups, id: \.self) { group in
                            Text(group).tag(group)
                        }
                    }
                    .pickerStyle(.menu)
                    .focusable(false)
                    Spacer()

                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                            .font(.system(size: 13))
                        TextField(String(localized: .SearchTip), text: $searchText)
                            .textFieldStyle(.plain)
                            .frame(width: 180)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
                }.padding(.horizontal, 10)
                tableView
                    .opacity(tableOpacity)
            }
            .background(.ultraThinMaterial)
            .border(Color.gray.opacity(0.1), width: 1)
            .cornerRadius(8)
        }
        .padding(8)
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .edit(let model):
                ConfigFormView(item: model) {
                    activeSheet = nil
                    loadData()
                }
            case .ping(let model):
                ProfilePingView(profile: model.toEntity(), isAll: false) {
                    activeSheet = nil
                }
            case .pingAll:
                ProfilePingView(profile: nil, isAll: true) {
                    activeSheet = nil
                }
            case .pingMultiple(let items):
                ProfilePingView(profiles: items, isAll: false) {
                    activeSheet = nil
                }
            case .share(let model):
                ShareQrCodeView(profile: model) {
                    activeSheet = nil
                }
            case .export(let items):
                ExportView(items: items) {
                    activeSheet = nil
                }
            case .importLegacy:
                LegacyImportView {
                    activeSheet = nil
                    loadData()
                }
            case .importServers:
                ImportView {
                    activeSheet = nil
                    loadData()
                }
            }
        }
        .task { loadData() }
    }

    func handleDrop(index: Int, rows: [ProfileEntity]) {
        guard let firstRow = rows.first,
              let firstRemoveIndex = viewModel.list.firstIndex(where: { $0.uuid == firstRow.uuid })
        else { return }

        viewModel.list.removeAll(where: { row in
            rows.contains(where: { $0.uuid == row.uuid })
        })
        viewModel.list.insert(contentsOf: rows, at: index > firstRemoveIndex ? (index - 1) : index)
        viewModel.updateSortOrderInDBAsync()
    }

    @ViewBuilder
    private func contextMenuProvider(item: ProfileEntity) -> some View {
        // NOTE: Avoid creating ObservableObject (ProfileModel) or doing heavy
        // computation in the contextMenu view builder — SwiftUI may re-evaluate
        // it during AttributeGraph updates, which causes crashes when new
        // ObservableObject instances are created each time.  Defer all such
        // work into the Button actions instead.
        let isMultiSelect = selection.contains(item.uuid) && selection.count > 1

        Group {
            Button {
                let model = ProfileModel(from: item)
                chooseItem(item: model)
            } label: {
                Label(String(localized: .SetActive), systemImage: "checkmark.circle")
            }
            .focusable(false)

            Button {
                if isMultiSelect {
                    let resolved = resolveSelectedItems(for: item)
                    activeSheet = .pingMultiple(resolved)
                } else {
                    activeSheet = .ping(ProfileModel(from: item))
                }
            } label: {
                Label(String(localized: .LatencyTest), systemImage: "gauge.with.dots.needle.67percent")
            }
            .focusable(false)

            Divider()

            Button {
                activeSheet = .share(ProfileModel(from: item))
            } label: {
                Label(String(localized: .ShareQrCode), systemImage: "qrcode")
            }
            .focusable(false)
            .disabled(isMultiSelect)

            Button {
                let resolved = resolveSelectedItems(for: item)
                activeSheet = .export(resolved)
            } label: {
                Label(String(localized: .Export), systemImage: "square.and.arrow.up")
            }
            .focusable(false)

            Divider()

            Button { moveToTop(item: item) } label: {
                Label(String(localized: .MoveToTop), systemImage: "arrow.up.to.line")
            }
            .focusable(false)
            .disabled(isMultiSelect)

            Button { moveToBottom(item: item) } label: {
                Label(String(localized: .MoveToBottom), systemImage: "arrow.down.to.line")
            }
            .focusable(false)
            .disabled(isMultiSelect)

            Button { moveUp(item: item) } label: {
                Label(String(localized: .MoveUp), systemImage: "chevron.up")
            }
            .focusable(false)
            .disabled(isMultiSelect)

            Button { moveDown(item: item) } label: {
                Label(String(localized: .MoveDown), systemImage: "chevron.down")
            }
            .focusable(false)
            .disabled(isMultiSelect)

            Divider()

            Button {
                duplicateItem(item: ProfileModel(from: item))
            } label: {
                Label(String(localized: .Duplicate), systemImage: "plus.square.on.square")
            }
            .focusable(false)
            .disabled(isMultiSelect)

            Button {
                activeSheet = .edit(ProfileModel(from: item))
            } label: {
                Label(String(localized: .Edit), systemImage: "pencil")
            }
            .focusable(false)
            .disabled(isMultiSelect)

            Button {
                let itemsToDelete = resolveSelectedItems(for: item)
                if showConfirmAlertSync(
                    title: String(localized: .DeleteSelectedConfirm),
                    message: itemsToDelete.count > 1 
                        ? String(localized: .DeleteMultipleConfirm, arguments: itemsToDelete.count)
                        : String(localized: .DeleteTip)
                ) {
                    for entity in itemsToDelete {
                        viewModel.delete(uuid: entity.uuid)
                    }
                }
            } label: {
                Label(String(localized: .Delete), systemImage: "trash")
                    .foregroundColor(.red)
            }
            .focusable(false)
        }
    }

    private var tableView: some View {
        Table(of: ProfileEntity.self, selection: $selection, sortOrder: $sortOrder) {
            Group {
                TableColumn("#") { (row: ProfileEntity) in
                    HStack(spacing: 4) {
                        if isRunningRow(row) {
                           Image(systemName: "checkmark.circle.fill")
                               .foregroundColor(.green)
                               .font(.system(size: 13))
                        } else if let idx = viewModel.list.firstIndex(where: { $0.uuid == row.uuid }) {
                            Text("\(idx + 1)")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .width(28)

                TableColumn(String(localized: .TableFieldSort)) { (row: ProfileEntity) in
                    HStack(spacing: 5) {
                        if isRunningRow(row) {
                            Image(systemName: "line.3.horizontal")
                                .foregroundColor(.green)
                        } else {
                            Image(systemName: "line.3.horizontal")
                        }
                    }
                    .contentShape(Rectangle())
                    .draggable(row)
                    .onTapGesture { }
                    .onHover { inside in
                        if inside { NSCursor.openHand.push() } else { NSCursor.pop() }
                    }
                }
                .width(26)

                TableColumn(String(localized: .TableFieldRemark)) { (row: ProfileEntity) in
                    HStack(spacing: 4) {
                        if isRunningRow(row) {
                            Image(systemName: "square.and.pencil")
                                .foregroundColor(.green)
                                .font(.system(size: 13))
                            Text(row.remark)
                                .fontWeight(.semibold)
                                .foregroundColor(.green)
                        } else {
                            Image(systemName: "square.and.pencil")
                            Text(row.remark)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { activeSheet = .edit(ProfileModel(from: row)) }
                    .onHover { inside in
                        if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                    }
                }
                .width(min: 150, max: 300)

                TableColumn(String(localized: .TableFieldLatency)) { (row: ProfileEntity) in
                    Text("\(row.speed)")
                        .foregroundColor(Color(getSpeedColor(latency: Double(row.speed))))
                }
                .width(40)

                TableColumn(String(localized: .TableFieldType)) { row in
                    Text(row.protocol == .shadowsocks ? "ss" : row.protocol.rawValue)
                }
                .width(40)

                TableColumn(String(localized: .TableFieldNetwork)) { row in
                    Text(row.network.rawValue)
                }.width(50)

                TableColumn(String(localized: .TableFieldSecurity)) { row in
                    Text(row.security.rawValue)
                }.width(40)

                TableColumn(String(localized: .TableFieldAddress)) { row in
                    Text(row.address)
                }
                .width(min: 120, max: 300)

                TableColumn(String(localized: .TableFieldPort)) { row in
                    Text("\(row.port)")
                }
                .width(40)
            }
            Group {
                TableColumn(String(localized: .TableFieldTodayDown)) { (row: ProfileEntity) in
                    Text(row.todayDown.humanSize)
                }
                .width(min: 40, max: 100)

                TableColumn(String(localized: .TableFieldTodayUp)) { (row: ProfileEntity) in
                    Text(row.todayUp.humanSize)
                }
                .width(min: 40, max: 100)

                TableColumn(String(localized: .TableFieldTotalDown)) { (row: ProfileEntity) in
                    Text(row.totalDown.humanSize)
                }
                .width(min: 40, max: 100)

                TableColumn(String(localized: .TableFieldTotalUp)) { (row: ProfileEntity) in
                    Text(row.totalUp.humanSize)
                }
                .width(min: 40, max: 100)
            }
        } rows: {
            ForEach(filteredAndSortedItems) { row in
                TableRow(row)
                    .draggable(row)
                    .contextMenu { contextMenuProvider(item: row) }
            }
            .dropDestination(for: ProfileEntity.self, action: handleDrop)
        }
    }

    private func chooseItem(item: ProfileModel) {
        Task {
            await AppState.shared.switchServer(uuid: item.uuid)
            loadData()
        }
    }

    private func duplicateItem(item: ProfileModel) {
        let newItem = item.clone()
        newItem.remark = newItem.remark + "-" + (String(localized: .Copy))
        newItem.uuid = UUID().uuidString // 新的 UUID
        newItem.entity.subid = "" // 清除分组信息
        // 显示编辑界面
        withAnimation {
            let newProxy = ProfileModel(from: newItem.entity)
            activeSheet = .edit(newProxy)
        }
    }

    private func copyItem(item: ProfileEntity) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        let profileString = ShareUri.generateShareUri(item: item)
        if pasteboard.setString(profileString, forType: .string) {
            alertDialog(title: String(localized: .Copied), message: "")
        } else {
            alertDialog(title: String(localized: .CopyFailed), message: "")
        }
    }

    private func moveToTop(item: ProfileEntity) {
        move(item: item, toVisibleIndex: 0)
    }

    private func moveToBottom(item: ProfileEntity) {
        move(item: item, toVisibleIndex: max(filteredAndSortedItems.count - 1, 0))
    }

    private func moveUp(item: ProfileEntity) {
        guard let visibleIndex = filteredAndSortedItems.firstIndex(where: { $0.id == item.id }),
              visibleIndex > 0 else { return }
        move(item: item, toVisibleIndex: visibleIndex - 1)
    }

    private func moveDown(item: ProfileEntity) {
        guard let visibleIndex = filteredAndSortedItems.firstIndex(where: { $0.id == item.id }),
              visibleIndex < filteredAndSortedItems.count - 1 else { return }
        move(item: item, toVisibleIndex: visibleIndex + 1)
    }

    private func move(item: ProfileEntity, toVisibleIndex visibleIndex: Int) {
        let visibleItems = filteredAndSortedItems
        guard let sourceVisibleIndex = visibleItems.firstIndex(where: { $0.id == item.id }) else { return }

        let clampedTargetIndex = min(max(visibleIndex, 0), max(visibleItems.count - 1, 0))
        guard sourceVisibleIndex != clampedTargetIndex else { return }

        var reorderedVisibleItems = visibleItems
        let movingItem = reorderedVisibleItems.remove(at: sourceVisibleIndex)
        reorderedVisibleItems.insert(movingItem, at: clampedTargetIndex)

        let reorderedVisibleByUUID = Dictionary(uniqueKeysWithValues: reorderedVisibleItems.enumerated().map { ($1.uuid, $0) })

        viewModel.list.sort { lhs, rhs in
            let lhsVisibleOrder = reorderedVisibleByUUID[lhs.uuid]
            let rhsVisibleOrder = reorderedVisibleByUUID[rhs.uuid]

            switch (lhsVisibleOrder, rhsVisibleOrder) {
            case let (l?, r?):
                return l < r
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            case (nil, nil):
                return lhs.sort < rhs.sort
            }
        }

        viewModel.updateSortOrderInDBAsync()
    }

    private func loadData() {
        viewModel.getList()
    }
}
