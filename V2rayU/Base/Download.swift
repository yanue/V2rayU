//
//  Download.swift
//  V2rayU
//
//  Created by yanue on 2025/7/23.
//

import Foundation
import SwiftUI

/// 下载状态模型（纯数据结构）
struct DownloadState {
    var downloadingVersion: String = ""
    var downloadingUrl: String = ""
    var progress: Double = 0.0
    var speed: String = "0.0 KB/s"
    var downloadedSize: String = "0.0 MB"
    var totalSize: String = "0.0 MB"
    var isFinished: Bool = false
    var errorMessage: String? = nil
    var downloadedFilePath: String? = nil
}

/// 通用下载代理，支持进度、超时、错误、完成回调
@MainActor
class DownloadManager: NSObject, ObservableObject, URLSessionDelegate, URLSessionDownloadDelegate {
    /// 一个整体的下载状态
    @Published var state = DownloadState()

    private let timerLock = NSLock()
    private var _timer: Timer?
    private var timer: Timer? {
        get { timerLock.lock(); defer { timerLock.unlock() }; return _timer }
        set { timerLock.lock(); _timer = newValue; timerLock.unlock() }
    }

    private let timeoutSeconds: Double
    private var didTimeout = false
    private var downloadTask: URLSessionDownloadTask?
    private let onSuccess: (String) -> Void
    private let onError: (String) -> Void
    private var lastWritten: Int64 = 0
    private var lastTime: Date = Date()

    /// 初始化
    /// - Parameters:
    ///   - timeout: 超时时间（秒）
    ///   - onSuccess: 成功回调，参数为下载文件临时路径
    ///   - onError: 错误回调，参数为错误信息
    init(timeout: Double = 10,
         onSuccess: @escaping (String) -> Void,
         onError: @escaping (String) -> Void) {
        timeoutSeconds = timeout
        self.onSuccess = onSuccess
        self.onError = onError
    }

    // MARK: - 对外启动下载接口
    func startDownload(from urlString: String, version: String, totalSize: Int64, useProxy: Bool = true) {
        guard let url = URL(string: urlString) else {
            self.state.isFinished = true
            self.state.errorMessage = String(localized: .DownloadURLInvalid)
            self.onError(self.state.errorMessage)
            return
        }
        state.downloadingVersion = version
        state.downloadingUrl = urlString
        state.totalSize = formatByte(Double(totalSize))
        state.isFinished = false
        state.progress = 0.0
        state.errorMessage = nil
        var config = URLSessionConfiguration.default
        if useProxy {
            config = getProxyUrlSessionConfigure()
        }
        session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        let task = session!.downloadTask(with: url)
        // 启动超时检测计时器
        startTimeout(downloadTask: task)
        // 启动下载任务
        task.resume()
    }

    func startTimeout(downloadTask: URLSessionDownloadTask) {
        self.downloadTask = downloadTask
        timer = Timer.scheduledTimer(withTimeInterval: timeoutSeconds, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            self.didTimeout = true
            downloadTask.cancel()
            DispatchQueue.main.async {
                self.state.isFinished = true
                self.state.errorMessage = String(localized: .DownloadErrorOccurred)
                self.onError(self.state.errorMessage)
            }
        }
    }

    func resetTimeout() {
        timer?.invalidate()
        guard let task = downloadTask else { return }
        timer = Timer.scheduledTimer(withTimeInterval: timeoutSeconds, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            self.didTimeout = true
            task.cancel()
            DispatchQueue.main.async {
                self.state.isFinished = true
                self.state.errorMessage = String(localized: .DownloadTimeoutError)
                self.onError(self.state.errorMessage)
            }
        }
    }

    func cancelTask() {
        if downloadTask != nil {
            downloadTask?.cancel()
        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let now = Date()
        let timeInterval = now.timeIntervalSince(lastTime)
        var speed = "0.0 KB/s"
        if timeInterval > 0 {
            speed = formatByte(Double(totalBytesWritten - lastWritten) / timeInterval) + "/s"
        }
        // 更新记录
        lastWritten = totalBytesWritten
        lastTime = now
        let progress = totalBytesExpectedToWrite > 0 ? Double(totalBytesWritten) / Double(totalBytesExpectedToWrite) : 0
        let downloaded = formatByte(Double(totalBytesWritten))
        // 更新结构体中的状态
        self.state.progress = progress
        self.state.speed = speed
        self.state.downloadedSize = downloaded
        resetTimeout()
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        timer?.invalidate()
        let locationPath = location.path
        let fileName = downloadTask.response?.suggestedFilename ?? ""
        guard locationPath != "", fileName != "" else {
            logger.info("urlSession: locationPath or fileName missing", )
            self.state.isFinished = true
            self.state.errorMessage = String(localized: .DownloadSaveFailed) + ": urlSession: locationPath or fileName missing"
            self.onError(self.state.errorMessage)
            return
        }
        let documentsPath = NSHomeDirectory() + "/Library/Caches/Download"
        let filePath = documentsPath + "/" + fileName
        do {
            // 删除原有文件
            if FileManager.default.fileExists(atPath: filePath) {
                try FileManager.default.removeItem(atPath: filePath)
            }
        } catch let catchError {
            self.state.isFinished = true
            self.state.errorMessage = String(localized: .DownloadSaveFailed) + ": \(catchError.localizedDescription)"
            self.onError(self.state.errorMessage)
            return
        }
        do {
            if FileManager.default.fileExists(atPath: documentsPath) == false {
                try FileManager.default.createDirectory(atPath: documentsPath, withIntermediateDirectories: true)
            }
            // 记录下载文件路径
            self.state.downloadedFilePath = filePath
            // 移动文件,不然随时被删除
            try FileManager.default.moveItem(atPath: locationPath, toPath: filePath)
        } catch let catchError {
            self.state.isFinished = true
            self.state.errorMessage = String(localized: .DownloadSaveFailed) + ": \(catchError.localizedDescription)"
            self.onError(self.state.errorMessage)
            return
        }
        DispatchQueue.main.async {
            // 更新状态为完成
            self.state.isFinished = true
            self.onSuccess(filePath)
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        timer?.invalidate()
        if let error = error {
            if didTimeout {
                // 已在超时回调处理
                return
            }
            DispatchQueue.main.async {
                self.state.isFinished = true
                self.state.errorMessage = String(localized: .DownloadErrorOccurred) + ": \(error.localizedDescription)"
                self.onError(self.state.errorMessage)
            }
        }
    }
}
