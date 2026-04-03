//
//  FileViewerManager.swift
//  V2rayU
//
//  文件查看器 - 支持日志、配置、PAC文件查看
//

import SwiftUI
import AppKit

enum FileType: String, CaseIterable, Identifiable {
    case logs = "日志"
    case config = "配置"
    case pac = "PAC"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .logs: return "doc.text"
        case .config: return "gearshape"
        case .pac: return "globe"
        }
    }
}

struct FileItem: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let path: String
    let size: Int64
    let type: FileType
    
    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
    
    var icon: String {
        if name.hasSuffix(".log") { return "doc.text" }
        if name.hasSuffix(".json") { return "doc.badge.gearshape" }
        if name.hasSuffix(".pac") { return "globe" }
        return "doc"
    }
}

@MainActor
final class FileViewerManager: ObservableObject {
    static let shared = FileViewerManager()
    
    @Published var selectedFileType: FileType = .logs
    @Published var selectedFile: FileItem?
    @Published var files: [FileItem] = []
    @Published var fileContent: String = ""
    @Published var isLoading: Bool = false
    @Published var searchText: String = ""
    @Published var showCopiedToast: Bool = false
    
    var filteredFiles: [FileItem] {
        guard !searchText.isEmpty else { return files }
        return files.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    var selectedFileIndex: Int {
        guard let selected = selectedFile else { return NSNotFound }
        return filteredFiles.firstIndex(where: { $0.path == selected.path }) ?? NSNotFound
    }
    
    private init() {
        refreshFiles()
    }
    
    func refreshFiles() {
        isLoading = true
        files = getFiles(for: selectedFileType)
        if selectedFile == nil, let first = files.first {
            selectFile(first)
        } else if let selected = selectedFile, !files.contains(where: { $0.path == selected.path }) {
            selectedFile = files.first
            if let file = selectedFile {
                loadFileContent(path: file.path)
            }
        }
        isLoading = false
    }
    
    func selectFile(_ item: FileItem) {
        selectedFile = item
        loadFileContent(path: item.path)
    }
    
    func selectFileType(_ type: FileType) {
        selectedFileType = type
        selectedFile = nil
        fileContent = ""
        refreshFiles()
    }
    
    func loadFileContent(path: String) {
        isLoading = true
        Task {
            let content = await readFileAsync(path: path)
            await MainActor.run {
                fileContent = content
                isLoading = false
            }
        }
    }
    
    private func readFileAsync(path: String) async -> String {
        return await Task.detached(priority: .userInitiated) {
            do {
                return try String(contentsOfFile: path, encoding: .utf8)
            } catch {
                return "无法读取文件内容: \(error.localizedDescription)"
            }
        }.value
    }
    
    private func getFiles(for type: FileType) -> [FileItem] {
        switch type {
        case .logs:
            return LogRotation.getLogFiles().map { 
                FileItem(name: $0.name, path: $0.path, size: $0.size, type: .logs) 
            }
        case .config:
            return getConfigFiles()
        case .pac:
            return getPacFiles()
        }
    }
    
    private func getConfigFiles() -> [FileItem] {
        let configPath = AppHomePath
        guard let contents = try? FileManager.default.contentsOfDirectory(atPath: configPath) else {
            return []
        }
        return contents
            .filter { $0.hasSuffix(".json") }
            .compactMap { name -> FileItem? in
                let path = (configPath as NSString).appendingPathComponent(name)
                guard let attrs = try? FileManager.default.attributesOfItem(atPath: path),
                      let size = attrs[.size] as? Int64 else { return nil }
                return FileItem(name: name, path: path, size: size, type: .config)
            }
    }
    
    private func getPacFiles() -> [FileItem] {
        let pacPath = AppHomePath
        guard let contents = try? FileManager.default.contentsOfDirectory(atPath: pacPath) else {
            return []
        }
        return contents
            .filter { $0.hasSuffix(".pac") }
            .compactMap { name -> FileItem? in
                let path = (pacPath as NSString).appendingPathComponent(name)
                guard let attrs = try? FileManager.default.attributesOfItem(atPath: path),
                      let size = attrs[.size] as? Int64 else { return nil }
                return FileItem(name: name, path: path, size: size, type: .pac)
            }
    }
    
    func copyContent() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(fileContent, forType: .string)
        showCopiedToast = true
        Task {
            try? await Task.sleep(for: .seconds(2))
            await MainActor.run {
                showCopiedToast = false
            }
        }
    }
    
    func openFileViewer() {
        refreshFiles()
        FileViewerWindowController.shared.showWindow(nil)
    }
}

@MainActor
final class FileViewerWindowController {
    static let shared = FileViewerWindowController()
    
    var window: NSWindow?
    
    func showWindow(_ sender: Any?) {
        if let existingWindow = window {
            existingWindow.makeKeyAndOrderFront(sender)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let contentView = FileViewerView()
        let hostingController = NSHostingController(rootView: contentView)
        
        let window = NSWindow(contentViewController: hostingController)
        window.title = String(localized: .ViewLogFiles)
        window.setContentSize(NSSize(width: 1000, height: 680))
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.minSize = NSSize(width: 800, height: 520)
        window.center()
        window.makeKeyAndOrderFront(sender)
        
        self.window = window
        NSApp.activate(ignoringOtherApps: true)
    }
}

struct FileViewerView: View {
    @StateObject private var manager = FileViewerManager.shared
    
    var body: some View {
        VStack(spacing: 0) {
            ToolbarBar()
            
            Divider()
            
            HSplitView {
                FileListSidebar()
                    .frame(minWidth: 240, idealWidth: 260, maxWidth: 320)
                
                FileContentArea()
                    .frame(minWidth: 480)
            }
        }
        .environmentObject(manager)
        .frame(minWidth: 800, minHeight: 520)
    }
}

struct ToolbarBar: View {
    @EnvironmentObject var manager: FileViewerManager
    
    var body: some View {
        HStack(spacing: 16) {
            Picker("", selection: $manager.selectedFileType) {
                ForEach(FileType.allCases) { type in
                    Label(type.rawValue, systemImage: type.icon)
                        .tag(type)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 220)
            .onChange(of: manager.selectedFileType) { _, newValue in
                manager.selectFileType(newValue)
            }
            
            TextField("搜索文件...", text: $manager.searchText)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 200)
                .overlay(
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                        .padding(.leading, 8)
                        .offset(x: 4),
                    alignment: .leading
                )
            
            Spacer()
            
            HStack(spacing: 8) {
                ToolbarButton(icon: "arrow.clockwise", tooltip: "刷新") {
                    manager.refreshFiles()
                }
                
                ToolbarButton(icon: "folder", tooltip: "在 Finder 中显示") {
                    openInFinder()
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            Color(nsColor: .windowBackgroundColor)
                .overlay(.ultraThinMaterial, in: Rectangle())
        )
    }
    
    private func openInFinder() {
        let url = URL(fileURLWithPath: AppHomePath)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}

struct ToolbarButton: View {
    let icon: String
    let tooltip: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .frame(width: 32, height: 28)
        }
        .buttonStyle(.plain)
        .help(tooltip)
    }
}

struct FileListSidebar: View {
    @EnvironmentObject var manager: FileViewerManager
    
    var body: some View {
        VStack(spacing: 0) {
            SidebarHeader()
                .environmentObject(manager)
            
            Divider()
            
            if manager.filteredFiles.isEmpty {
                EmptyFileList()
            } else {
                FileList()
                    .environmentObject(manager)
            }
        }
        .background(Color(nsColor: .underPageBackgroundColor))
    }
}

struct SidebarHeader: View {
    @EnvironmentObject var manager: FileViewerManager
    
    var body: some View {
        HStack {
            Label {
                Text(manager.selectedFileType.rawValue)
                    .font(.system(size: 13, weight: .semibold))
            } icon: {
                Image(systemName: manager.selectedFileType.icon)
                    .font(.system(size: 14))
            }
            .foregroundColor(.primary)
            
            Spacer()
            
            Text("\(manager.files.count)")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.secondary.opacity(0.12))
                .clipShape(Capsule())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

struct EmptyFileList: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 28))
                .foregroundColor(.secondary.opacity(0.4))
            Text("暂无文件")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct FileList: View {
    @EnvironmentObject var manager: FileViewerManager
    
    var body: some View {
        List(manager.filteredFiles, selection: Binding(
            get: { manager.selectedFile?.id },
            set: { id in
                if let file = manager.filteredFiles.first(where: { $0.id == id }) {
                    manager.selectFile(file)
                }
            }
        )) { file in
            FileRowView(file: file, isSelected: manager.selectedFile?.id == file.id)
                .tag(file.id)
                .listRowInsets(EdgeInsets(top: 2, leading: 8, bottom: 2, trailing: 8))
                .listRowSeparator(.hidden)
        }
        .listStyle(.plain)
    }
}

struct FileRowView: View {
    let file: FileItem
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: file.icon)
                .font(.system(size: 15))
                .foregroundColor(isSelected ? .white : .accentColor)
                .frame(width: 22, height: 22)
                .background(
                    isSelected ? Color.accentColor.opacity(0.15) : Color.accentColor.opacity(0.08),
                    in: RoundedRectangle(cornerRadius: 6)
                )
            
            VStack(alignment: .leading, spacing: 3) {
                Text(file.name)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                    .foregroundColor(isSelected ? .white : .primary)
                
                Text(file.formattedSize)
                    .font(.system(size: 11))
                    .foregroundColor(isSelected ? .white.opacity(0.7) : .secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(
            isSelected ? Color.accentColor : Color.clear,
            in: RoundedRectangle(cornerRadius: 8)
        )
        .contentShape(Rectangle())
    }
}

struct FileContentArea: View {
    @EnvironmentObject var manager: FileViewerManager
    
    var body: some View {
        VStack(spacing: 0) {
            if let selected = manager.selectedFile {
                ContentHeader(file: selected)
                    .environmentObject(manager)
                
                Divider()
                
                if manager.isLoading {
                    LoadingView()
                } else {
                    FileContentView()
                        .environmentObject(manager)
                }
            } else {
                EmptyContentView()
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
    }
}

struct ContentHeader: View {
    let file: FileItem
    @EnvironmentObject var manager: FileViewerManager
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(file.name)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
                
                HStack(spacing: 12) {
                    Label(file.formattedSize, systemImage: "arrow.up.arrow.down")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    
                    Text(file.path)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            
            Spacer()
            
            HStack(spacing: 6) {
                HeaderButton(icon: "doc.on.clipboard", tooltip: "复制路径") {
                    copyFilePath(file.path)
                }
                
                HeaderButton(icon: "doc.on.doc", tooltip: "复制内容") {
                    manager.copyContent()
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color(nsColor: .windowBackgroundColor))
        .overlay(alignment: .bottomTrailing) {
            if manager.showCopiedToast {
                CopiedToast()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }
    
    private func copyFilePath(_ path: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(path, forType: .string)
    }
}

struct HeaderButton: View {
    let icon: String
    let tooltip: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .frame(width: 30, height: 28)
        }
        .buttonStyle(.plain)
        .help(tooltip)
    }
}

struct CopiedToast: View {
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
            Text("已复制")
                .font(.system(size: 12, weight: .medium))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
    }
}

struct LoadingView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("正在加载...")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct FileContentView: View {
    @EnvironmentObject var manager: FileViewerManager
    
    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            Text(displayContent)
                .font(.system(size: 13, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .lineSpacing(4)
        }
    }
    
    private var displayContent: String {
        let lines = manager.fileContent.components(separatedBy: .newlines)
        if lines.count > 2000 {
            return lines.prefix(2000).joined(separator: "\n") + "\n\n... (文件过大，仅显示前2000行)"
        }
        return manager.fileContent
    }
}

struct EmptyContentView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.viewfinder")
                .font(.system(size: 56))
                .foregroundColor(.secondary.opacity(0.3))
            Text("选择文件查看内容")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.secondary)
            Text("从左侧列表选择要查看的文件")
                .font(.system(size: 13))
                .foregroundColor(.secondary.opacity(0.6))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// 保持向后兼容: 旧名仍可用
typealias LogWindowManager = FileViewerManager
