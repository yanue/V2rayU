import SwiftUI

protocol LogLineProtocol: Identifiable, Equatable {
    var raw: String { get }
}

struct GenericLogLine: LogLineProtocol {
    let id = UUID()
    let raw: String
    static func == (lhs: GenericLogLine, rhs: GenericLogLine) -> Bool {
        lhs.id == rhs.id
    }
}

@MainActor
class LogManager<T: LogLineProtocol>: ObservableObject {
    @Published var logLines: [T] = []
    private var logFileURL: URL?
    private var fileHandle: FileHandle?
    private var source: DispatchSourceFileSystemObject?
    private var lastOffset: UInt64 = 0
    private let maxLines: Int
    private let parse: (String) -> T
    private let filePath: String

    init(filePath: String, maxLines: Int, parse: @escaping (String) -> T) {
        self.filePath = filePath
        self.maxLines = maxLines
        self.parse = parse
        setupLogFile()
    }

    func startLogging() {
        guard let url = logFileURL else { return }
        do {
            fileHandle = try FileHandle(forReadingFrom: url)
            lastOffset = 0
            logLines = []
            readNewLines(limit: maxLines)
            startFileMonitor()
        } catch {
            print("Error starting logging: \(error)")
        }
    }

    func stopLogging() {
        source?.cancel()
        source = nil
        fileHandle?.closeFile()
        fileHandle = nil
    }

    private func setupLogFile() {
        let fileManager = FileManager.default
        logFileURL = URL(fileURLWithPath: filePath)
        if !fileManager.fileExists(atPath: filePath) {
            fileManager.createFile(atPath: filePath, contents: nil, attributes: nil)
        }
    }

    private func startFileMonitor() {
        guard let url = logFileURL else { return }
        stopLogging()
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
                    let parsed = tail.map { self.parse($0) }
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
                let parsed = lines.map { self.parse($0) }
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
}

struct LogView<T: LogLineProtocol>: View {
    @StateObject var logManager: LogManager<T>
    var title: String
    var minHeight: CGFloat = 300

    var body: some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.headline)
                .padding(.bottom, 2)
            ScrollViewReader { proxy in
                ScrollView(.vertical) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(logManager.logLines.map { $0.raw }.joined(separator: "\n"))
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity, minHeight: minHeight, maxHeight: .infinity, alignment: .topLeading)
                            .textSelection(.enabled)
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
            .background(Color(NSColor.textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                    .shadow(color: Color.primary.opacity(0.1), radius: 1, x: 0, y: 1)
            )
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                logManager.startLogging()
            }
        }
        .onDisappear {
            logManager.stopLogging()
        }
    }
}
