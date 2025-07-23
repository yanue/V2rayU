//
//  Download.swift
//  V2rayU
//
//  Created by yanue on 2025/7/23.
//

import Foundation

/// 通用下载代理，支持进度、超时、错误、完成回调
class DownloadDelegate: NSObject, URLSessionDelegate, URLSessionDownloadDelegate, @unchecked Sendable {
    private let timerLock = NSLock()
    private var _timer: Timer?
    private var timer: Timer? {
        get { timerLock.lock(); defer { timerLock.unlock() }; return _timer }
        set { timerLock.lock(); _timer = newValue; timerLock.unlock() }
    }

    private let timeoutSeconds: Double
    private var didTimeout = false
    private var downloadTask: URLSessionDownloadTask?
    private let onProgress: (Double, String) -> Void
    private let onSuccess: (URL) -> Void
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
         onProgress: @escaping (Double, String) -> Void,
         onSuccess: @escaping (URL) -> Void,
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
            DispatchQueue.main.async {
                self.onError("下载超时，请检查网络或代理设置")
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
                self.onError("下载超时，请检查网络或代理设置")
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
            speed = formatByte(Double(totalBytesWritten - lastWritten) / timeInterval)+"/s"
        }
        // 更新记录
        lastWritten = totalBytesWritten
        lastTime = now
        let progress = totalBytesExpectedToWrite > 0 ? Double(totalBytesWritten) / Double(totalBytesExpectedToWrite) : 0

        DispatchQueue.main.async {
            self.onProgress(progress, speed)
        }
        resetTimeout()
    }


    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        timer?.invalidate()
        DispatchQueue.main.async {
            self.onSuccess(location)
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
                self.onError("下载失败: \(error.localizedDescription)")
            }
        }
    }
}
