//
//  FileViewerView.swift
//  V2rayU
//
//  文件查看器视图
//

import SwiftUI
import AppKit

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
        List(manager.filteredFiles) { file in
            HStack(spacing: 0) {
                FileRowView(file: file, isSelected: manager.selectedFile?.id == file.id)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                manager.selectFile(file)
            }
            .listRowBackground(
                manager.selectedFile?.id == file.id
                    ? Color.accentColor.opacity(0.15)
                    : Color.clear
            )
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

struct FileRowView: View {
    let file: FileItem
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.accentColor : Color.accentColor.opacity(0.15))
                    .frame(width: 28, height: 28)
                
                Image(systemName: file.icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isSelected ? .white : .accentColor)
            }
            
            VStack(alignment: .leading, spacing: 1) {
                Text(file.name)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                    .lineLimit(1)
                    .foregroundColor(.primary)
                
                Text(file.formattedSize)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
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
