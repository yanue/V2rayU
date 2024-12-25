//
//  Url+Extension.swift
//  V2rayU
//
//  Created by yanue on 2024/12/25.
//  Copyright © 2024 yanue. All rights reserved.

import Foundation

extension URL {
    func queryParams() -> [String: Any] {
        var dict = [String: Any]()

        if let components = URLComponents(url: self, resolvingAgainstBaseURL: false) {
            if let queryItems = components.queryItems {
                for item in queryItems {
                    dict[item.name] = item.value!
                }
            }
            return dict
        } else {
            return [:]
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
