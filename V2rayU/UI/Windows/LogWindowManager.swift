//
//  LogWindowManager.swift
//  V2rayU
//
//  日志文件查看窗口管理
//

import SwiftUI
import AppKit

@MainActor
final class LogWindowManager: ObservableObject {
    static let shared = LogWindowManager()
    
    @Published var selectedLogFile: LogFileItem?
    @Published var logFiles: [LogFileItem] = []
    @Published var logContent: String = ""
    
    struct LogFileItem: Identifiable, Hashable {
        let id = UUID()
        let name: String
        let path: String
        let size: Int64
        
        var formattedSize: String {
            ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
        }
    }
    
    private init() {
        refreshLogFiles()
    }
    
    func refreshLogFiles() {
        logFiles = LogRotation.getLogFiles().map { LogFileItem(name: $0.name, path: $0.path, size: $0.size) }
        if selectedLogFile == nil, let first = logFiles.first {
            selectLogFile(first)
        }
    }
    
    func selectLogFile(_ item: LogFileItem) {
        selectedLogFile = item
        loadLogContent(path: item.path)
    }
    
    func loadLogContent(path: String) {
        guard let content = try? String(contentsOfFile: path, encoding: .utf8) else {
            logContent = "无法读取日志文件"
            return
        }
        logContent = content
    }
    
    func openLogWindow() {
        refreshLogFiles()
        _LogWindowController.shared.showWindow(nil)
    }
}

@MainActor
final class _LogWindowController {
    static let shared = _LogWindowController()
    
    var window: NSWindow?
    
    func showWindow(_ sender: Any?) {
        if let existingWindow = window {
            existingWindow.makeKeyAndOrderFront(sender)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let contentView = LogFilesView()
        let hostingController = NSHostingController(rootView: contentView)
        
        let window = NSWindow(contentViewController: hostingController)
        window.title = String(localized: .ViewLogFiles)
        window.setContentSize(NSSize(width: 800, height: 600))
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.minSize = NSSize(width: 600, height: 400)
        window.center()
        window.makeKeyAndOrderFront(sender)
        
        self.window = window
        NSApp.activate(ignoringOtherApps: true)
    }
}

struct LogFilesView: View {
    @StateObject private var manager = LogWindowManager.shared
    
    var body: some View {
        HSplitView {
            VStack(alignment: .leading, spacing: 8) {
                Text(String(localized: .LogFile))
                    .font(.headline)
                    .padding(.horizontal, 8)
                    .padding(.top, 8)
                
                List(manager.logFiles, selection: $manager.selectedLogFile) { file in
                    Button(action: { manager.selectLogFile(file) }) {
                        HStack {
                            Image(systemName: "doc.text")
                            Text(file.name)
                            Spacer()
                            Text(file.formattedSize)
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .background(manager.selectedLogFile?.id == file.id ? Color.accentColor.opacity(0.2) : Color.clear)
                    .cornerRadius(4)
                }
                .listStyle(.sidebar)
                
                HStack {
                    Button(action: { manager.refreshLogFiles() }) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .help("刷新")
                    
                    Button(action: openInFinder) {
                        Image(systemName: "folder")
                    }
                    .help("在 Finder 中显示")
                }
                .padding(8)
            }
            .frame(minWidth: 200, maxWidth: 250)
            .background(Color(nsColor: .controlBackgroundColor))
            
            VStack(spacing: 0) {
                if let selected = manager.selectedLogFile {
                    HStack {
                        Text(selected.name)
                            .font(.headline)
                        Spacer()
                        Text(selected.formattedSize)
                            .foregroundColor(.secondary)
                    }
                    .padding(12)
                    .background(Color(nsColor: .controlBackgroundColor))
                    
                    Divider()
                    
                    ScrollView {
                        Text(manager.logContent)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                    }
                    .background(Color(nsColor: .textBackgroundColor))
                } else {
                    VStack {
                        Image(systemName: "doc.text")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text(String(localized: .SelectLogFile))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
    }
    
    private func openInFinder() {
        if let selected = manager.selectedLogFile {
            let url = URL(fileURLWithPath: selected.path)
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
    }
}
