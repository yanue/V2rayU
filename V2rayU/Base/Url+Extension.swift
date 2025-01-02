//
//  Url+Extension.swift
//  V2rayU
//
//  Created by yanue on 2024/12/25.
//  Copyright © 2024 yanue. All rights reserved.

import Foundation

// URL 扩展：用于从 URL 获取查询参数
extension URL {
    func queryParams() -> QueryParameters {
        var dict = QueryParameters()
        if let components = URLComponents(url: self, resolvingAgainstBaseURL: false) {
            if let queryItems = components.queryItems {
                for item in queryItems {
                    dict.add(key: item.name, value: item.value ?? "")
                }
            }
        }
        return dict
    }
}

// 更合适的命名：用于存储 URL 查询参数的类
class QueryParameters: NSObject {
    private var dict = [String: String]()

    override init() {
        super.init()
    }

    // 添加查询参数
    func add(key: String, value: String) {
        dict[key] = value
    }

    // 获取 String 类型的参数
    func getString(forKey key: String, defaultValue: String = "") -> String {
        return dict[key] ?? defaultValue
    }

    // 获取 Int 类型的参数
    func getInt(forKey key: String, defaultValue: Int = 0) -> Int {
        if let stringValue = dict[key], let intValue = Int(stringValue) {
            return intValue
        }
        return defaultValue
    }

    // 获取 Bool 类型的参数
    func getBool(forKey key: String, defaultValue: Bool = false) -> Bool {
        if let stringValue = dict[key] {
            return stringValue.lowercased() == "true" || stringValue == "1"
        }
        return defaultValue
    }

    // 获取 Enum 类型的参数
    func getEnum<T: RawRepresentable>(forKey key: String, type: T.Type, defaultValue: T) -> T where T.RawValue == String {
        if let rawValue = dict[key], let enumValue = T(rawValue: rawValue) {
            return enumValue
        }
        return defaultValue
    }
}

// 自定义的 metrics 代理
class MetricsCollectorDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    private let completion: @Sendable (URLSessionTaskMetrics) -> Void
    private let queue = DispatchQueue(label: "MetricsCollectorDelegate.queue")

    init(completion: @escaping @Sendable (URLSessionTaskMetrics) -> Void) {
        self.completion = completion
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
        // 确保 completion 在安全的队列上调用
        queue.async {
            self.completion(metrics)
        }
    }
}

// 扩展 URLSession 以支持 metrics
extension URLSession {
    /// 获取请求的 metrics
    func metrics(for request: URLRequest) async throws -> URLSessionTaskMetrics {
        let task = dataTask(with: request)
        return try await withCheckedThrowingContinuation { continuation in
            let delegate = MetricsCollectorDelegate { metrics in
                continuation.resume(with: .success(metrics))
            }
            task.delegate = delegate
            task.resume()
        }
    }
}

func getProxyUrlSessionConfigure() -> URLSessionConfiguration {
    // Create a URLSessionConfiguration with proxy settings
    let configuration = URLSessionConfiguration.default
    // v2ray is running
    if UserDefaults.getBool(forKey: .v2rayTurnOn) {
        let proxyHost = "127.0.0.1"
        let proxyPort = getHttpProxyPort()
        // set proxies
        configuration.connectionProxyDictionary = [
            kCFNetworkProxiesHTTPEnable as AnyHashable: true,
            kCFNetworkProxiesHTTPProxy as AnyHashable: proxyHost,
            kCFNetworkProxiesHTTPPort as AnyHashable: proxyPort,
            kCFNetworkProxiesHTTPSEnable as AnyHashable: true,
            kCFNetworkProxiesHTTPSProxy as AnyHashable: proxyHost,
            kCFNetworkProxiesHTTPSPort as AnyHashable: proxyPort,
        ]
    }
    configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
    configuration.urlCache = nil
    configuration.timeoutIntervalForRequest = 30 // Set your desired timeout interval in seconds

    return configuration
}

func getProxyUrlSessionConfigure(httpProxyPort: uint16) -> URLSessionConfiguration {
    // Create a URLSessionConfiguration with proxy settings
    let configuration = URLSessionConfiguration.default
    let proxyHost = "127.0.0.1"
    let proxyPort = httpProxyPort
    // set proxies
    configuration.connectionProxyDictionary = [
        kCFNetworkProxiesHTTPEnable as AnyHashable: true,
        kCFNetworkProxiesHTTPProxy as AnyHashable: proxyHost,
        kCFNetworkProxiesHTTPPort as AnyHashable: proxyPort,
        kCFNetworkProxiesHTTPSEnable as AnyHashable: true,
        kCFNetworkProxiesHTTPSProxy as AnyHashable: proxyHost,
        kCFNetworkProxiesHTTPSPort as AnyHashable: proxyPort,
    ]
    configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
    configuration.urlCache = nil
    configuration.timeoutIntervalForRequest = 2 // Set your desired timeout interval in seconds
    return configuration
}
