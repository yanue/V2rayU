//
//  LogView.swift
//  V2rayU
//
//  Created by yanue on 2025/7/13.
//

import SwiftUI

struct V2rayLogView: View {
    @StateObject var logManager = V2rayLogManager.shared

    var body: some View {
        VStack {
            // 使用 ScrollView + Text 实现可选择和复制
            ScrollViewReader { proxy in
                ScrollView(.vertical) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(logManager.logLines.map { $0.raw }.joined(separator: "\n"))
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity, minHeight: 300, maxHeight: .infinity, alignment: .topLeading)
                            .textSelection(.enabled) // 允许选中和复制
                            .padding(.horizontal, 4)
                            .id("logText")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .onChange(of: logManager.logLines) { _,_ in
                    withAnimation {
                        proxy.scrollTo("logText", anchor: .bottom)
                    }
                }
            }
            .padding()
            .background(Color(NSColor.textBackgroundColor)) // 统一背景色
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                    .shadow(color: Color.primary.opacity(0.1), radius: 1, x: 0, y: 1)
            )
        }
        .frame(maxWidth: .infinity) // 只设置maxWidth, 不设置minWidth
        .onAppear {
            // 避免刚启动页面卡顿,睡眠一会
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                logManager.startLogging()
            }
        }
        .onDisappear {
            logManager.stopLogging()
        }
    }
}

// 日志管理器，负责监听和读取日志文件
@MainActor
class V2rayLogManager : ObservableObject {
    static let shared = V2rayLogManager()
    
    @Published var logLines: [LogLine] = []
    private var logFileURL: URL?
    private var fileHandle: FileHandle?
    private var source: DispatchSourceFileSystemObject?
    private var lastOffset: UInt64 = 0
    private let maxLines = 20 // 最多保留 20 行

    private init() {
        setupLogFile()
    }

    // 启动日志监听
    func startLogging() {
        guard let url = logFileURL else { return }
        do {
            fileHandle = try FileHandle(forReadingFrom: url)
            lastOffset = 0
            logLines = []
            readNewLines(limit: maxLines) // 首次只读最后 20 行
            startFileMonitor()
        } catch {
            print("Error starting logging: \(error)")
        }
    }

    // 停止日志监听
    func stopLogging() {
        source?.cancel()
        source = nil
        fileHandle?.closeFile()
        fileHandle = nil
    }

    // 设置日志文件路径
    private func setupLogFile() {
        let fileManager = FileManager.default
        let path = logFilePath
        logFileURL = URL(fileURLWithPath: path)
        if !fileManager.fileExists(atPath: path) {
            fileManager.createFile(atPath: path, contents: nil, attributes: nil)
        }
    }

    // 启动文件变化监听
    private func startFileMonitor() {
        guard let url = logFileURL else { return }
        stopLogging() // 先停止之前的监听
        do {
            let fh = try FileHandle(forReadingFrom: url)
            fileHandle = fh
            let fd = fh.fileDescriptor
            let src = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: .write, queue: DispatchQueue.main)
            src.setEventHandler { [weak self] in
                self?.readNewLines()
            }
            src.setCancelHandler { [weak self] in
                self?.fileHandle?.closeFile()
                self?.fileHandle = nil
            }
            source = src
            src.resume()
        } catch {
            print("Error monitoring log file: \(error)")
        }
    }

    // 增量读取新日志内容，首次只读最后 limit 行
    private func readNewLines(limit: Int? = nil) {
        guard let fh = fileHandle else { return }
        do {
            let attr = try FileManager.default.attributesOfItem(atPath: logFileURL!.path)
            let fileSize = attr[.size] as? UInt64 ?? 0
            if lastOffset == 0, let limit = limit, fileSize > 0 {
                // 首次加载时只读最后 limit 行
                let data = try Data(contentsOf: logFileURL!)
                if let str = String(data: data, encoding: .utf8) {
                    let lines = str.components(separatedBy: "\n").filter { !$0.isEmpty }
                    let tail = lines.suffix(limit)
                    let parsed = tail.map { V2rayLogManager.parseLogLine($0) }
                    DispatchQueue.main.async {
                        self.logLines = Array(parsed)
                    }
                }
                lastOffset = fileSize
                return
            }
            guard fileSize > lastOffset else { return }
            fh.seek(toFileOffset: lastOffset)
            let data = fh.readDataToEndOfFile()
            if let str = String(data: data, encoding: .utf8) {
                let lines = str.components(separatedBy: "\n").filter { !$0.isEmpty }
                let parsed = lines.map { V2rayLogManager.parseLogLine($0) }
                DispatchQueue.main.async {
                    self.logLines.append(contentsOf: parsed)
                    if self.logLines.count > self.maxLines {
                        self.logLines.removeFirst(self.logLines.count - self.maxLines)
                    }
                }
            }
            lastOffset = fileSize
        } catch {
            print("Error reading new log lines: \(error)")
        }
    }

    // 解析日志行为 LogLine
    static func parseLogLine(_ line: String) -> LogLine {
        LogLine(raw: line)
    }
}

// 日志行结构体，只保存原始内容
struct LogLine: Identifiable, Equatable {
    let id = UUID()
    let raw: String
    static func == (lhs: LogLine, rhs: LogLine) -> Bool {
        lhs.id == rhs.id
    }
}
