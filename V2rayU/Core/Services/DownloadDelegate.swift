//
//  DownloadModel.swift
//  V2rayU
//
//  Created by yanue on 2025/10/31.
//

import SwiftUI
import Combine

/// 通用下载代理，支持进度、超时、错误、完成回调
final class DownloadDelegate: NSObject, URLSessionDelegate, URLSessionDownloadDelegate, @unchecked Sendable {
    private let timerLock = NSLock()
    private var _timer: Timer?
    private var timer: Timer? {
        get { timerLock.lock(); defer { timerLock.unlock() }; return _timer }
        set { timerLock.lock(); _timer = newValue; timerLock.unlock() }
    }

    private let timeoutSeconds: Double
    private var didTimeout = false
    private var downloadTask: URLSessionDownloadTask?
    private let onProgress: (Double, String, String) -> Void
    private let onSuccess: (String) -> Void
    private let onError: (String) -> Void
    private var lastWritten: Int64 = 0
    private var lastTime: Date = Date()

    /// 初始化
    /// - Parameters:
    ///   - timeout: 超时时间（秒）
    ///   - onProgress: 进度回调 0~1
    ///   - onSuccess: 成功回调，参数为下载文件临时路径
    ///   - onError: 错误回调，参数为错误信息
    init(timeout: Double = 10,
         onProgress: @escaping (Double, String, String) -> Void,
         onSuccess: @escaping (String) -> Void,
         onError: @escaping (String) -> Void) {
        timeoutSeconds = timeout
        self.onProgress = onProgress
        self.onSuccess = onSuccess
        self.onError = onError
    }

    func startTimeout(downloadTask: URLSessionDownloadTask) {
        self.downloadTask = downloadTask
        timer = Timer.scheduledTimer(withTimeInterval: timeoutSeconds, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            self.didTimeout = true
            downloadTask.cancel()
            Task { @MainActor in
                self.onError(String(localized: .DownloadTimeoutProxy))
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
            Task { @MainActor in
                self.onError(String(localized: .DownloadTimeoutProxy))
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
        let downloadedSize = formatByte(Double(totalBytesWritten))
        DispatchQueue.main.async { [weak self] in
            self?.onProgress(progress, speed, downloadedSize)
        }
        resetTimeout()
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        timer?.invalidate()
        let locationPath = location.path
        let fileName = downloadTask.response?.suggestedFilename ?? ""
        guard locationPath != "", fileName != "" else {
            print("urlSession: locationPath or fileName missing")
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
            Task { @MainActor in
                alertDialog(title: String(localized: .DownloadSaveFailed), message: String(localized: .OperationFailed, arguments: catchError.localizedDescription))
            }
        }
        do {
            if FileManager.default.fileExists(atPath: documentsPath) == false {
                try FileManager.default.createDirectory(atPath: documentsPath, withIntermediateDirectories: true)
            }
            // 移动文件,不然随时被删除
            try FileManager.default.moveItem(atPath: locationPath, toPath: filePath)
        } catch let catchError {
            Task { @MainActor in
                alertDialog(title: String(localized: .DownloadSaveFailed), message: String(localized: .OperationFailed, arguments: catchError.localizedDescription))
            }
        }
        DispatchQueue.main.async { [weak self] in
            self?.onSuccess(filePath)
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        timer?.invalidate()
        if let error = error {
            if didTimeout {
                // 已在超时回调处理
                return
            }
            Task { @MainActor in
                self.onError(String(localized: .OperationFailed, arguments: error.localizedDescription))
            }
        }
    }
}
