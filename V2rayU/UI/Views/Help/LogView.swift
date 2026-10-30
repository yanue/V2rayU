//
//  LogView.swift
//  V2rayU
//
//  应用内日志查看: 核心 / TUN / App 日志实时滚动, 按级别过滤, 搜索
//

import SwiftUI

enum LogLevel: String, CaseIterable, Identifiable {
    case all, error, warn, info, debug
    var id: String { rawValue }

    var label: String {
        switch self {
        case .all: return "ALL"
        case .error: return "ERROR"
        case .warn: return "WARN"
        case .info: return "INFO"
        case .debug: return "DEBUG"
        }
    }

    var color: Color {
        switch self {
        case .error: return .red
        case .warn: return .orange
        case .info: return .primary
        case .debug: return .secondary
        case .all: return .primary
        }
    }

    /// 从一行日志里认级别: sing-box "INFO [..]" / xray "[Info]" / "[Warning]" / "ERROR" 等
    static func detect(_ line: String) -> LogLevel {
        let upper = line.uppercased()
        if upper.contains("[ERROR]") || upper.contains(" ERROR ") || upper.contains("FATAL") || upper.contains("PANIC") { return .error }
        if upper.contains("[WARNING]") || upper.contains("[WARN]") || upper.contains(" WARN ") { return .warn }
        if upper.contains("[DEBUG]") || upper.contains(" DEBUG ") || upper.contains("[TRACE]") { return .debug }
        return .info
    }
}

struct LogFileOption: Identifiable, Hashable {
    let id: String
    let title: String
    let path: String

    @MainActor
    static var all: [LogFileOption] {
        [
            LogFileOption(id: "core", title: "core.log", path: coreLogFilePath),
            LogFileOption(id: "tun", title: "tun.log", path: tunLogFilePath),
            LogFileOption(id: "run-tun", title: "run-tun.log", path: runTunLogFilePath),
            LogFileOption(id: "app", title: "V2rayU.log", path: appLogFilePath),
        ]
    }
}

struct LogLine: Identifiable, Equatable {
    let id: Int
    let text: String
    let level: LogLevel
}

enum LogTail {
    static let maxBytes = 256 * 1024
    static let maxLines = 2000

    /// 增量读取结果
    struct Chunk {
        var lines: [String]
        /// 读到的文件末尾位置, 下次从这里继续
        var offset: UInt64
        /// 最后一段没换行的半行, 下次拼到前面
        var partial: String
    }

    /// 从 offset 开始读到文件末尾; offset 为 0 且文件大于 maxBytes 时只读尾部.
    /// 文件变小了(被清空/轮转)也从头来. 返回 nil 表示文件打不开
    static func read(path: String, from offset: UInt64, partial: String = "") -> Chunk? {
        guard let handle = FileHandle(forReadingAtPath: path) else { return nil }
        defer { try? handle.close() }
        let size = (try? handle.seekToEnd()) ?? 0
        var start = offset
        var carry = partial
        var dropFirstLine = false
        if size < offset || offset == 0 {
            carry = ""
            start = size > UInt64(maxBytes) ? size - UInt64(maxBytes) : 0
            dropFirstLine = start > 0
        }
        guard size > start else { return Chunk(lines: [], offset: size, partial: carry) }
        try? handle.seek(toOffset: start)
        var data = (try? handle.readToEnd()) ?? Data()
        // 从文件中间开始读时, 起点可能落在一个中文字符中间: 先按字节丢掉第一行再解码。
        // 解码用容错方式, 个别坏字节变成 �, 不会因为一个字节整段退回 Latin1 变成乱码
        if dropFirstLine, let nl = data.firstIndex(of: 0x0A) { data = data[data.index(after: nl)...] }
        let text = carry + String(decoding: data, as: UTF8.self)
        var pieces = text.components(separatedBy: "\n")
        let newPartial = text.hasSuffix("\n") ? "" : (pieces.popLast() ?? "")
        if text.hasSuffix("\n") { pieces.removeLast() }
        return Chunk(lines: pieces.filter { !$0.isEmpty }, offset: size, partial: newPartial)
    }

    static func split(_ text: String) -> [LogLine] {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: true).suffix(maxLines)
        return lines.enumerated().map { LogLine(id: $0.offset, text: String($0.element), level: LogLevel.detect(String($0.element))) }
    }

    static func filter(_ lines: [LogLine], level: LogLevel, keyword: String) -> [LogLine] {
        let k = keyword.trimmingCharacters(in: .whitespaces).lowercased()
        return lines.filter { line in
            (level == .all || line.level == level) && (k.isEmpty || line.text.lowercased().contains(k))
        }
    }
}

@MainActor
final class LogViewModel: ObservableObject {
    @Published var selected: LogFileOption = LogFileOption.all[0]
    @Published var lines: [LogLine] = []
    @Published var level: LogLevel = .all
    @Published var keyword = ""
    @Published var autoScroll = true
    @Published var paused = false

    private var task: Task<Void, Never>?
    /// 增量读取状态: 上次读到的位置、未结束的半行、下一条 id
    private var offset: UInt64 = 0
    private var partial = ""
    private var nextId = 0

    var filtered: [LogLine] { LogTail.filter(lines, level: level, keyword: keyword) }

    func start() {
        stop()
        reload(force: true)
        task = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                self?.reload(force: false)
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }

    func reload(force: Bool) {
        guard force || !paused else { return }
        if force {
            offset = 0; partial = ""; lines = []
        }
        // 文件大小没变就什么都不做, 这是每秒轮询的常态
        let size = ((try? FileManager.default.attributesOfItem(atPath: selected.path))?[.size] as? NSNumber)?.uint64Value ?? 0
        guard force || size != offset else { return }
        guard let chunk = LogTail.read(path: selected.path, from: offset, partial: partial) else {
            lines = []; offset = 0; partial = ""
            return
        }
        if size < offset { lines = [] }   // 文件被清空/轮转, 从头显示
        offset = chunk.offset
        partial = chunk.partial
        guard !chunk.lines.isEmpty else { return }
        var appended = lines
        for text in chunk.lines {
            appended.append(LogLine(id: nextId, text: text, level: LogLevel.detect(text)))
            nextId += 1
        }
        if appended.count > LogTail.maxLines { appended.removeFirst(appended.count - LogTail.maxLines) }
        lines = appended
    }

    func clear() {
        LogRotation.truncate(path: selected.path)
        reload(force: true)
    }

    func revealInFinder() {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: selected.path)])
    }
}

struct LogView: View {
    var showHeader = true
    @StateObject private var vm = LogViewModel()

    var body: some View {
        VStack(spacing: 0) {
            if showHeader {
                PageHeader(icon: "doc.text.magnifyingglass", title: localizedString(.Logs), subtitle: localizedString(.LogsSubHead))
            }

            HStack(spacing: 8) {
                    Picker("", selection: $vm.selected) {
                        ForEach(LogFileOption.all) { Text($0.title).tag($0) }
                    }
                    .labelsHidden()
                    .fixedSize()
                    .onChange(of: vm.selected) { _, _ in vm.reload(force: true) }

                    Picker("", selection: $vm.level) {
                        ForEach(LogLevel.allCases) { Text($0.label).tag($0) }
                    }
                    .labelsHidden()
                    .fixedSize()

                    TextField(localizedString(.SearchTip), text: $vm.keyword)
                        .textFieldStyle(.roundedBorder)
                        .frame(minWidth: 80, maxWidth: 220)

                    Toggle(localizedString(.LogsAutoScroll), isOn: $vm.autoScroll)
                        .toggleStyle(.checkbox)
                        .fixedSize()

                    Button(action: { vm.paused.toggle() }) {
                        Image(systemName: vm.paused ? "play.fill" : "pause.fill")
                    }
                    .help(localizedString(vm.paused ? .Resume : .Pause))
                    .focusable(false)

                    Button(action: { vm.revealInFinder() }) { Image(systemName: "folder") }
                        .help(vm.selected.path)
                        .focusable(false)

                    Button(role: .destructive, action: { vm.clear() }) { Image(systemName: "trash") }
                        .help(localizedString(.ClearAllLogs))
                        .focusable(false)
                    Spacer(minLength: 0)
            }
            .padding(.vertical, 4)

            logList
                .padding(.top, 6)
        }
        .padding(8)
        .onAppear { vm.start() }
        .onDisappear { vm.stop() }
    }

    private var logList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 1) {
                    ForEach(vm.filtered) { line in
                        Text(line.text)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(line.level.color)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .id(line.id)
                    }
                }
                .textSelection(.enabled)
                .padding(6)
            }
            .background(Color(NSColor.textBackgroundColor))
            .cornerRadius(6)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.2)))
            .onChange(of: vm.lines) { _, _ in
                guard vm.autoScroll, let last = vm.filtered.last else { return }
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
    }
}
