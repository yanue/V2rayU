//
//  LogStream.swift
//  V2rayU
//
//  Created by yanue on 2025/7/14.
//

import SwiftUI

import Combine

@MainActor let AppLogStream = LogStreamHandler(filePath: appLogFilePath, maxLines: 100)
@MainActor let V2rayLogStream = LogStreamHandler(filePath: v2rayLogFilePath, maxLines: 100)

@MainActor
// 支持多实例的 LogManager
class LogStreamHandler : ObservableObject {
    @Published var logLines: [LogLine] = []
    @Published var isLogging: Bool = false
    private var logFileURL: URL?
    private var fileHandle: FileHandle?
    private var source: DispatchSourceFileSystemObject?
    private var lastOffset: UInt64 = 0
    private let maxLines: Int
    private let parseBlock: (String) -> String
    let filePath: String

    init(filePath: String, maxLines: Int = 20, parse: @escaping (String) -> String = { $0 }) {
        self.filePath = filePath
        self.maxLines = maxLines
        self.parseBlock = parse
        setupLogFile()
    }

    private func setupLogFile() {
        let fileManager = FileManager.default
        logFileURL = URL(fileURLWithPath: filePath)
        if !fileManager.fileExists(atPath: filePath) {
            fileManager.createFile(atPath: filePath, contents: nil, attributes: nil)
        }
    }

    func parse(_ line: String) -> String {
        parseBlock(line)
    }

    func clear() {
        logLines = []
        lastOffset = 0
    }

    func reload() {
        lastOffset = 0
        logLines = []
        readNewLines(limit: maxLines)
    }

    func startLogging() {
        guard let url = logFileURL else {
            logger.info("Log file URL is not set.\(String(describing: logFileURL))")
            return
        }
        do {
            fileHandle = try FileHandle(forReadingFrom: url)
            lastOffset = 0
            logLines = []
            startFileMonitor()
            isLogging = true
            logger.info("Started logging to \(url.path)")
        } catch {
            logger.info("Error starting logging: \(error)")
            isLogging = false
        }
    }

    func stopLogging(silent: Bool = false) {
        source?.cancel()
        source = nil
        fileHandle?.closeFile()
        fileHandle = nil
        if !silent {
            isLogging = false
        }
    }

    private func startFileMonitor() {
        guard let url = logFileURL else { return }
        stopLogging(silent: true)
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
            logger.info("Error monitoring log file: \(error)")
        }
    }

    private func readNewLines(limit: Int? = nil) {
        guard let fh = fileHandle else { return }
        do {
            let attr = try FileManager.default.attributesOfItem(atPath: logFileURL!.path)
            let fileSize = attr[.size] as? UInt64 ?? 0
            if lastOffset == 0, let limit = limit, fileSize > 0 {
                let data = try Data(contentsOf: logFileURL!)
                if let str = String(data: data, encoding: .utf8) {
                    let lines = str.components(separatedBy: "\n").filter { !$0.isEmpty }
                    let tail = lines.suffix(limit)
                    let parsed = tail.map { LogLine(raw: $0) }
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
                let parsed = lines.map { LogLine(raw: $0) }
                DispatchQueue.main.async {
                    self.logLines.append(contentsOf: parsed)
                    if self.logLines.count > self.maxLines {
                        self.logLines.removeFirst(self.logLines.count - self.maxLines)
                    }
                }
            }
            lastOffset = fileSize
        } catch {
            logger.info("Error reading new log lines: \(error)")
        }
    }
}

struct LogLine: Identifiable, Equatable {
    let id = UUID()
    let raw: String
    static func == (lhs: LogLine, rhs: LogLine) -> Bool {
        lhs.id == rhs.id
    }
}
