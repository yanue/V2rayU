//
//  FileViewerManager.swift
//  V2rayU
//
//  文件查看器 - 支持日志、配置、PAC文件查看
//

import SwiftUI
import AppKit

// 使用全局常量和工具函数，不显式依赖额外模块

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
        refreshFiles()
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
    
    func loadFileContent(path: String) {
        guard let content = try? String(contentsOfFile: path, encoding: .utf8) else {
            fileContent = "无法读取文件内容"
            return
        }
        fileContent = content
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
        window.setContentSize(NSSize(width: 900, height: 650))
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.minSize = NSSize(width: 700, height: 500)
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
            fileTypePicker
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(nsColor: .controlBackgroundColor))
            
            Divider()
            
            HSplitView {
                fileListSidebar
                    .frame(minWidth: 220, maxWidth: 280)
                
                fileContentView
                    .frame(minWidth: 400)
            }
        }
        .frame(minWidth: 700, minHeight: 500)
    }
    
    private var fileTypePicker: some View {
        HStack(spacing: 12) {
            ForEach(FileType.allCases) { type in
                FileTypeButton(
                    type: type,
                    isSelected: manager.selectedFileType == type,
                    action: { manager.selectFileType(type) }
                )
            }
            
            Spacer()
            
            Button(action: { manager.refreshFiles() }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 14, weight: .medium))
            }
            .buttonStyle(.bordered)
            .help("刷新文件列表")
            
            Button(action: openInFinder) {
                Image(systemName: "folder")
                    .font(.system(size: 14, weight: .medium))
            }
            .buttonStyle(.bordered)
            .help("在 Finder 中显示")
        }
    }
    
    private var fileListSidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: manager.selectedFileType.icon)
                    .foregroundColor(.secondary)
                Text(manager.selectedFileType.rawValue + "文件")
                    .font(.headline)
                Spacer()
                Text("\(manager.files.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(4)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(nsColor: .controlBackgroundColor))
            
            Divider()
            
            if manager.files.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "folder")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("暂无文件")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(manager.files, selection: Binding(
                    get: { manager.selectedFile?.id },
                    set: { id in
                        if let file = manager.files.first(where: { $0.id == id }) {
                            manager.selectFile(file)
                        }
                    }
                )) { file in
                    FileRowView(file: file, isSelected: manager.selectedFile?.id == file.id)
                        .tag(file.id)
                }
                .listStyle(.sidebar)
            }
        }
    }
    
    private var fileContentView: some View {
        VStack(spacing: 0) {
            if let selected = manager.selectedFile {
                fileContentHeader(selected)
                
                Divider()
                
                if manager.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView([.horizontal, .vertical]) {
                        Text(manager.fileContent)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                    }
                    .background(Color(nsColor: .textBackgroundColor))
                }
            } else {
                emptyStateView
            }
        }
    }
    
    private func fileContentHeader(_ file: FileItem) -> some View {
        HStack(spacing: 12) {
            Image(systemName: file.icon)
                .font(.system(size: 16))
                .foregroundColor(.accentColor)
            
            Text(file.name)
                .font(.system(.headline, weight: .semibold))
                .lineLimit(1)
            
            Spacer()
            
            HStack(spacing: 8) {
                Text(file.formattedSize)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(file.path)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            
            Button(action: { copyFilePath(file.path) }) {
                Image(systemName: "doc.on.clipboard")
                    .font(.system(size: 12))
            }
            .buttonStyle(.borderless)
            .help("复制文件路径")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(nsColor: .controlBackgroundColor))
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.5))
            Text("请选择文件")
                .font(.title3)
                .foregroundColor(.secondary)
            Text("从左侧列表选择要查看的文件")
                .font(.caption)
                .foregroundColor(.secondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func openInFinder() {
        let basePath: String
        switch manager.selectedFileType {
        case .logs:
            basePath = AppHomePath
        case .config:
            basePath = AppHomePath
        case .pac:
            basePath = AppHomePath
        }
        let url = URL(fileURLWithPath: basePath)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
    
    private func copyFilePath(_ path: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(path, forType: .string)
    }
}

struct FileTypeButton: View {
    let type: FileType
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: type.icon)
                    .font(.system(size: 12))
                Text(type.rawValue)
                    .font(.system(size: 13, weight: .medium))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.1))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

struct FileRowView: View {
    let file: FileItem
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: file.icon)
                .font(.system(size: 14))
                .foregroundColor(isSelected ? .white : .secondary)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(file.name)
                    .font(.system(size: 13))
                    .lineLimit(1)
                
                Text(file.formattedSize)
                    .font(.system(size: 11))
                    .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(isSelected ? Color.accentColor : Color.clear)
        .cornerRadius(6)
        .contentShape(Rectangle())
    }
}

// 保持向后兼容: 旧名仍可用
typealias LogWindowManager = FileViewerManager
