import SwiftUI
import Combine

@MainActor
final class DownloadViewModel: ObservableObject {
    // 直接用 @Published 保存状态
    @Published var progress: Double = 0
    @Published var speed: String = ""
    @Published var downloadedSize: String = "0 B"
    @Published var downloadedPath: String = ""
    @Published var totalSize: String = "—"
    @Published var isFinished: Bool = false
    @Published var errorMessage: String = ""
    @Published var downloadingUrl: String = ""
    @Published var downloadingVersion: String = ""

    private var session: URLSession?
    private var delegate: DownloadDelegate?
    
    private var onSuccess: (String) -> Void = { _ in }
    private var onError: (String) -> Void = { _ in }

    func setCallback(onSuccess: @escaping (String) -> Void, onError: @escaping (String) -> Void) {
      self.onSuccess = onSuccess
      self.onError = onError
    }
    
    func startDownload(from urlStr: String, version: String, totalSize: Int64? = nil, timeout: Double = 120) {
        // [Fix] #1679 — 只拦截"正在下载中"的重复请求，允许取消/失败后重试。
        //
        // 原逻辑: session != nil || isFinished
        //   问题: 用户取消下载后 isFinished=true、session=nil，
        //         再次点击下载时 guard 条件为 true，直接 return，
        //         下面的状态重置代码永远不会执行，导致无法重新下载。
        //
        // 修复后: 仅当 session 仍存活（下载进行中）时才跳过，
        //         已取消/已失败/已完成的下载都会落入下方重置逻辑，
        //         重新创建 session 并启动下载。
        if downloadingUrl == urlStr, downloadingVersion == version, session != nil {
            return
        }

        // 重置状态
        progress = 0
        speed = ""
        downloadedSize = "0 B"
        self.totalSize = totalSize.map { formatByte(Double($0)) } ?? "—"
        isFinished = false
        errorMessage = ""
        downloadedPath = ""
        downloadingUrl = urlStr
        downloadingVersion = version
        logger.info("startDownload: from=\(urlStr),version=\(version)")
        guard let url = URL(string: urlStr) else {
            errorMessage = String(localized: .DownloadURLInvalid) + ": \(urlStr)"
            isFinished = true
            return
        }

        let delegate = DownloadDelegate(
            timeout: timeout,
            onProgress: { [weak self] progress, speed, downloadedSize in
                DispatchQueue.main.async {
                    self?.progress = progress
                    self?.speed = speed
                    self?.downloadedSize = downloadedSize
                }
            },
            onSuccess: { [weak self] filePath in
                DispatchQueue.main.async {
                    self?.isFinished = true
                    self?.downloadedPath = filePath
                    self?.session?.finishTasksAndInvalidate()
                    self?.session = nil
                    self?.onSuccess(filePath)
                }
            },
            onError: { [weak self] err in
                DispatchQueue.main.async {
                    self?.isFinished = true
                    self?.errorMessage = err
                    self?.session?.invalidateAndCancel()
                    self?.session = nil
                    self?.onError(err)
                }
            }
        )

        self.delegate = delegate
        session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
        let task = session?.downloadTask(with: url)
        if let task {
            delegate.startTimeout(downloadTask: task)
            task.resume()
        }
    }

    func cancelTask() {
        delegate?.cancelTask()
        session?.invalidateAndCancel()
        session = nil
        isFinished = true
        if errorMessage.isEmpty {
            errorMessage = String(localized: .DownloadCanceled)
        }
    }
}
