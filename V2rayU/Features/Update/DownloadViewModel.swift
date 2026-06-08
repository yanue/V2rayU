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
        if downloadingUrl == urlStr, downloadingVersion == version, session != nil || isFinished {
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
