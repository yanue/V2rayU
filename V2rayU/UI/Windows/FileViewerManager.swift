//
//  FileViewerManager.swift
//  V2rayU
//
//  文件查看器 - 支持日志、配置、PAC文件查看
//

import SwiftUI
import AppKit
import OSLog

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
    let id: String
    let path: String
    let size: Int64
    let type: FileType
    
    var name: String {
        (path as NSString).lastPathComponent
    }
    
    init(name: String, path: String, size: Int64, type: FileType) {
        self.id = name
        self.path = path
        self.size = size
        self.type = type
    }
    
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

enum PredefinedFile: String, CaseIterable {
    case coreLog = "core.log"
    case tunLog = "tun.log"
    case errorLog = "error.log"
    case config = "config.json"
    case tunConfig = "tun-config.json"
    case proxyJs = "proxy.js"
    
    var fileType: FileType {
        switch self {
        case .coreLog, .tunLog, .errorLog:
            return .logs
        case .config, .tunConfig:
            return .config
        case .proxyJs:
            return .pac
        }
    }
    
    func fileItem() -> FileItem? {
        let path = AppHomePath + "/" + rawValue
        guard FileManager.default.fileExists(atPath: path),
              let attrs = try? FileManager.default.attributesOfItem(atPath: path),
              let size = attrs[.size] as? Int64 else { return nil }
        return FileItem(name: rawValue, path: path, size: size, type: fileType)
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
    
    func selectFileType(_ type: FileType, preSelectPath: String? = nil) {
        selectedFileType = type
        selectedFile = nil
        fileContent = ""
        refreshFiles()
        
        if let path = preSelectPath,
           let file = files.first(where: { $0.path == path }) {
            selectFile(file)
        }
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
        return PredefinedFile.allCases
            .filter { $0.fileType == type }
            .compactMap { $0.fileItem() }
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

typealias LogWindowManager = FileViewerManager
